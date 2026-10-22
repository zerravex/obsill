#Requires AutoHotkey v2.0

; Loads and validates <project>\config.json (created by setup_obsill.bat).
; Every problem is thrown as an Error with a message that is safe to show to the user.
class ObsillConfig {
    VaultRoot := ""
    Hotkey := "^!l"
    TimeFormat := "HH:mm"                ; AutoHotkey FormatTime syntax
    EntryTemplate := "- {time} {text}"
    DailyNoteMode := "auto"              ; "auto" = read .obsidian\daily-notes.json, "manual" = use the values below
    SnapFolder := ""                     ; snapshot written by setup; used in manual mode or as a fallback
    SnapFormat := "YYYY-MM-DD"
    SnapTemplate := ""

    static Load(path) {
        if !FileExist(path)
            throw Error("config.json was not found.`n`nExpected here:`n" path "`n`nRun setup_obsill.bat first.")

        try {
            data := Json.Parse(FileRead(path, "UTF-8"))
        } catch as e {
            throw Error("config.json could not be read.`n`n" e.Message)
        }
        if !(data is Map)
            throw Error("config.json must contain a JSON object.")

        cfg := ObsillConfig()

        root := ObsillConfig._Str(data, "vaultRoot")
        if (Trim(root) = "")
            throw Error("config.json: 'vaultRoot' is missing or empty.`n`nRun setup_obsill.bat again.")
        root := RTrim(StrReplace(Trim(root), "/", "\"), "\")
        if !DirExist(root "\.obsidian")
            throw Error("The Obsidian vault was not found.`n`nvaultRoot: " root "`n(there is no .obsidian folder in it)`n`nIf the vault moved, run setup_obsill.bat again.")
        cfg.VaultRoot := root

        hotkeyText := Trim(ObsillConfig._Str(data, "hotkey", "^!l"))
        cfg.Hotkey := (hotkeyText = "") ? "^!l" : hotkeyText

        timeText := Trim(ObsillConfig._Str(data, "timeFormat", "HH:mm"))
        cfg.TimeFormat := (timeText = "") ? "HH:mm" : timeText

        tpl := ObsillConfig._Str(data, "entryTemplate", "- {time} {text}")
        if !InStr(tpl, "{text}")
            throw Error("config.json: 'entryTemplate' must contain {text}.`nCurrent value: " tpl)
        cfg.EntryTemplate := tpl

        mode := StrLower(Trim(ObsillConfig._Str(data, "dailyNoteMode", "auto")))
        if (mode != "auto" && mode != "manual")
            throw Error("config.json: 'dailyNoteMode' must be `"auto`" or `"manual`" (found: " mode ").")
        cfg.DailyNoteMode := mode

        if (data.Has("dailyNote") && (data["dailyNote"] is Map)) {
            dn := data["dailyNote"]
            cfg.SnapFolder := ObsillConfig._Str(dn, "folder", "")
            cfg.SnapFormat := ObsillConfig._Str(dn, "format", "YYYY-MM-DD")
            cfg.SnapTemplate := ObsillConfig._Str(dn, "template", "")
        }
        return cfg
    }

    static _Str(m, key, fallback := "") {
        if (m.Has(key) && (m[key] is String))
            return m[key]
        return fallback
    }
}
