#Requires AutoHotkey v2.0

; Converts an Obsidian (Moment.js style) date format such as "YYYY-MM-DD-ddd"
; into text, e.g. "2026-10-22-Thu".
;
; Why not AutoHotkey's FormatTime? Its tokens differ from Moment's (yyyy vs YYYY,
; dd vs DD) and its weekday/month names follow the Windows language, while the
; daily note's file name must match what Obsidian generates. So this converter:
;   * implements the Moment tokens itself, with ENGLISH names;
;   * never guesses: any token it does not support throws an error.
;
; Supported tokens:  YYYY YY | MMMM MMM MM M | DD D | dddd ddd
; Literal text:      wrap it in square brackets, e.g.  [Week]
; Anything else that is a letter (HH, mm, Do, dd, ...) is NOT supported and throws.
; Characters that are not letters (- _ . space / ,) are copied as they are.
class DateFormat {
    static Tokens := ["YYYY", "YY", "MMMM", "MMM", "MM", "M", "DD", "D", "dddd", "ddd"]    ; longest first per family
    static DayShort := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static DayLong := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static MonthShort := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static MonthLong := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    ; fmt   : Moment-style format string, e.g. "YYYY-MM-DD-ddd"
    ; stamp : AutoHotkey timestamp YYYYMMDDHH24MISS, e.g. A_Now
    static Format(fmt, stamp) {
        if (fmt = "")
            throw ValueError("The date format is empty.")
        if !RegExMatch(stamp, "^\d{14}$")
            throw ValueError("Invalid timestamp: " stamp)

        year := SubStr(stamp, 1, 4)
        month := Integer(SubStr(stamp, 5, 2))
        day := Integer(SubStr(stamp, 7, 2))
        weekday := Integer(FormatTime(stamp, "WDay"))    ; 1 = Sunday ... 7 = Saturday (numeric, locale independent)

        out := ""
        i := 1
        n := StrLen(fmt)
        while (i <= n) {
            c := SubStr(fmt, i, 1)

            ; [literal text]
            if (c == "[") {
                close := InStr(fmt, "]", true, i + 1)
                if (!close)
                    throw ValueError("Unclosed '[' in date format: " fmt)
                out .= SubStr(fmt, i + 1, close - i - 1)
                i := close + 1
                continue
            }

            ; supported token (case-sensitive, longest match first)
            matched := ""
            for token in DateFormat.Tokens {
                if (SubStr(fmt, i, StrLen(token)) == token) {
                    matched := token
                    break
                }
            }
            if (matched != "") {
                out .= DateFormat._Render(matched, year, month, day, stamp, weekday)
                i += StrLen(matched)
                continue
            }

            if RegExMatch(c, "^[A-Za-z]$")
                throw ValueError("Unsupported date format token '" c "' at position " i " in '" fmt "'. Supported: YYYY YY MMMM MMM MM M DD D dddd ddd (wrap literal text in [ ]).")
            if (c == "\")
                throw ValueError("Backslash is not supported in the date format: " fmt)

            out .= c
            i += 1
        }
        return out
    }

    static _Render(token, year, month, day, stamp, weekday) {
        if (token == "YYYY")
            return year
        if (token == "YY")
            return SubStr(year, 3, 2)
        if (token == "MMMM")
            return DateFormat.MonthLong[month]
        if (token == "MMM")
            return DateFormat.MonthShort[month]
        if (token == "MM")
            return SubStr(stamp, 5, 2)
        if (token == "M")
            return month
        if (token == "DD")
            return SubStr(stamp, 7, 2)
        if (token == "D")
            return day
        if (token == "dddd")
            return DateFormat.DayLong[weekday]
        if (token == "ddd")
            return DateFormat.DayShort[weekday]
        throw ValueError("Internal error: unhandled token " token)
    }
}
