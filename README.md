# Obsill

**Obsidian Life Logger** - press a hotkey, type one line, and it lands in today's daily note with a timestamp.

Version 0.0.1 (first working draft)

---

## About

Obsill is a tiny Windows tool for capturing "micro life logs" without opening Obsidian.

- You press a **global hotkey** (default `Ctrl+Alt+L`), from any app.
- A small window opens. You type your log and press `Enter`.
- Obsill appends it to **today's daily note** as a timestamped bullet, for example:

  ```
  - 14:32 finished the invoice, then a long walk
  ```

- If today's daily note does not exist yet, Obsill **creates it**.

### How it knows where your daily note lives

Obsill does not ask you to type your Daily Notes settings. It reads them from your vault:

`<vault>\.obsidian\daily-notes.json` (folder, date format, template)

It re-reads this file every time you log, so if you change the folder or format in Obsidian, Obsill follows without a new setup. If the file does not exist yet (Obsidian only creates it after you change a Daily notes option), Obsill uses Obsidian's defaults: vault root folder and `YYYY-MM-DD`.

### The weekday is part of the note's name

If your format is `YYYY-MM-DD-ddd`, today's note is `2026-10-22-Thu.md`, and tomorrow's is `2026-10-23-Fri.md`. The `-Thu` / `-Fri` suffix is **part of the daily note's file name**. Obsill builds the exact full name and only ever opens that exact file. It never matches by prefix, so `2026-10-22.md` or any other note that merely starts with the date is never touched.

