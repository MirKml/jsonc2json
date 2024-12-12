#!/usr/bin/env bash
set -euo pipefail

# remove line or multi line comments on single line
#   // line comment on single line
#   /* multi line comment on single line */
strip_alone_line_comments() {
    sed -e "/^[[:blank:]]*\/\//d" -e "/^[[:blank:]]*\/\*.*\*\/[[:blank:]]*$/d"
}

# removing trailing commas with simple :-) sed
# doesn't bother if trailing comma is inside string or not
# because this case i really rare, maybe when json contains some parts for code generation
#
# todo: try to replace with json string based scanner of whole json string
# stdin - line stream of jsonc file
strip_trailing_commas() {
    sed -e '
# sets a label named "a"
:a

# "$!" if not the last line, then
# "N" append the next line to the pattern space (or quit if there is no next line)
# and "ba" branch (go to) label "a"
$!{N;ba}

# replace trailing commans with blanks ,<spaces>} with }
s/,[[:blank:]]*\([]}]\)/ \1/g

# replace trailing commans with new lines blanks ,\n<spaces>}" with \n<spaces>}
s/,\n\([[:blank:]]*\)\([]}]\)/\n\1\2/g

# last resort, trailing commans with new lines or spaces before "}"
s/,[[:space:]]*\([]}]\)/ \1/g;'
}

