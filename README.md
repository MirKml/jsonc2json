# jsonc2json.sh
JSONC to JSON conversion utility in shell (bash with help of awk, sed), for shell

## Quick usage
from command line - `./jsonc2json.sh < config.jsonc > config.json`

as bash library
- loads the source script with `--aslib` option as library,
- then use `convert` function with $1 parameter as JSONC source string

```bash
#!/usr/bin/env bash
set -euo pipefail

source "./jsonc2json.sh --aslib"
local original_json="\"arrayProp\": [ 0, 1, \"test\", ]"

convert <<< "$original_json"
```

## Description
It converts JSONC file - JSON with comments - into JSON file. This format is more appropriate for human-readable
configurations rather then pure JSON. In pure JSON, comments aren't allowed.

There are many tools with same purpose, but mostly in JavaScript, Golang. I couldn't find anything for simple usage
with pure bash environment. So I tried to write this one.
It's implemented in mostly (g)awk and bash, sed without any other dependencies.
It's useful anywhere bash is used frequently e.g. administration task, configurations, DevOps tooling, CI pipelines.

Supported features
 - single-line comments `// some comment`
 - multi-line comments `/* many lines */`
 - trailing commas for objects, arrays `{ "prop": [ "item1", "item2", ], }` => `{ "prop": [ "item1", "item2" ] }`

All these are removed during conversion.

Other JSONC like formats have many other features, e.g. [JSON5](https://github.com/json5/json5), [HJSON](https://github.com/hjson/) implement empty values, numbers ...
But this is out of scope of this utility.

Benefits - It isn't based on regexps, simple scanner/tokenizer approach is used, mostly in awk. I think it covers more use cases and
it's more reliable. Regexps are used in corner cases.

Shortcomings
 - Scanner is very simple, isn't rock solid, extensible, understandable. Mostly because of awk, sed and bash, which aren't very favorable for such task. It
 - No syntax checks, errors are provided. It's out of scope. It's up to you if your JSONC and converted JSON is valid - use e.g. famous [jq](https://github.com/jqlang/jq/) tool.

## Example

JSONC config.jsonc file

```jsonc
{
    // first property with value
    "prop1": "prop1Value",
    /* second property
       with another values */
    "prop2": { "prop21": "prop21Value" },

    "prop3": {
        "prop31": {
             /** maybe this is more readable
              *  multi-line comment
              */
            "prop311": null,
            "prop312": [ "arr1", "arr2",
                "arr3",
                "arr4", // trailing comma
            ], // another trailing comma
        },
        /* comment some part of json, useful for configuration development
        "prop31Comment": {
            "prop311": null,
            "prop312: 22
        }
        */
        "prop32": {
            "prop32": "test",
            "prop312": 22,
            "prop313": true
        }
    },
    /* "prop4": {
       } // single line inside multi-line
    start property after multi-line */    "prop4": {
        "prop41": "value"
     },
}
```

can be converted into JSON config.json file with command `cat config.jsonc | ./jsonc2json.sh > config.json`
```json
{
    "prop1": "prop1Value",
    "prop2": { "prop21": "prop21Value" },
    "prop3": {
        "prop31": {
            "prop311": null,
            "prop312": [ "arr1", "arr2",
                "arr3",
                "arr4"
            ]
        },
        "prop32": {
            "prop32": "test",
            "prop312": 22,
            "prop313": true
        }
    },
    "prop4": {
        "prop41": "value"
     }
}
```
