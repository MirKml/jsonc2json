# jsonc2json
Jsonc to json conversion tool in shell (bash)

It converts JSONC - JSON with comments - file into JSON file. This format is more appropriate for human readable
configurations then pure JSON. In pure JSON comments aren't allowed.

There are many tools with same purpose, but mostly in Javascript, Golang. I coudn't find anything for simple usage
with pure bash environment. So I tried to write this one.
It's implemented in mostly (g)awk and bash, sed without any other dependencies.
It's useful anywhere bash is used frequently e.g. administration task, configurations, devops tooling, CI pipelines.

Supported features
 - single-line comments // some commnet
 - multi-line comments /* many lines */
 - trailing commas for objects, arrays `{ "prop": [ "item1", "item2", ], }` => `{ "prop": [ "item1", "item2" ] }`

All these are removed during conversion.

Other JSONC like formats have many other features, e.g. [JSON5](https://github.com/json5/json5), [HJSON](https://github.com/hjson/) empty values, numbers ...
But this is out of scope of this utility.

benefits - It isn't based on regexps, simple scanner/tokenizer approach is used, mostly in awk. I think it covers more use cases and
it's more reliable. Regexps are used in corner cases.

shortcommings - Scanner isn't rock solid, extensible, understandable. Mostly because of awk, sed and bash, which aren't
very favourable for such task.

## Example

JSONC file

```jsonc
{
    // first property with value
    "prop1": "prop1Value",
    /* second property
       with another values */
    "prop2": { "prop21": "prop21Value" }

    "prop3": {
        "prop31": {
             /** maybe this is more readable
              *  multi-line comment
              */
            "prop311": null,
            "prop312: [ arr1, arr2,
                arr3,
                arr4, // trailing comma
            ], // another trailing comma
        },
        /* comment some part of json, useful for configuration development
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
    },
    /* "prop4": {
       } // single line inside multi-line
    start property after multi-line */ "prop4": {
            "prop41": "value"
        },
}
```
