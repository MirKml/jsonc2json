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
    is_comment = 0
}

/^[[:blank:]]*\/\*/ {
    is_comment = 1
    next
}

/\*\/[[:blank:]]*$/ {
    is_comment = 0
    next
}

/\/\*/ {

}

is_comment { next }
{ strip_comment($0) }

function strip_comment(input_line,      i, current_char, state, output)
{
    state = ""
    output = ""
    token = ""

    for (i = 0; i < length(input_line); i++) {
        print ("state: " state)
        current_char = substr($0, i, 1);

        if (current_char == "\"") {
            if (state == "in_string") {
                state = ""
            }
        }
        else if (current_char == "/") {
            if (state == "in_string")
        }

        token = token current_char
        state = handle_state(state, token)

        if (state == "exit") break
    }

    return output
}

function handle_state(state, token)
{
    if (!state == "") {
        if (token == "//") return "exit"
    }
    return state
}
'
}


main() {
    strip_line_comments | strip_multi_line_comments
}

_tests() {
    cat <<JSONC | main
{
    "prop1": "test" //line comment
}
JSONC
return

    cat <<JSONC | main
{
    "prop1": "prop1Value"
    // first comment
    /* second comment */
    "prop2": { "prop21": "prop21Value" }
    /* multi line in single line 22 @ ;'**/
    "prop2": { "prop21": "prop21Value" }

    "prop3": {
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
}
JSONC
}

_tests

