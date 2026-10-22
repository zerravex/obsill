#Requires AutoHotkey v2.0

; Minimal, read-only JSON parser.
;   Json.Parse(text) -> Map (object) / Array / String / Number / 1 (true) / 0 (false) / "" (null)
; Throws an Error that names the character position when the text is not valid JSON.
; Obsill only READS JSON: config.json (written by Setup-Obsill.ps1) and the
; .obsidian\*.json files (written by Obsidian). It never writes JSON itself.
class Json {
    static Parse(text) {
        parser := Json._Parser(text)
        return parser.ParseDocument()
    }

    class _Parser {
        __New(text) {
            if (text != "" && Ord(text) = 0xFEFF)
                text := SubStr(text, 2)
            this.s := text
            this.n := StrLen(text)
            this.i := 1
        }

        ParseDocument() {
            this.SkipWs()
            value := this.ParseValue()
            this.SkipWs()
            if (this.i <= this.n)
                this.Fail("Unexpected extra content")
            return value
        }

        Fail(message) {
            throw Error("Invalid JSON at character " this.i ": " message)
        }

        Peek() {
            return SubStr(this.s, this.i, 1)
        }

        SkipWs() {
            while (this.i <= this.n) {
                c := SubStr(this.s, this.i, 1)
                if (c != " " && c != "`t" && c != "`n" && c != "`r")
                    break
                this.i += 1
            }
        }

        ParseValue() {
            this.SkipWs()
            if (this.i > this.n)
                this.Fail("Unexpected end of text")
            c := this.Peek()
            if (c = "{")
                return this.ParseObject()
            if (c = "[")
                return this.ParseArray()
            if (c = '"')
                return this.ParseString()
            if (SubStr(this.s, this.i, 4) == "true") {
                this.i += 4
                return true
            }
            if (SubStr(this.s, this.i, 5) == "false") {
                this.i += 5
                return false
            }
            if (SubStr(this.s, this.i, 4) == "null") {
                this.i += 4
                return ""
            }
            return this.ParseNumber()
        }

        ParseObject() {
            obj := Map()
            this.i += 1
            this.SkipWs()
            if (this.Peek() = "}") {
                this.i += 1
                return obj
            }
            loop {
                this.SkipWs()
                if (this.Peek() != '"')
                    this.Fail("Expected a string key")
                key := this.ParseString()
                this.SkipWs()
                if (this.Peek() != ":")
                    this.Fail("Expected ':' after key")
                this.i += 1
                obj[key] := this.ParseValue()
                this.SkipWs()
                c := this.Peek()
                this.i += 1
                if (c = ",")
                    continue
                if (c = "}")
                    break
                this.i -= 1
                this.Fail("Expected ',' or '}'")
            }
            return obj
        }

        ParseArray() {
            arr := []
            this.i += 1
            this.SkipWs()
            if (this.Peek() = "]") {
                this.i += 1
                return arr
            }
            loop {
                arr.Push(this.ParseValue())
                this.SkipWs()
                c := this.Peek()
                this.i += 1
                if (c = ",")
                    continue
                if (c = "]")
                    break
                this.i -= 1
                this.Fail("Expected ',' or ']'")
            }
            return arr
        }

        ParseString() {
            this.i += 1
            out := ""
            while (this.i <= this.n) {
                c := SubStr(this.s, this.i, 1)
                if (c == '"') {
                    this.i += 1
                    return out
                }
                if (c == "\") {
                    this.i += 1
                    e := SubStr(this.s, this.i, 1)
                    if (e == '"')
                        out .= '"'
                    else if (e == "\")
                        out .= "\"
                    else if (e == "/")
                        out .= "/"
                    else if (e == "b")
                        out .= "`b"
                    else if (e == "f")
                        out .= "`f"
                    else if (e == "n")
                        out .= "`n"
                    else if (e == "r")
                        out .= "`r"
                    else if (e == "t")
                        out .= "`t"
                    else if (e == "u") {
                        hex := SubStr(this.s, this.i + 1, 4)
                        if !RegExMatch(hex, "^[0-9A-Fa-f]{4}$")
                            this.Fail("Bad \u escape")
                        out .= Chr(Integer("0x" hex))
                        this.i += 4
                    } else
                        this.Fail("Unknown escape \" e)
                    this.i += 1
                } else {
                    out .= c
                    this.i += 1
                }
            }
            this.Fail("Unterminated string")
        }

        ParseNumber() {
            if !RegExMatch(this.s, "A)-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", &m, this.i)
                this.Fail("Unexpected character '" this.Peek() "'")
            this.i += StrLen(m[0])
            return Number(m[0])
        }
    }
}
