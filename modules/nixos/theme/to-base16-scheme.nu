# Converts a base 16 theme exported from terminal.sexy as "JSON Scheme" to base16 yaml
def main [ json_string ] {
    $json_string
        | from json
        | get color
        | enumerate
        | each {
            {
                ("base" + ($in.index | format number | get upperhex | str replace "0x" "0")): $in.item
            }
        }
        | into record
        | to yaml
}