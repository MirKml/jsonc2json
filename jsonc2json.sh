#!/usr/bin/env bash
# removes
set -euo pipefail

strip_line_comments() {
    sed -e "/^[[:blank:]]*\/\//d" -e "/^[[:blank:]]*\/\*.*\*\/[[:blank:]]*$/d"
}

strip_multi_line_comments() {
    awk \
'
BEGIN {
    in_multi_line_comment = 0
}

/^[[:blank:]]*\/\*/ {
    in_multi_line_comment = 1
    next
}

/\*\/[[:blank:]]*$/ {
    in_multi_line_comment = 0
    next
}

# return all after multiline comment end - "*/"
in_multi_line_comment == 1 {
    # no end of multi line comment foud
    # we are still in comment, so print nothig
    if ($0 !~ /\*\//) {
        next
    }

    # remove all to the end of comment
    # save it as current line a go to the next awk line processing
    comment_position = index($0, "*/")
    if (comment_position > 0) {
        $0 = substr($0, comment_position + 2)
        $0 = trim_right($0)
        in_multi_line_comment = 0
    }

}

{ print strip_comments($0) }

function strip_comments(input_line,      current_pos, current_char, token_val, output)
{

    output = ""
    # necessary substr() starts with 1
    current_pos = 1

    # print "line: " input_line
    # print "length: " length(input_line)

    while (current_pos <= length(input_line)) {
        current_char = get_current_char(input_line, current_pos)
        # print "main iter: current_char: " current_char current_pos " output : " output

        # string e.g. "some string input with escape \" rest of string"
        if (current_char == "\"") {
            token_val = ""

            # read until the end of string or end of input line
            while (++current_pos <= length(input_line)) {
                current_char = get_current_char(input_line, current_pos)

                # end of string
                if (current_char == "\"") {
                    break
                }

                # escape, get next char immediatelly
                if (current_char == "\\") {
                    token_val = token_val current_char
                    current_char = get_current_char(input_line, ++current_pos)
                }

                token_val = token_val current_char
            }

            # it was finished because the end of input line
            if (current_pos >= length(input_line)) {
                output = output "\"" token_val
                # last characted on line was ", but it was skipped via break
                if (current_char == "\"") {
                    output = output "\""
                }
            # it was break because of end of string
            } else {
                output = output "\"" token_val "\""
            }

            # next input char iteration
            current_pos++
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
                    # if latest 2 string in token are */ - closing comment
                    if (substr(token_val, length(token_val) - 1) == "*/") {
                        # print "found multiline comment: " token_val
                        # next input char iteration
                        break
                    }
                }

                # whole line was processed and we are still in multiline comment
                if (current_pos >= length(input_line)) {
                    in_multi_line_comment = 1
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

function get_current_char(input_line, current_pos) {
    return substr(input_line, current_pos, 1)
}

function trim_right(str) {
    gsub(/[ \t]+$/, "", str)
    return str
}
'
}

main() {
    strip_line_comments | strip_multi_line_comments
}

_tests() {
    result_status=1

    local json_orig=$(cat <<JSONC
    "prop1": /* "inner comment // */ "prop1 value"
JSONC
)
    local json_expected='    "prop1":  "prop1 value"'
    local json_result=$(main <<< "$json_orig")
    local message="test no. 1"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }

    json_orig=\""pure JSON string with quotes \""
    json_expected="$json_orig"
    json_result=$(main <<< "$json_orig")
    local message="test no. 2"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }

    #  not correctly closed string
    json_orig="\"prop1\": \"unclosed string"
    json_expected="$json_orig"
    json_result=$(main <<< "$json_orig")
    local message="test no. 3"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }


    # test for: line commnet
    # - in string
    # - after json content
    json_orig=$(cat <<JSONC
{
    "prop1": "test\"with escape and // line comment start inside string" // after line comment
}
JSONC
)

    json_expected=$(cat <<JSONC
{
    "prop1": "test\"with escape and // line comment start inside string"
}
JSONC
)
    json_result=$(main <<< "$json_orig")
    local message="test no. 4"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
    # echo "result: $json_result"; echo "expected: $json_expected"

#    cat <<JSONC | main
#{
#    "prop1": "prop1Value"
#    // first comment
#    /* second comment */
#    "prop2": { "prop21": "prop21Value" }
#    /* multi line in single line 22 @ ;'**/
#    "prop2": { "prop21": "prop21Value" }
#
#    "prop3": {
#        /** comments some part of json, uncomment later
#        "prop31Comment": {
#            "prop311": null,
#            "prop312: 22
#        }
#        */
#        "prop32": {
#            "prop32": "test"
#            "prop312": 22
#            "prop313": true
#        }
#    }
#}
#JSONC
}

_tests

