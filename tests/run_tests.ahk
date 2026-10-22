#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\src\lib\Version.ahk
#Include ..\src\lib\Json.ahk
#Include ..\src\lib\ObsillLog.ahk
#Include ..\src\lib\DateFormat.ahk
#Include ..\src\lib\Config.ahk
#Include ..\src\lib\DailyNote.ahk

; Unit tests for the pure logic: date format converter, JSON reader, folder
; normalising and entry building. Double-click to run; a message box shows the result.
; Add a test here whenever you fix a bug.

Results := {passed: 0, failed: []}

Check(name, actual, expected) {
    if (actual == expected)
        Results.passed += 1
    else
        Results.failed.Push(name "`n      expected: [" expected "]`n      actual:   [" actual "]")
}

CheckThrows(name, fn) {
    try {
        fn()
    } catch {
        Results.passed += 1
        return
    }
    Results.failed.Push(name "`n      expected an error, but none was thrown")
}

; ---- DateFormat: the weekday is part of the daily note name -------------------------
F := "YYYY-MM-DD-ddd"
Check("Tue", DateFormat.Format(F, "20261020090000"), "2026-10-20-Tue")
Check("Wed", DateFormat.Format(F, "20261021090000"), "2026-10-21-Wed")
Check("Thu", DateFormat.Format(F, "20261022090000"), "2026-10-22-Thu")
Check("Fri", DateFormat.Format(F, "20261023090000"), "2026-10-23-Fri")
Check("Sat", DateFormat.Format(F, "20261024090000"), "2026-10-24-Sat")
Check("Sun", DateFormat.Format(F, "20261025090000"), "2026-10-25-Sun")
Check("Mon", DateFormat.Format(F, "20261026090000"), "2026-10-26-Mon")
Check("leap day 2024", DateFormat.Format(F, "20240229235959"), "2024-02-29-Thu")
Check("year 2000", DateFormat.Format(F, "20000101000000"), "2000-01-01-Sat")
Check("midnight keeps the day", DateFormat.Format(F, "20261022000000"), "2026-10-22-Thu")

Check("dddd", DateFormat.Format("YYYY-MM-DD-dddd", "20260105120000"), "2026-01-05-Monday")
Check("subfolders", DateFormat.Format("YYYY/MM/YYYY-MM-DD", "20261022090000"), "2026/10/2026-10-22")
Check("literal + short tokens", DateFormat.Format("[Week] D MMM YY", "20260105120000"), "Week 5 Jan 26")
Check("long date", DateFormat.Format("dddd, MMMM D, YYYY", "20261022090000"), "Thursday, October 22, 2026")
Check("literal with dash", DateFormat.Format("[Daily-]YYYY", "20261022090000"), "Daily-2026")
Check("M and D unpadded", DateFormat.Format("M-D", "20260305090000"), "3-5")
Check("MM and DD padded", DateFormat.Format("MM-DD", "20260305090000"), "03-05")

CheckThrows("time token HH is unsupported", () => DateFormat.Format("YYYY-MM-DD HH:mm", "20261022090000"))
CheckThrows("dd is unsupported", () => DateFormat.Format("YYYY-MM-DD-dd", "20261022090000"))
CheckThrows("Do is unsupported", () => DateFormat.Format("YYYY-MM-Do", "20261022090000"))
CheckThrows("backslash", () => DateFormat.Format("YYYY\MM", "20261022090000"))
CheckThrows("unclosed bracket", () => DateFormat.Format("[oops", "20261022090000"))
CheckThrows("empty format", () => DateFormat.Format("", "20261022090000"))
CheckThrows("bad timestamp", () => DateFormat.Format("YYYY", "abc"))

