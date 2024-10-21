#!/usr/bin/env bash
# removes
set -euo pipefail

strip_alone_line_comments() {
    sed -e "/^[[:blank:]]*\/\//d" -e "/^[[:blank:]]*\/\*.*\*\/[[:blank:]]*$/d"
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
    in_multi_line_comment = 0
    inside_array = 0
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
    # no end of multi line comment found
    # we are still in comment, so print nothig
    if ($0 !~ /\*\//) {
        next
    }

    # remove everything from start to the end of comment
    # save it as current line a go to the next awk line pattern processing
    comment_position = index($0, "*/")
    if (comment_position > 0) {
        $0 = substr($0, comment_position + 2)
        $0 = trim_right($0)
        in_multi_line_comment = 0
    }

}
{
    $0 = remove_comments($0)
    print remove_trailing_comma($0)
}

function remove_comments(input_line,      current_pos, current_char, buffer, token_val, output) {

    output = ""
    # all awk string starts on index 1
    current_pos = 1

    # print "line: " input_line
    # print "length: " length(input_line)

    while (current_pos <= length(input_line)) {
        current_char = get_current_char(input_line, current_pos)
        #print "main iter: current_char: " current_char current_pos " output : " output

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

function remove_trailing_comma(input_line,
        current_pos, current_char, output, buffer, next_array_result, is_array_closed) {
    output = ""
    current_pos = 1

    # print "line: " input_line
    # print "length: " length(input_line)

    while (current_pos <= length(input_line)) {
        current_char = get_current_char(input_line, current_pos)
        # print "current_char_main: " current_char

        # string e.g. "some string input with escape \" rest of string"
        if (current_char == "\"") {
            buffer = get_next_string(input_line, current_pos)
            output = output buffer
            current_pos += length(buffer) - 1

        # array handling
        } else if (current_char == "[") {
            next_array_result = get_next_array(input_line, current_pos)
            buffer = next_array_result[0]
            is_array_closed = next_array_result[1]

            output = output buffer
            current_pos += length(buffer) - 1

        # other char
        } else {
            # next input char iteration
            output = output current_char
        }

        current_pos++
    }

    in_array
    return trim_right(output)
}

function get_next_array(input_line, current_pos,        current_char, buffer, is_closed) {
    current_char = get_current_char(input_line, current_pos)
    buffer = current_char

    is_closed = 0
    current_pos++;
    while (current_pos <= length(input_line)) {
        # string
        if (current_char == "\"") {
            buffer = get_next_string(input_line, current_pos)
            output = output buffer
            current_pos += length(buffer)
        } else if (current_char == "]") {
            is_closed = 1
            current_char = get_current_char(input_line, ++current_pos)
            buffer = buffer current_char
            break;
        }
    }

    if (is_closed) {
        gsub(/, +]$/, "]", buffer)
        gsub(/,]$/, "]", buffer)
    } else {
        gsub(/, *$/, ",", buffer)
    }

    return [buffer, is_closed]
}

# get next json string from current line and position
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
'
}

main() {
    strip_alone_line_comments | strip_jsonc_specific_chars
}

_tests() {
    local result_status=1

    local json_orig="\"arrayProp\": [ 0, 1, \"test\", ]"
    local json_expected="\"arrayProp\": [ 0, 1, \"test\" ]"
    local json_result=$(main <<< "$json_orig")
    #echo -e "original: $json_orig\nexpected: $json_expected\nresult: $json_result"
    local message="test trailing comma no. 1"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
    return
#===========
    json_orig="[ 0, 1, \"test\",] "
    json_expected="[ 0, 1, \"test\"]"
    json_result=$(main <<< "$json_orig")
    message="test trailing comma no. 2"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
#===========
    json_orig=$(cat <<JSONC
"prop1": [ "arrval1", "arrVal2", 12,
    "test",
    null,
],
JSONC
)
    local json_expected=$(cat <<JSONC
"prop1": [ "arrval1", "arrVal2", 12,
    "test",
    null,
],
JSONC
)
    json_result=$(main <<< "$json_orig")
    message="test trailing comma no. 2"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
#===========
    json_orig=$(cat <<JSONC
{
    "prop1": [ arrval1, "arrVal2", null,
               1234, "arraVal 3" ]
    "prop2": {
        "prop21",
    }
}
JSONC
)
    json_expected=$(cat <<JSONC
{
    "prop1": [ arrval1, "arrVal2", null,
               1234, "arraVal 3" ]
    "prop2": {
        "prop21",
    }
}
JSONC
)
    json_result=$(main <<< "$json_orig")
    message="test trailing comma no. 4"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
#===========
    json_orig=$(cat <<JSONC
    "prop1": /* "inner comment // */ "prop1 value"
JSONC
)
    json_expected="    \"prop1\":  \"prop1 value\""
    json_result=$(main <<< "$json_orig")
    message="test multi line comment no. 1"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
#===========
    message="test pure string with quotes"
    json_orig=\""pure JSON string with quotes \""
    json_expected="$json_orig"
    json_result=$(main <<< "$json_orig")
    message="test pure string with quotes"
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
#===========
    message="test not correctly closed string"
    json_orig="\"prop1\": \"unclosed string"
    json_expected="$json_orig"
    json_result=$(main <<< "$json_orig")
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
#===========
    message="test line comment in string, after json content"
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
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
#===========
    message="test multi line comment in string"
    json_orig=$(cat <<JSONC
{
    "prop1": "test\"with escape and /* multi line comment */ inside string" // after line comment
}
JSONC
)

    json_expected=$(cat <<JSONC
{
    "prop1": "test\"with escape and /* multi line comment */ inside string"
}
JSONC
)
    json_result=$(main <<< "$json_orig")
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
#===========
    message="test integration test no. 1"
    json_orig=$(cat <<JSONC
{
    "prop1": "prop1Value"
    // alone line comment
    /* alone multi line comment */
    "prop2": { "prop21": "prop21Value" }

    "prop3": {
        "prop31": {
            "prop311": null,
            "prop312: [ arr1, arr2,
                arr3,
                arr4,
            ]
        }
        /** comments some part of json, uncomment later
        "prop31Comment": {
            "prop311": null,
            "prop312: 22
        }
        */
        "prop32": {
            "prop32": "test"
            "prop312": 22
            "prop313": true
        }
    }
    /* "prop4": {
       } //
    */ "prop4": { // test
            "prop41": "value"
        }
}
JSONC
)

    json_expected=$(cat <<JSONC
{
    "prop1": "prop1Value"
    "prop2": { "prop21": "prop21Value" }

    "prop3": {
        "prop31": {
            "prop311": null,
            "prop312: [ arr1, arr2,
                arr3,
                arr4,
            ]
        }
        "prop32": {
            "prop32": "test"
            "prop312": 22
            "prop313": true
        }
    }
 "prop4": {
            "prop41": "value"
        }
}
JSONC
)
    json_result=$(main <<< "$json_orig")
    [ "$json_expected" = "$json_result" ] && echo "$message OK" \
        || { result_status=0; echo "$message FAILED"; }
}

_tests