Obsill converts Obsidian's (Moment.js) date format with its own converter and **English** day and month names, so the file name matches Obsidian's regardless of your Windows language. See [Supported date format tokens](#supported-date-format-tokens).

### Tech

AutoHotkey v2 for the tool itself (fast hotkey, no startup delay). PowerShell is used once, for setup (folder picker, reading the Obsidian config, writing `config.json`). Obsill only reads from `.obsidian`, it never changes your Obsidian settings.

---

## How to use

### 1. Requirements

- Windows 10 or 11
- [AutoHotkey **v2**](https://www.autohotkey.com) (v1 will not work)
- An Obsidian vault with the core **Daily notes** plugin set up

### 2. Set up (once)

1. Double-click **`setup_obsill.bat`**.
2. A folder window opens: select your **vault folder** (the one that contains `.obsidian`). If you pick a folder inside the vault, Obsill finds the vault root for you.
3. Setup shows the daily note settings it found in the vault. Keep **automatic mode** (recommended).
4. Choose the hotkey (press Enter to keep `Ctrl+Alt+L`).
5. Setup writes `config.json`, runs a **self-check** that prints the exact path of today's note, and offers to start Obsill (and optionally start it with Windows).

Everything setup does is recorded in **`logs\setup.log`**.

### 3. Log something

1. Press your hotkey. The Obsill window opens (always on top).
2. Type. Then:
   - `Enter` (or `Ctrl+Enter`) saves
   - `Shift+Enter` adds a new line (the extra lines stay inside the same bullet)
   - `Esc` cancels
3. The window closes. Your entry is at the end of today's note.

The time shown is when you **opened** the window, so an entry started at 23:58 and saved at 00:02 still belongs to the first day.

If saving fails (for example the vault drive is missing), the window stays open with your text and a copy is written to `logs\unsaved_entries.txt`. Text is never silently lost.

### 4. Everyday commands

| I want to... | Do this |
|---|---|
| Start Obsill later | Double-click `start_obsill.bat` (or choose "start with Windows" in setup) |
| Check that everything is healthy | Tray icon > **Run self-check** |
| Change the hotkey or vault | Tray icon > **Re-run setup** (or run `setup_obsill.bat`) |
| See what happened | Tray icon > **Open logs folder** |
| Stop Obsill | Tray icon > **Exit Obsill** |
| Stop starting with Windows | Delete `Obsill.lnk` from the folder that opens with `Win+R` > `shell:startup` |

### 5. Configuration (`config.json`)

Created by setup. See `config.example.json`. In JSON, a backslash must be doubled (`D:\\Notes\\MyVault`); forward slashes also work.

| Key | Meaning |
|---|---|
| `vaultRoot` | Vault folder (must contain `.obsidian`) |
| `hotkey` | AutoHotkey hotkey syntax: `^` Ctrl, `!` Alt, `+` Shift, `#` Windows key. `^!l` = Ctrl+Alt+L |
| `dailyNoteMode` | `"auto"` reads `.obsidian\daily-notes.json` on every save. `"manual"` uses the `dailyNote` values below |
| `dailyNote.folder` | Folder relative to the vault root, `/` separated |
| `dailyNote.format` | Obsidian/Moment date format, e.g. `YYYY-MM-DD-ddd` |
| `dailyNote.template` | Recorded for reference. Templates are not applied in v0.0.1 |
| `timeFormat` | Time stamp format (AutoHotkey `FormatTime` syntax), default `HH:mm` |
| `entryTemplate` | Line layout. `{time}` and `{text}` are replaced. Default `- {time} {text}` |

In `auto` mode the `dailyNote` values are only a snapshot used as a fallback if `daily-notes.json` cannot be read. After editing `config.json`, use the tray menu > **Reload**.

### Supported date format tokens

`YYYY` `YY` `MMMM` `MMM` `MM` `M` `DD` `D` `dddd` `ddd`

Put literal text in square brackets: `[Week]`. Separators such as `-`, `_`, `.`, space and `/` (subfolders) are copied as they are. Any other letter (for example `HH`, `mm`, `Do`, `dd`) is rejected with a clear error instead of guessing, because a wrong guess would create a duplicate note.

### Troubleshooting

1. Tray icon > **Run self-check**. It shows the exact note path and the newest note already in the folder, so you can compare the naming pattern by eye.
2. Read `logs\setup.log` (setup) and `logs\obsill.log` (runtime). They contain your vault path, so check them before sharing.
3. Run `tests\run_tests.ahk` to test the date converter and the other logic.
4. Typical causes:
   - *"vault not found"*: the vault folder moved. Run setup again.
   - *Weekday names differ* (for example your notes use a non-English `ddd`): v0.0.1 supports English names only.
   - *Hotkey does nothing*: another program owns that key combination. Choose another in setup.
   - *`daily-notes.json` missing*: change any Daily notes option in Obsidian once so it creates the file, then run setup again.

---

## Project structure

```
Obsill/
  setup_obsill.bat        one-click setup (folder picker, reads Obsidian config, writes config.json, log)
  start_obsill.bat        starts Obsill with AutoHotkey v2
  config.example.json     example of the generated config.json
  README.md  AGENTS.md  CHANGELOG.md
  src/
    Obsill.ahk            the tool: hotkey, tray menu, save flow
    Obsill-Check.ahk      self-check (never touches a running Obsill)
    Setup-Obsill.ps1      setup logic (called by setup_obsill.bat)
    lib/
      Config.ahk          loads and validates config.json
      DailyNote.ahk       finds today's note, builds and appends the entry
      DateFormat.ahk      Moment-style date format converter (English names)
      InputWindow.ahk     the quick-log window
      Json.ahk            small read-only JSON parser
      ObsillLog.ahk       logger
      Version.ahk         version number
  tests/run_tests.ahk     unit tests
  logs/                   generated: setup.log, obsill.log, check_result.txt, unsaved_entries.txt
```

## Known limitations (v0.0.1)

- Templates are not applied. New notes are created blank (the template setting is only reported).
- Entries are always appended at the end of the note (no "under a heading" mode yet).
- English weekday and month names only.
- Only the core Daily notes plugin is read, not Periodic Notes.
- Written without access to a Windows machine: run `tests\run_tests.ahk` and the self-check first, and report anything odd in `logs\`.

## Roadmap

Insert under a chosen heading, template support, Periodic Notes support, optional tags in the input window.
