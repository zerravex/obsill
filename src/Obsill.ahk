#Requires AutoHotkey v2.0
#SingleInstance Force

#Include lib\Version.ahk
#Include lib\Json.ahk
#Include lib\ObsillLog.ahk
#Include lib\DateFormat.ahk
#Include lib\Config.ahk
#Include lib\DailyNote.ahk
#Include lib\InputWindow.ahk

; ---------------------------------------------------------------------------------
; Obsill - Obsidian Life Logger. Entry point: global hotkey -> quick log window ->
; timestamped entry appended to today's daily note.
; ---------------------------------------------------------------------------------

SplitPath(A_ScriptDir, , &ProjectRoot)    ; the folder that contains "src"
ConfigPath := ProjectRoot "\config.json"
LogDir := ProjectRoot "\logs"

ObsillLog.Init(LogDir)
ObsillLog.Info("---- Obsill " ObsillInfo.Version " starting ----")
OnError(LogUncaught)
OnExit(LogExit)

try {
    Cfg := ObsillConfig.Load(ConfigPath)
} catch as e {
    ObsillLog.Err("Config problem: " e.Message)
    answer := MsgBox(e.Message "`n`nRun setup now?", "Obsill", "YesNo Icon!")
    if (answer = "Yes")
        Run('"' ProjectRoot '\setup_obsill.bat"')
    ExitApp(1)
}

try {
    Hotkey(Cfg.Hotkey, OnHotkey)
} catch as e {
    ObsillLog.Err("Could not register hotkey '" Cfg.Hotkey "': " e.Message)
    MsgBox("The hotkey '" Cfg.Hotkey "' is not valid.`n`n" e.Message "`n`nFix 'hotkey' in config.json or run setup_obsill.bat again.", "Obsill", "Iconx")
    ExitApp(1)
}
InputWindow.RegisterKeys()
BuildTrayMenu()
Persistent()

ObsillLog.Info("Ready. Hotkey: " Cfg.Hotkey "  Vault: " Cfg.VaultRoot "  Mode: " Cfg.DailyNoteMode)
TrayTip("Ready. Press " Cfg.Hotkey " to log.", "Obsill")
return

; ---------------------------------------------------------------------------------

OnHotkey(*) {
    stamp := A_Now    ; captured NOW, when the window opens
    InputWindow.Open(stamp, FormatTime(stamp, Cfg.TimeFormat), SaveEntry)
}

; Called by the window. Returns "" on success, otherwise a message for the user.
SaveEntry(text, stamp) {
    try {
        DailyNote.AppendEntry(Cfg, text, stamp)
        return ""
    } catch as e {
        ObsillLog.Err("Save failed: " e.Message)
        SaveFallback(text, stamp)
        return "Could not save to your daily note:`n" e.Message "`n`nA copy was written to logs\unsaved_entries.txt"
    }
}

; Last resort: the text must never be lost.
SaveFallback(text, stamp) {
    try {
        FileAppend(FormatTime(stamp, "yyyy-MM-dd HH:mm") "  " StrReplace(text, "`r`n", "`n") "`n", LogDir "\unsaved_entries.txt", "UTF-8-RAW")
    }
}

BuildTrayMenu() {
    A_IconTip := "Obsill - Obsidian Life Logger"
    tray := A_TrayMenu
    tray.Delete()
    quickLabel := "Quick log (" Cfg.Hotkey ")"
    tray.Add(quickLabel, (*) => OnHotkey())
    tray.Add("Run self-check", (*) => Run('"' A_AhkPath '" "' A_ScriptDir '\Obsill-Check.ahk"'))
    tray.Add("Open logs folder", (*) => Run('explorer.exe "' LogDir '"'))
    tray.Add("Re-run setup", (*) => Run('"' ProjectRoot '\setup_obsill.bat"'))
    tray.Add("Reload (re-read config.json)", (*) => Reload())
    tray.Add()
    tray.Add("Exit Obsill", (*) => ExitApp())
    tray.Default := quickLabel
}

LogUncaught(err, mode) {
    ObsillLog.Err("Uncaught error: " err.Message " (in " err.What ", line " err.Line ")")
    return 0
}

LogExit(reason, code) {
    ObsillLog.Info("Obsill exiting (" reason ")")
    return 0
}
