#Requires AutoHotkey v2.0

; Finds today's daily note and appends a log entry to it.
;
; NAMING RULE (do not break): the note's file name is EXACTLY
;     <vault>\<daily folder>\<DateFormat.Format(format, stamp)>.md
; so with the format "YYYY-MM-DD-ddd" the weekday suffix (-Thu, -Fri, ...) is part of
; the name of the daily note. Notes are never found by prefix, wildcard or "starts with"
; matching, so "2026-10-22.md" or "2026-10-22-Thu extra.md" are never mistaken for it.
class DailyNote {
    static DefaultFormat := "YYYY-MM-DD"

    ; ---- settings -------------------------------------------------------------------
    ; Returns {folder, format, template, source}. In "auto" mode the values come from
    ; <vault>\.obsidian\daily-notes.json (read on every call, so changes made in Obsidian
    ; are picked up immediately). Missing keys fall back to Obsidian's own defaults.
    static ResolveSettings(cfg) {
        folder := cfg.SnapFolder
        fmt := cfg.SnapFormat
        template := cfg.SnapTemplate
        source := "config.json (manual values)"

        if (cfg.DailyNoteMode = "auto") {
            dnPath := cfg.VaultRoot "\.obsidian\daily-notes.json"
            if FileExist(dnPath) {
                try {
                    data := Json.Parse(FileRead(dnPath, "UTF-8"))
                    if !(data is Map)
                        throw Error("the top level is not a JSON object")
                    folder := DailyNote._Str(data, "folder")
                    fmt := DailyNote._Str(data, "format")
                    template := DailyNote._Str(data, "template")
                    source := "daily-notes.json"
                } catch as e {
                    ObsillLog.Warn("daily-notes.json could not be used (" e.Message "). Falling back to the values saved in config.json.")
                    source := "config.json (fallback: daily-notes.json unreadable)"
                }
            } else {
                folder := ""
                fmt := ""
                template := ""
                source := "Obsidian defaults (daily-notes.json does not exist yet)"
            }
        }

        if (Trim(fmt) = "")
            fmt := DailyNote.DefaultFormat
        return {folder: DailyNote.NormalizeFolder(folder), format: Trim(fmt), template: Trim(template), source: source}
    }

    ; "a\b/ c //d/" -> "a/b/c/d". Rejects anything that could leave the vault.
    static NormalizeFolder(folder) {
        parts := []
        for part in StrSplit(StrReplace(folder, "\", "/"), "/") {
            part := Trim(part)
            if (part = "" || part = ".")
                continue
            if (part = "..")
                throw Error("The daily note folder must stay inside the vault (found '..'): " folder)
            parts.Push(part)
        }
        if (parts.Length > 0 && RegExMatch(parts[1], "^[A-Za-z]:$"))
            throw Error("The daily note folder must be relative to the vault root, not a drive path: " folder)
        out := ""
        for part in parts {
            if (out != "")
                out .= "/"
            out .= part
        }
        return out
    }

    ; ---- paths ----------------------------------------------------------------------
    ; Full path of the daily note for the moment `stamp` (YYYYMMDDHH24MISS).
    static NotePath(cfg, s, stamp) {
        name := StrReplace(DateFormat.Format(s.format, stamp), "/", "\")    ; a format may contain "/" = subfolders
        segments := []
        for seg in StrSplit(name, "\") {
            if (seg = "" || seg = "." || seg = "..")
                throw Error("The date format '" s.format "' produced an invalid file name: " name)
            if RegExMatch(seg, '[<>:"|?*]')
                throw Error("The date format '" s.format "' produced characters Windows does not allow in a file name: " name)
            if RegExMatch(seg, "[ .]$")
                throw Error("The date format '" s.format "' produced a name ending in a space or dot: " name)
            segments.Push(seg)
        }
        rel := ""
        for seg in segments {
            if (rel != "")
                rel .= "\"
            rel .= seg
        }
        full := cfg.VaultRoot "\"
        if (s.folder != "")
            full .= StrReplace(s.folder, "/", "\") "\"
        full .= rel ".md"
        return full
    }

    ; Name of the newest .md file (by file name) directly inside `dir`, or "". Diagnostics only.
    static NewestNoteName(dir) {
        newest := ""
        Loop Files dir "\*.md", "F" {
            if (A_LoopFileName > newest)
                newest := A_LoopFileName
        }
        return newest
    }

    ; ---- writing --------------------------------------------------------------------
    static AppendEntry(cfg, text, stamp) {
        s := DailyNote.ResolveSettings(cfg)
        path := DailyNote.NotePath(cfg, s, stamp)
        if (s.template != "")
            ObsillLog.Info("A template ('" s.template "') is configured in Obsidian, but v0.0.1 does not apply templates. New notes are created blank.")

        SplitPath(path, , &dir)
        if !DirExist(dir) {
            DirCreate(dir)
            ObsillLog.Info("Created folder: " dir)
        }

        attrs := FileExist(path)
        if InStr(attrs, "D")
            throw Error("A folder with the name of today's note already exists: " path)

        entry := DailyNote.BuildEntry(cfg.EntryTemplate, FormatTime(stamp, cfg.TimeFormat), text)
        lead := ""
        if (attrs != "" && !DailyNote._EndsWithNewline(path))
            lead := "`n"

        DailyNote._AppendWithRetry(path, lead entry "`n")
        if (attrs = "")
            ObsillLog.Info("Created daily note: " path)
        ObsillLog.Info("Saved entry to " path " (settings from " s.source ")")
    }

    ; Pure function (unit tested). Fills the template; continuation lines of a
    ; multi-line entry are indented so they stay inside the same Markdown list item.
    static BuildEntry(tpl, timeText, text) {
        text := StrReplace(text, "`r`n", "`n")
        text := StrReplace(text, "`r", "`n")
        text := Trim(text, " `t`n")
        lines := StrSplit(text, "`n")

        indent := ""
        if RegExMatch(tpl, "^(\s*(?:[-*+]|\d+[.)])\s+)", &m)
            indent := DailyNote._Spaces(StrLen(m[1]))

        head := StrReplace(tpl, "{time}", timeText)
        head := StrReplace(head, "{text}", lines[1])    ; {text} last, so text containing "{time}" is left alone

        out := head
        loop lines.Length - 1 {
            line := lines[A_Index + 1]
            piece := (Trim(line, " `t") = "") ? "" : indent line
            out .= "`n" piece
        }
        return out
    }

    static _Spaces(count) {
        out := ""
        loop count
            out .= " "
        return out
    }

    static _EndsWithNewline(path) {
        size := FileGetSize(path)
        if (size = 0)
            return true
        f := FileOpen(path, "r")
        try {
            f.Pos := size - 1
            lastByte := f.ReadUChar()
        } finally {
            f.Close()
        }
        return (lastByte = 10 || lastByte = 13)
    }

    ; Sync tools / antivirus can lock a file for a moment, so retry a few times.
    static _AppendWithRetry(path, text) {
        lastError := ""
        loop 4 {
            try {
                FileAppend(text, path, "UTF-8-RAW")    ; UTF-8 without BOM
                return
            } catch as e {
                lastError := e
                Sleep(150)
            }
        }
        throw lastError
    }

    static _Str(m, key, fallback := "") {
        if (m.Has(key) && (m[key] is String))
            return m[key]
        return fallback
    }
}
