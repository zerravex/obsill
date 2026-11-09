#Requires AutoHotkey v2.0

; Turns an AutoHotkey hotkey string (config.json "hotkey", e.g. "^!l") into
; human-readable text ("Ctrl+Alt+L"). The raw syntax is meaningless to users,
; so every message that shows the hotkey goes through this first.
; Anything that cannot be recognised falls back to the raw characters, so
; a name that is not understood can never stop Obsill from starting.
class HotkeyText {
    ; raw   : the config.json "hotkey" value, e.g. "^!l" or "^!|" (the final key
    ;         is "|" = the vertical bar key, NOT a separator)
    ; returns readable text, e.g. "Ctrl+Alt+L" / "Ctrl+Alt+Vertical bar"; on a
    ;         modifier repeat or an empty result the raw string is returned.
    static Describe(raw) {
        mods := Map()
        i := 1
        n := StrLen(raw)
        ; Modifier prefix: each modifier symbol may appear once, in any order.
        while (i <= n) {
            c := SubStr(raw, i, 1)
            if (c != "^" && c != "!" && c != "+" && c != "#")
                break    ; not a modifier symbol -> the final key starts here
            if mods.Has(HotkeyText._ModName(c))
                break    ; a repeated modifier = not a plain prefix, show it as typed
            mods[HotkeyText._ModName(c)] := true
            i++
        }

        rest := SubStr(raw, i)
        key := HotkeyText._KeyName(rest)

        parts := []
        for name in ["Ctrl", "Alt", "Shift", "Win"]    ; fixed order, matches how people say it
            if mods.Has(name)
                parts.Push(name)
        if (rest != "" && key = "")
            parts.Push(rest)    ; not a name we know: better the real characters than nothing
        else if (key != "")
            parts.Push(key)
        text := Join(parts, "+")
        return (text != "") ? text : raw
    }

    static _ModName(c) {
        if (c == "^")
            return "Ctrl"
        if (c == "!")
            return "Alt"
        if (c == "+")
            return "Shift"
        return "Win"
    }

    ; Returns the readable name of the final key part, or "" when there is no
    ; final key or the text is not recognised.
    static _KeyName(rest) {
        if (rest = "")
            return ""
        ; Mouse buttons
        if (rest == "LButton")
            return "Left mouse button"
        if (rest == "RButton")
            return "Right mouse button"
        if (rest == "MButton")
            return "Middle mouse button"
        if (StrLower(rest) == "wheelup")
            return "Wheel up"
        if (StrLower(rest) == "wheeldown")
            return "Wheel down"
        ; Repeated modifier symbols ("^^a"): AHK takes the LAST one as the real
        ; modifier, so describe it that way instead of showing raw text.
        if (rest ~= "^[\^!+#]{2,}") {
            mods := Map()
            j := 1
            while (j <= StrLen(rest)) {
                ch := SubStr(rest, j, 1)
                if (ch != "^" && ch != "!" && ch != "+" && ch != "#")
                    break    ; the final key starts here
                mods.Clear()  ; AHK: only the last occurrence of each symbol counts
                mods[HotkeyText._ModName(ch)] := true
                j++
            }
            tail := SubStr(rest, j)
            name := HotkeyText._KeyName(tail)
            if (name = "" && tail != "")
                name := tail
            parts := []
            for m in ["Ctrl", "Alt", "Shift", "Win"]
                if mods.Has(m)
                    parts.Push(m)
            if (name != "")
                parts.Push(name)
            return Join(parts, "+")
        }
        ; Single character
        if (StrLen(rest) = 1) {
            c := rest
            if (c ~= "[A-Za-z]")
                return StrUpper(c)
            if (c ~= "[0-9]")
                return c
            if (c == " ")
                return "Space"
            literal := Map("`!", "Exclamation mark", "`"", "Quote mark", "$", "Dollar sign", "%", "Percent sign",
                           "&", "Ampersand", "'", "Single quote", "(", "Left parenthesis", ")", "Right parenthesis",
                           "*", "Asterisk", "+", "Plus sign", ",", "Comma", "-", "Hyphen", ".", "Period", "/", "Slash",
                           ":", "Colon", ";", "Semicolon", "<", "Less-than sign", "=", "Equal sign", ">", "Greater-than sign",
                           "?", "Question mark", "@", "At sign", "\", "Backslash", "[", "Left square bracket",
                           "]", "Right square bracket", "^", "Caret", "_", "Underscore", "`"", "Grave accent",
                           "{", "Left curly brace", "}", "Right curly brace", "|", "Vertical bar", "~", "Tilde")
            for ch, name in literal
                if (ch == c)
                    return name
            return ""
        }
        ; Named keys: F1-F24, Numpad0-Numpad9, single words (Enter, Tab, Space...)
        if (rest ~= "^[Ff][0-9]+$" || rest ~= "^[Ff]1[0-9]$" || rest ~= "^[Ff]2[0-4]$")
            return StrUpper(SubStr(rest, 1, 1)) SubStr(rest, 2)
        if (rest ~= "^Numpad\d+$")
            return rest
        if (rest ~= "^[A-Za-z]+$")
            return StrUpper(SubStr(rest, 1, 1)) SubStr(rest, 2)
        return ""
    }
}

Join(list, sep) {
    text := ""
    for item in list {
        if (text != "")
            text .= sep
        text .= item
    }
    return text
}
