#Requires AutoHotkey v2.0
#SingleInstance Off    ; must never replace a running Obsill

#Include lib\Version.ahk
#Include lib\Json.ahk
#Include lib\ObsillLog.ahk
#Include lib\DateFormat.ahk
#Include lib\Config.ahk
#Include lib\DailyNote.ahk

; ---------------------------------------------------------------------------------
; Obsill self-check. Verifies config.json, the hotkey, the Obsidian daily note
; settings and the exact file name of today's note. Changes nothing.
;   Obsill-Check.ahk            shows the result in a message box
;   Obsill-Check.ahk /silent    no message box (used by setup_obsill.bat)
; Exit code 0 = all good, 1 = a problem was found.
; The report is also written to <project>\logs\check_result.txt
; ---------------------------------------------------------------------------------

silent := false
for arg in A_Args {
    if (StrLower(arg) = "/silent")
        silent := true
}

SplitPath(A_ScriptDir, , &ProjectRoot)
LogDir := ProjectRoot "\logs"
ObsillLog.Init(LogDir)

result := RunCheck(ProjectRoot)
verdict := result.ok ? "PASSED" : "FAILED"
ObsillLog.Info("Self-check " verdict "`n" result.text)

try DirCreate(LogDir)
try FileDelete(LogDir "\check_result.txt")
try FileAppend(result.text "`n", LogDir "\check_result.txt", "UTF-8-RAW")

if !silent {
    icon := result.ok ? "Iconi" : "Icon!"
    MsgBox(result.text, "Obsill self-check", icon)
}
ExitApp(result.ok ? 0 : 1)

; ---------------------------------------------------------------------------------

RunCheck(projectRoot) {
    lines := []
    ok := true
    lines.Push("Obsill self-check (v" ObsillInfo.Version ")")

    try {
        cfg := ObsillConfig.Load(projectRoot "\config.json")
    } catch as e {
        lines.Push("[FAIL] " e.Message)
        return {ok: false, text: JoinLines(lines)}
    }
    lines.Push("[ OK ] config.json loaded")
    lines.Push("       vault root : " cfg.VaultRoot)

    try {
        Hotkey(cfg.Hotkey, (*) => 0, "Off")
        lines.Push("[ OK ] hotkey     : " cfg.Hotkey)
    } catch as e {
        lines.Push("[FAIL] hotkey '" cfg.Hotkey "' is not valid: " e.Message)
        ok := false
    }

    try {
        s := DailyNote.ResolveSettings(cfg)
        folderText := (s.folder = "") ? "(vault root)" : s.folder
        templateText := (s.template = "") ? "(none)" : s.template " (not applied in v0.0.1)"
        lines.Push("[ OK ] daily note settings from: " s.source)
        lines.Push("       folder     : " folderText)
        lines.Push("       format     : " s.format)
        lines.Push("       template   : " templateText)

        stamp := A_Now
        path := DailyNote.NotePath(cfg, s, stamp)
        SplitPath(path, &fileName, &dir)
        lines.Push("[ OK ] today's note file name: " fileName)
        lines.Push("       full path  : " path)
        noteText := FileExist(path) ? "yes" : "no (it will be created on your first log)"
        dirText := DirExist(dir) ? "yes" : "no (it will be created on your first log)"
        lines.Push("       note exists: " noteText)
        lines.Push("       folder exists: " dirText)

        newest := DailyNote.NewestNoteName(dir)
        if (newest != "")
            lines.Push("       newest .md in that folder: " newest "   <- its naming pattern should match today's file name")
        else
            lines.Push("       (no .md files in that folder yet, so the naming pattern could not be compared)")
    } catch as e {
        lines.Push("[FAIL] " e.Message)
        ok := false
    }

    verdict := ok ? "RESULT: PASS" : "RESULT: FAIL"
    lines.Push(verdict)
    return {ok: ok, text: JoinLines(lines)}
}

JoinLines(arr) {
    out := ""
    for line in arr {
        if (out != "")
            out .= "`n"
        out .= line
    }
    return out
}
