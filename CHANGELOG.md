# Changelog

## 0.0.1 - 2026-10-22

First version.

- Global hotkey opens a quick-log window; Enter saves, Shift+Enter new line, Esc cancels.
- Appends `- HH:mm text` to today's daily note and creates the note (and folders) if missing.
- Reads the daily note folder and date format from `<vault>\.obsidian\daily-notes.json` on every save.
- Own Moment-style date format converter with English names; supports `ddd` so the weekday is part of the note name (`2026-10-22-Thu.md`). Unsupported tokens raise an error.
- `setup_obsill.bat` + `Setup-Obsill.ps1`: folder picker, vault validation, reads Obsidian config, writes `config.json`, runs a self-check, optional Startup shortcut, full `logs\setup.log`.
- Self-check (`Obsill-Check.ahk`), unit tests (`tests\run_tests.ahk`), runtime log, unsaved-entry fallback.
- Known gaps: no template support, end-of-file insertion only, English names only.
