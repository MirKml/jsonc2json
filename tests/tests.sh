#!/usr/bin/env bash
set -euo pipefail

# $1 original json
# $2 expected json
# $3 message
test_run() {
    local original_json="$1"
    local expected_json="$2"
    local message="${3:-"test (no message)"}"

    local result_status=0
    local result_json=$(convert <<< "$original_json")

    #echo -e "original: $original_json\nexpected: $expected_json\nresult:   $result_json"
    [ "$expected_json" = "$result_json" ] && echo "$message OK" \
        || { result_status=1; echo "$message FAILED"; }

    return $result_status
}

load_lib() {
    local script_dir="$1"
    source "$script_dir"/jsonc2json.sh --aslib
}

debug_test() {
    local script_dir=$(dirname $0)
    load_lib "$(dirname $0)"

    local original_json="\"arrayProp\": [ 0, 1, \"test\", ]"
    local expected_json="\"arrayProp\": [ 0, 1, \"test\" ]"
    echo -e "original: $original_json\nexpected: $expected_json\nresult:   \n"
    $(convert <<< "$original_json")
}
#debug_test
#exit

all_tests() {
    load_lib "$(dirname $0)"

    local result_status=0

    local message="test trailing comma no. 1"
    local original_json="\"arrayProp\": [ 0, 1, \"test\", ]"
    local expected_json="\"arrayProp\": [ 0, 1, \"test\" ]"
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi
#===========

    message="test trailing comma no. 2"
    original_json="[ 0, 1, \"test\",] "
    expected_json="[ 0, 1, \"test\" ]"
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi

#===========

    message="test trailing comma no. 3"
    original_json=$(cat <<JSONC
"prop1": [ "arrval1", "arrVal2", 12,
    "test",
    null,
    ],
JSONC
)
    expected_json=$(cat <<JSONC
"prop1": [ "arrval1", "arrVal2", 12,
    "test",
    null
    ],
JSONC
)
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi
#===========

    message="test trailing comma no. 4"
    original_json=$(cat <<JSONC
{
    "prop1": [
       "arrval1", "arrVal2", null,
        1234, "arraVal 3",
    ],
    "prop2": {
        "prop21": null,
        "prop22": null,
    }
}
JSONC
)
    expected_json=$(cat <<JSONC
{
    "prop1": [
       "arrval1", "arrVal2", null,
        1234, "arraVal 3"
    ],
    "prop2": {
        "prop21": null,
        "prop22": null
    }
}
JSONC
)
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi
#===========

    message="test multi line comment no. 1"
    original_json=$(cat <<JSONC
    "prop1": /* "inner comment // */ "prop1 value"
JSONC
)
    expected_json="    \"prop1\":  \"prop1 value\""
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi

#===========

    message="test pure string with quotes"
    original_json=\""pure JSON string with quotes \""
    expected_json="$original_json"
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi
#===========

    message="test not correctly closed string"
    original_json="\"prop1\": \"unclosed string"
    expected_json="$original_json"

    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi
#===========

    message="test line comment in string, after json content"
    original_json=$(cat <<JSONC
{
    "prop1": "test\"with escape and // line comment start inside string" // after line comment
}
JSONC
)

    expected_json=$(cat <<JSONC
{
    "prop1": "test\"with escape and // line comment start inside string"
}
JSONC
)
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi
#===========

    message="test multi line comment in string"
    original_json=$(cat <<JSONC
{
    "prop1": "test\"with escape and /* multi line comment */ inside string" // after line comment
}
JSONC
)

    expected_json=$(cat <<JSONC
{
    "prop1": "test\"with escape and /* multi line comment */ inside string"
}
JSONC
)
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi
#===========

    message="test integration test no. 1"
    original_json=$(cat <<JSONC
{
    "prop1": "prop1Value",
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
        /** comment some part of json, uncomment later
        "prop31Comment": {
            "prop311": null,
            "prop312: 22
        }
        */
        "prop32": {
            "prop32": "test"
            "prop312": 22,
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

    expected_json=$(cat <<JSONC
{
    "prop1": "prop1Value",
    "prop2": { "prop21": "prop21Value" }

    "prop3": {
        "prop31": {
            "prop311": null,
            "prop312: [ arr1, arr2,
                arr3,
                arr4
            ]
        }
        "prop32": {
            "prop32": "test"
            "prop312": 22,
            "prop313": true
        }
    }
 "prop4": {
            "prop41": "value"
        }
}
JSONC
)
    if ! test_run "$original_json" "$expected_json" "$message"; then
        result_status=1
    fi
}

all_tests