; ---- Json ---------------------------------------------------------------------------
j := Json.Parse('{"folder":"__taskir/_instances/allofmydayz","format":"YYYY-MM-DD-ddd"}')
Check("json: your real daily-notes.json / folder", j["folder"], "__taskir/_instances/allofmydayz")
Check("json: your real daily-notes.json / format", j["format"], "YYYY-MM-DD-ddd")
Check("json: has no template key", j.Has("template"), false)

j := Json.Parse('{"p":"D:\\Notes\\My Vault","u":"\u0026 \u00e9","t":true,"f":false,"n":null,"x":-12.5,"a":[1,"two",{"k":"v"}],"o":{}}')
Check("json: escaped backslashes", j["p"], "D:\Notes\My Vault")
Check("json: unicode escapes", j["u"], "& " Chr(0xE9))
Check("json: true", j["t"], 1)
Check("json: false", j["f"], 0)
Check("json: null", j["n"], "")
Check("json: number", j["x"], -12.5)
Check("json: array length", j["a"].Length, 3)
Check("json: array item", j["a"][2], "two")
Check("json: nested object", j["a"][3]["k"], "v")
Check("json: empty object", j["o"].Count, 0)
Check("json: BOM tolerated", Json.Parse(Chr(0xFEFF) '{"a":"b"}')["a"], "b")
Check("json: array at top level", Json.Parse('["x","y"]').Length, 2)
CheckThrows("json: missing value", () => Json.Parse('{"a":}'))
CheckThrows("json: trailing comma", () => Json.Parse('{"a":1,}'))
CheckThrows("json: unterminated string", () => Json.Parse('{"a":"b'))
CheckThrows("json: garbage", () => Json.Parse('not json'))

; ---- DailyNote.NormalizeFolder ------------------------------------------------------
Check("folder: as stored by Obsidian", DailyNote.NormalizeFolder("__taskir/_instances/allofmydayz"), "__taskir/_instances/allofmydayz")
Check("folder: backslashes and edges", DailyNote.NormalizeFolder("\Journal\Daily\"), "Journal/Daily")
Check("folder: empty = vault root", DailyNote.NormalizeFolder(""), "")
Check("folder: slash only", DailyNote.NormalizeFolder("/"), "")
Check("folder: duplicate slashes and dots", DailyNote.NormalizeFolder("a//b/./c"), "a/b/c")
CheckThrows("folder: parent reference", () => DailyNote.NormalizeFolder("../x"))
CheckThrows("folder: parent reference inside", () => DailyNote.NormalizeFolder("a/../../x"))
CheckThrows("folder: drive path", () => DailyNote.NormalizeFolder("C:/x"))

; ---- DailyNote.BuildEntry -----------------------------------------------------------
T := "- {time} {text}"
Check("entry: single line", DailyNote.BuildEntry(T, "14:32", "hello"), "- 14:32 hello")
Check("entry: trims", DailyNote.BuildEntry(T, "14:32", "  hi  `n"), "- 14:32 hi")
Check("entry: multi-line is indented", DailyNote.BuildEntry(T, "14:32", "a`nb`n`nc"), "- 14:32 a`n  b`n`n  c")
Check("entry: CRLF input", DailyNote.BuildEntry(T, "14:32", "a`r`nb"), "- 14:32 a`n  b")
Check("entry: text is not re-expanded", DailyNote.BuildEntry(T, "09:00", "use {time} here"), "- 09:00 use {time} here")
Check("entry: no list marker, no indent", DailyNote.BuildEntry("{time} {text}", "14:32", "x`ny"), "14:32 x`ny")
Check("entry: numbered list indent", DailyNote.BuildEntry("1. {time} {text}", "14:32", "x`ny"), "1. 14:32 x`n   y")

; ---- report -------------------------------------------------------------------------
report := Results.passed " passed, " Results.failed.Length " failed."
for item in Results.failed
    report .= "`n`nFAIL: " item
MsgBox(report, "Obsill tests", Results.failed.Length ? "Icon!" : "Iconi")
ExitApp(Results.failed.Length ? 1 : 0)