# removes
# - single line comments
# - multiple line comments
# - trailing commas in arrays
# all these can be mixed inside with other json like chars
strip_jsonc_specific_chars() {
    awk \
'
BEGIN {
    In_multi_line_comment = 0
}

/^[[:blank:]]*\/\*/ {
    In_multi_line_comment = 1
    next
}

/\*\/[[:blank:]]*$/ {
    In_multi_line_comment = 0
    next
}

# we are in multi-line comment
# return all after multiline comment end - "*/"
In_multi_line_comment == 1 {
    # no end of multi line comment found
    # we are still in comment, so print nothig
    if ($0 !~ /\*\//) {
        next
    }

    # remove everything from start to the end of comment
    # save it as current line - $0 - a go to the next awk line pattern processing
    comment_position = index($0, "*/")
    if (comment_position > 0) {
        $0 = substr($0, comment_position + 2)
        $0 = trim_right($0)
        In_multi_line_comment = 0
    }
}

# executed only if we aren'"'"'t in multiline comment
# notice (be aware of single quite in single quote in previous comment, because we are generally in bash :-))
{
    current_line = remove_comments($0)
    current_block = remove_trailing_comma(current_line)
    printf("current block: --%s--\n", current_block)
}

function remove_comments(input_line,      current_pos, current_char, buffer, token_val, output) {
    output = ""
    # all awk string starts on index 1
    current_pos = 1

    # print "line: " input_line
    # print "length: " length(input_line)

    while (current_pos <= length(input_line)) {
        current_char = get_current_char(input_line, current_pos)
        # printf("rem. comments: pos: %s char: %s out: %s\n", current_pos, current_char, output)

        # string e.g. "some string input with escape \" rest of string"
        if (current_char == "\"") {
            buffer = get_next_string(input_line, current_pos)
            output = output buffer
            current_pos += length(buffer)
            continue
        }

        # one line comments //
        if (current_char == "/") {
            token_val = current_char
            # get next char immediatelly
            current_char = get_current_char(input_line, ++current_pos)
            token_val = token_val current_char

            # start of line comment, stop reading rest of input,
            # return current output as final
            if (token_val == "//") {
                break
            }

            # multi line comments
            if (token_val == "/*") {
                # read until the end of string or end of input line
                while (++current_pos <= length(input_line)) {
                    current_char = get_current_char(input_line, current_pos)
                    token_val = token_val current_char
                    # if latest 2 chars in token are */ - closing comment
                    if (substr(token_val, length(token_val) - 1) == "*/") {
                        # print "found multiline comment: " token_val
                        # next input char iteration
                        break
                    }
                }

                # whole line was processed and we are still in multiline comment
                if (current_pos >= length(input_line)) {
                    In_multi_line_comment = 1
                }
                token_val = ""
            }

            output = output token_val
            # next input char iteration
            current_pos++
            continue
        }

        output = output current_char
        current_pos++
    }

    # trim ending spaces
    return trim_right(output)
}

function remove_trailing_comma(input_line,      current_pos, current_char, output, buffer) {
    current_pos = 1
    #print "rem. trailing comma: line" input_line

    if (Trailing_comma["buffer"]) {
        output = Trailing_comma["buffer"] "\n"
    } else {
        output = ""
    }

    while (current_pos <= length(input_line)) {
        current_char = get_current_char(input_line, current_pos)
        #printf("rem. traling comma: pos: %s char: %s out: %s\n", current_pos, current_char, output)

        # string e.g. "some string input with escape \" { test, } ..."
        if (current_char == "\"") {
            buffer = get_next_string(input_line, current_pos)
            output = output buffer
            current_pos += length(buffer)
            continue
        }

        if (current_char == ",") {
            buffer = current_char
            while (++current_pos <= length(input_line)) {
                current_char = get_current_char(input_line, current_pos)
                #print "rem. trailing comma: traling block: char:" current_char
                if (current_char == " " || current_char == "\t") {
                    buffer = buffer current_char
                    continue
                } else if (is_end_trailing_comma_block(current_char)) {
                    break
                } else {
                    break
                }
            }

            if (is_end_trailing_comma_block(current_char)) {
                #print "rem. trailing comma: end trailing, buffer:-" buffer "-"
                gsub(/ +/, " ", buffer)
                gsub(/\t+/, "\t", buffer)
                gsub(/,/, "", buffer)
                output = output buffer current_char
                current_pos++
                continue
            }

            # end of line, trailing comma block is open
            if (current_pos > length(input_line)) {
                if (!Trailing_comma["buffer"]) {
                    Trailing_comma["buffer"] = buffer
                }
                #print "rem. trailing comma: block is open, returning"
                return trim_right(output)
            }

            # other char which breaks trailing comma block
            # process the character again
            print "rem. trailing comma: " current_char " breaks block, process again"
            output = output buffer
            continue
        }

        output = output current_char
        if (Trailing_comma["buffer"]) {
            Trailing_comma["buffer"] = ""
        }
        current_pos++
    }

    #print "rem. trailing comma: output:" output
    # add newline, because this is normally processed end of line
    output = trim_right(output)# "\n"
    return output
}

function is_end_trailing_comma_block(char) {
     return char == "]" || char == "}"
}

# get next json string from current line and position
# json doesnt support real multi line string
function get_next_string(input_line, current_pos,   current_char, buffer) {
    current_char = get_current_char(input_line, current_pos)
    buffer = current_char

    current_pos++;
    # read until the end of string or end of input line
    while (current_pos <= length(input_line)) {
        current_char = get_current_char(input_line, current_pos)
        buffer = buffer current_char

        # end of string
        if (current_char == "\"") {
            break
        }

        # escape, get next char immediatelly
        if (current_char == "\\") {
            current_char = get_current_char(input_line, ++current_pos)
            buffer = buffer current_char
        }

        current_pos++
    }

    return buffer
}

function get_current_char(input_line, current_pos) {
    return substr(input_line, current_pos, 1)
}

function trim_right(str) {
    gsub(/[ \t]+$/, "", str)
    return str
}

function quote(str, quoting_char) {
    quoting_char = quoting_char ? quoting_char : "'\''"
    return quoting_char str quoting_char
}
'
}

convert() {
    strip_alone_line_comments | strip_jsonc_specific_chars
    #| strip_trailing_commas
}

print_help() {
    echo "help"
}

main() {
    local options=$(getopt -o "h,f:" --long "help,aslib" -n 'jsonc2json options' -- "$@")
    set -- $options

    local input_file=""
    while true; do
        case "$1" in
            -h | --help)
                print_help
                return
                ;;
            -f)
                input_file="${2//\'/}"
                [ ! -f "$input_file" ] \
                    && echo "error: file \"$input_file\" doesn't exist" \
                    && return 1
                shift 2
                ;;
            # use as library via "source" command
            --aslib)
                return
                ;;
            --)
                shift
                break
                ;;
        esac
    done

    if [ -n "$input_file" ]; then
        convert < "$input_file"
    else
        convert
    fi
}

main "$@"

