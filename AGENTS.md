# AGENTS.md - the complete working guide for Obsill

Audience: AI coding agents of any size, and humans. Read this whole file before changing anything.
It is deliberately long and explicit. If a rule here conflicts with your own habits, follow this file.

---

## 0. If you read nothing else (the 12 golden rules)

1. Obsill is **AutoHotkey v2** (runtime) + **Windows PowerShell 5.1** (setup only). No other language, no downloads, no network.
2. **Make the smallest change that solves the task.** Do not refactor, rename, reorder or "clean up" code you were not asked to touch.
3. The daily note's file name is built by `DateFormat.Format(format, stamp)` and used **exactly**. With `YYYY-MM-DD-ddd` the weekday (`-Thu`) is **part of the note's name**. Never find a note by prefix, wildcard or date-only matching.
4. The date converter **never guesses**. Unsupported token = throw an error.
5. **Never lose the user's text.** Save failure = window stays open + copy in `logs\unsaved_entries.txt`.
6. **Never write inside `.obsidian`.** Obsill only reads there.
7. Only `src\Setup-Obsill.ps1` writes `config.json`. The AHK code only reads it.
8. Files are **ASCII only** (`.ahk`, `.ps1`, `.bat`). `.bat` files use CRLF line endings.
9. AutoHotkey identifiers are **case-insensitive**. Never name something like a built-in (`Log`, `Map`, `Format`, `Error`, `Hotkey`, `Trim`...).
10. Every behaviour change needs: a test (or a manual test line), a `CHANGELOG.md` entry, a version bump in `src/lib/Version.ahk`, and README/config-table updates if users can see it.
11. **You usually cannot run AutoHotkey or PowerShell.** Do not claim you ran or tested code you did not run. Say "not run" and list what the user should run (section 11).
12. When unsure, **ask the user** or choose the more conservative option. A wrong guess that creates duplicate or misplaced notes is worse than an error message.

---

## 1. What Obsill is

A tiny Windows tool for "micro life logs". The user presses a global hotkey (default `Ctrl+Alt+L`), a small window opens, they type a line and press Enter. Obsill appends it to **today's Obsidian daily note** as a timestamped bullet and creates the note (and folders) if missing.

Example result in the note:

```
- 17:30 Testing Obsill.
- 17:32 Second entry
  second line of the same entry
```
(The user wants the timestamp bold with a colon, i.e. `- **17:30:** text`. That is the `entryTemplate` setting, see sections 4 and 7.)

Naming: **Obsill** = **Obs**idian **L**ife **L**ogger. Current version: see `src/lib/Version.ahk` (single source of truth).

## 2. Current status (be honest about it)

Verified working on the user's real Windows 10 PC (AutoHotkey 2.0.26, PowerShell 5.1) from their logs and screenshots:
- `setup_obsill.bat`: folder picker, vault detection, reading `daily-notes.json`, writing `config.json`, self-check, Startup shortcut, launch.
- Hotkey opens the window; Enter saves; the note is created on the first entry and **appended** (not re-created) on later entries.
- Auto mode: after the user changed the format in Obsidian to `YYYY-MM-DD-ddd`, Obsill produced `2026-10-22-Thu.md` with no re-setup.
- A vault path containing `&`, parentheses and underscores works (setup writes `&` as `\u0026` in JSON; the AHK parser decodes it).
- Time stamps appear in entries.

NOT yet confirmed by the user (treat as untested): `tests\run_tests.ahk` result; multi-line entries (`Shift+Enter`); the save-failure path and `unsaved_entries.txt`; manual mode; the fallback when `daily-notes.json` is unreadable; entries across midnight; tray items other than Reload; re-running setup over an existing config; Obsidian having the note open while Obsill appends.

The user also runs an unrelated AHK script (`Start Lifelog.ahk`). Two AutoHotkey processes in Task Manager are normal and not a bug. Do not "fix" that.

## 3. Architecture and data flow

```
Hotkey pressed                         (Obsill.ahk: OnHotkey)
  stamp := A_Now                       <- date AND time are fixed HERE
  InputWindow.Open(stamp, timeText, SaveEntry)
      user types, presses Enter        (InputWindow.Submit)
      SaveEntry(text, stamp)           (Obsill.ahk)
        DailyNote.AppendEntry(cfg, text, stamp)
          1. ResolveSettings(cfg)      -> {folder, format, template, source}
          2. NotePath(cfg, s, stamp)   -> full path, name from DateFormat.Format
          3. create folder if missing  (DirCreate)
          4. BuildEntry(template, timeText, text)
          5. add a leading "`n" if the existing file does not end with a newline
          6. FileAppend(..., "UTF-8-RAW") with up to 4 retries
        on any error: ObsillLog.Err + SaveFallback -> returns message
      "" = success -> window closes; message = window stays open + MsgBox
```

Process model: `src\Obsill.ahk` is the long-running tool (`#SingleInstance Force`: starting it again replaces the running copy). `src\Obsill-Check.ahk` is a **separate** script (`#SingleInstance Off`) so a self-check never kills a running Obsill. `Setup-Obsill.ps1` runs the check with `/silent` and reads its exit code and `logs\check_result.txt`.

### 3.1 File map and public functions

| File | Responsibility | Main functions |
|---|---|---|
| `setup_obsill.bat` | Starts PowerShell with `-NoProfile -ExecutionPolicy Bypass -STA`, then `pause` | - |
| `start_obsill.bat` | Finds AutoHotkey **v2** and starts `src\Obsill.ahk` (env var `OBSILL_AHK` overrides) | - |
| `src/Setup-Obsill.ps1` | One-time setup, logs to `logs\setup.log` | `Write-Log`, `Write-Say`, `Read-YesNo`, `Read-WithDefault`, `Read-JsonFile`, `Get-JsonProp`, `ConvertTo-VaultRelativeFolder`, `Find-AutoHotkeyV2`, `Select-Folder`, `Find-VaultRoot`, `Get-VaultRootFromUser`, `Get-DailyNoteSettings`, `Save-Config`, `New-StartupShortcut` |
| `src/Obsill.ahk` | Entry: load config, register hotkey, tray menu, save flow | `OnHotkey`, `SaveEntry`, `SaveFallback`, `BuildTrayMenu`, `LogUncaught`, `LogExit` |
| `src/Obsill-Check.ahk` | Read-only self-check; exit code 0 = pass | `RunCheck`, `JoinLines` |
| `src/lib/Version.ahk` | `ObsillInfo.Version` | - |
| `src/lib/ObsillLog.ahk` | Logger to `logs\obsill.log` (rotates at 512 KB to `.old`); never throws | `Init`, `Info`, `Warn`, `Err` |
| `src/lib/Json.ahk` | Read-only JSON parser | `Json.Parse(text)` -> Map / Array / String / Number / 1 / 0 / "" |
| `src/lib/DateFormat.ahk` | Moment-style format -> text, English names | `DateFormat.Format(fmt, stamp)` |
| `src/lib/Config.ahk` | Loads and validates `config.json` | `ObsillConfig.Load(path)` -> object |
| `src/lib/DailyNote.ahk` | Settings, paths, entry building, appending | `ResolveSettings`, `NormalizeFolder`, `NotePath`, `NewestNoteName`, `AppendEntry`, `BuildEntry` |
| `src/lib/InputWindow.ahk` | The quick-log GUI | `RegisterKeys`, `Open`, `Submit`, `Cancel` |
| `tests/run_tests.ahk` | Unit tests (message box, exit code) | `Check`, `CheckThrows` |
| `config.example.json` | Documents the config shape | - |

Generated at runtime, never committed (`.gitignore`): `config.json`, `config.json.bak`, `logs\setup.log`, `logs\obsill.log`, `logs\check_result.txt`, `logs\unsaved_entries.txt`.

### 3.2 Include order
Every entry script lists `#Include` lines at the top, in this order: `Version`, `Json`, `ObsillLog`, `DateFormat`, `Config`, `DailyNote`, (`InputWindow` only in `Obsill.ahk`). Keep that order; `DailyNote` uses `Json`, `DateFormat` and `ObsillLog`.

## 4. config.json (written by setup, read by Obsill)

```json
{
  "obsillVersion": "0.0.1",
  "vaultRoot": "D:\\Notes\\MyVault",
  "hotkey": "^!l",
  "dailyNoteMode": "auto",
  "dailyNote": { "folder": "__taskir/_instances/allofmydayz", "format": "YYYY-MM-DD-ddd", "template": "" },
  "timeFormat": "HH:mm",
  "entryTemplate": "- {time} {text}"
}
```

| Key | Type | Default if missing | Rules |
|---|---|---|---|
| `vaultRoot` | string | **required** | Must contain a `.obsidian` folder or `Load` throws. `/` is converted to `\`. |
| `hotkey` | string | `^!l` | AutoHotkey syntax. Invalid = startup error dialog. |
| `dailyNoteMode` | `"auto"` or `"manual"` | `auto` | Anything else throws. |
| `dailyNote.folder/format/template` | strings | `""` / `YYYY-MM-DD` / `""` | **Snapshot.** Used in manual mode, and as fallback if `daily-notes.json` is unreadable in auto mode. |
| `timeFormat` | string | `HH:mm` | AutoHotkey `FormatTime` syntax (not Moment). |
| `entryTemplate` | string | `- {time} {text}` | **Must contain `{text}`** or `Load` throws. |

Written by PowerShell as UTF-8 **without BOM**. `ConvertTo-Json` escapes `&` as `\u0026` and doubles backslashes; the AHK parser handles both. Do not "fix" that.

## 5. External data Obsill reads from the vault

`<vault>\.obsidian\daily-notes.json` (core Daily notes plugin). Created by Obsidian only after the user changes an option, so it may not exist. Real example from the user:
```json
{"folder":"__taskir/_instances/allofmydayz","format":"YYYY-MM-DD-ddd"}
```
- Keys may be missing; missing means Obsidian defaults: folder = vault root, format = `YYYY-MM-DD`, template = none.
- `template` is stored without `.md` (v0.0.1 does not use it anyway).
- `folder` uses `/` separators.

`<vault>\.obsidian\core-plugins.json`: used only by setup, to warn if `daily-notes` is disabled. It is an **object** (`{"daily-notes": true, ...}`) in recent Obsidian versions and an **array** of names in old ones; setup handles both.

`ResolveSettings` decision table:

| Mode | `daily-notes.json` | Result |
|---|---|---|
| auto | exists and parses | its values (missing keys -> defaults), source `daily-notes.json` |
| auto | exists but unreadable | **snapshot** values from `config.json` + a WARN log line |
| auto | does not exist | Obsidian **defaults** (not the snapshot), like Obsidian itself |
| manual | ignored | snapshot values |

## 6. Date format converter (`DateFormat.Format`)

Input: a Moment-style format (what Obsidian stores) and a stamp `YYYYMMDDHH24MISS` (usually `A_Now`).

| Token | Output (for 2026-01-05, Monday) |
|---|---|
| `YYYY` / `YY` | `2026` / `26` |
| `MMMM` / `MMM` / `MM` / `M` | `January` / `Jan` / `01` / `1` |
| `DD` / `D` | `05` / `5` |
| `dddd` / `ddd` | `Monday` / `Mon` |
| `[text]` | `text` (literal, brackets removed) |

Rules:
- Matching is **case-sensitive** and **longest first** (the `Tokens` array order matters: `YYYY` before `YY`, `MMMM` before `MMM` before `MM` before `M`, `DD` before `D`, `dddd` before `ddd`).
- Non-letter characters (`- _ . space , /`) are copied. `/` in the result means subfolders (handled in `NotePath`).
- Any other ASCII letter (`H`, `m`, `s`, `a`, `o`, `d`...) -> `ValueError`. A backslash -> `ValueError`. An unclosed `[` -> `ValueError`. Empty format -> `ValueError`.
- Names are English from fixed arrays. The weekday number comes from `FormatTime(stamp, "WDay")` (1 = Sunday), which is locale independent. **Never** use `FormatTime` with `dddd`/`MMMM` (it follows the Windows language).

Verified examples: `YYYY-MM-DD-ddd` -> `2026-10-20-Tue`, `2026-10-21-Wed`, `2026-10-22-Thu`, `2026-10-23-Fri`, `2026-10-24-Sat`, `2026-10-25-Sun`, `2026-10-26-Mon`; `2024-02-29` -> `Thu`; `2000-01-01` -> `Sat`.

To add a token, see recipe 13.1.

## 7. Entry format (`DailyNote.BuildEntry`)

Pure function, unit tested. Steps:
1. Normalize `CRLF`/`CR` to `LF`; trim spaces, tabs and newlines at both ends.
2. Split into lines. Fill the template: replace `{time}` first, then `{text}` with **line 1 only** (so text containing the literal `{time}` is never expanded).
3. Continuation lines: if the template starts like a list item (`- `, `* `, `+ `, `1. `, `1) `, optionally indented) they are indented by that marker's width (2 spaces for `- `) so they stay inside the same bullet. Otherwise no indent. Blank lines stay empty (no trailing spaces).
4. `AppendEntry` writes `entry + "`n"`; if the file exists and does not end with a newline it first writes one `"`n"`.

Examples with `- {time} {text}`, time `14:32`:
- `hello` -> `- 14:32 hello`
- `a` / `b` / blank / `c` -> `- 14:32 a`, `  b`, (empty), `  c`
Bold timestamp (the user's wish): `entryTemplate` = `- **{time}:** {text}` -> `- **14:32:** hello`. The indent regex still matches `- `.

## 8. Invariants (do not break; the reason is in brackets)

1. Note path = `<vault>\<folder>\<DateFormat.Format(format, stamp)>.md`, exact. Only `NewestNoteName` may glob and it is diagnostics only. (A prefix match could append to the wrong note.)
2. Converter throws on unsupported tokens. (A guess creates duplicate notes.)
3. Failed save: text must survive (window open + `logs\unsaved_entries.txt`).
4. Timestamp = moment the hotkey was pressed (`stamp` passed down), never recomputed at save time. (Midnight.)
5. Folder values with `..` or a drive prefix are rejected in **both** `ConvertTo-VaultRelativeFolder` (PS) and `DailyNote.NormalizeFolder` (AHK). Keep the two in sync. (Stay inside the vault.)
6. No writes inside `.obsidian`. Obsill must not edit Obsidian's settings.
7. Notes and logs: UTF-8 **no BOM** (`"UTF-8-RAW"`). `config.json` no BOM.
8. Auto mode re-reads `daily-notes.json` on **every** save (so Obsidian changes apply instantly).
9. Setup logs every decision to `logs\setup.log`; on failure the log must explain why.
10. Templates are **not applied** in v0.0.x; a configured template only produces an INFO log line and a blank note.
11. The self-check must never change anything (read-only) and must never replace a running Obsill.
12. Setup is idempotent: running it again must not corrupt anything; the old config is saved as `config.json.bak`.

## 9. AutoHotkey v2 rules and pitfalls (each one is a real risk)

- First line of every `.ahk`: `#Requires AutoHotkey v2.0`. v1 syntax (`%var%`, `:=` mixed with legacy commands, `MsgBox, text`) is forbidden.
- **Case-insensitive identifiers.** A class named `Log` collides with the built-in `Log()` function; that is why the logger is `ObsillLog`. Also avoid parameters/variables named `map`, `format`, `error`, `hotkey`, `default`. Use `fmt`, `m`, `problem`, `hotkeyText`, `fallback`.
- `=` is case-insensitive; `==` is case-sensitive. Token comparisons use `==`.
- Do not write `"text" (expression)`; it can be parsed as a call. Compute into a variable first, then concatenate.
- Escape character is the backtick: `` `n `` `` `t `` `` `" ``. Backslash is a normal character (`"C:\x"` is fine).
- Put all `#Include` lines at the top of the entry script, before executable code.
- Functions may **read** globals freely. To **assign** a global inside a function, declare `global name`. Mutating an object's properties needs no declaration.
- `#SingleInstance Force` replaces a running copy of the same script file. Anything that must not replace Obsill goes in its own script.
- Use `try { } catch as e { }` with braces. `e.Message` is safe to show.
- `FileAppend(text, path, "UTF-8-RAW")` for notes/logs. Plain `"UTF-8"` adds a BOM to new files.
- `FileExist(path)` returns an attribute string (`"A"`, `"D"`...) or `""`; check `InStr(attrs, "D")` for folders.
- GUI: `+AlwaysOnTop`, buttons use `-Tabstop`; Esc is the Gui `"Escape"` event; Enter is a context hotkey active only for `ahk_class AutoHotkeyGUI ahk_pid <this process>`. `Shift+Enter` is left to the Edit control (new line).
- JSON `true`/`false` parse to `1`/`0`; `null` to `""`.
- `for x in arr` with one variable gives values. Assigning to the loop variable is allowed.
- Avoid `Format("{:02}")` style specs (unverified here). Padding comes from `SubStr(stamp, ...)`.
- Do not use `switch` for string tokens (case-insensitive by default); use `if (x == "...")` chains.
- Avoid non-ASCII characters in code and in log text.

## 10. PowerShell 5.1 and batch rules

PowerShell (`Setup-Obsill.ps1`):
- Must run on Windows PowerShell 5.1: no `??`, no `?:`, no `-AsHashtable`, no `ForEach-Object -Parallel`.
- `Set-StrictMode -Version 2.0` and `$ErrorActionPreference = 'Stop'` are on: reading a missing property throws. Use `Get-JsonProp $obj 'name' $default` for JSON data.
- `ConvertFrom-Json` unrolls arrays; `Read-JsonFile` returns `, $parsed` to keep them intact. Keep that comma.
- In an argument array, the comma binds tighter than `+`: write `@($quotedPath, '/silent')`, never `@('"' + $path + '"', '/silent')`.
- `-like` treats `[FAIL]` as a character class; use `-match '\[FAIL\]'`.
- After `Start-Process -PassThru`, run `$null = $proc.Handle` or `ExitCode` may be empty. Use `WaitForExit(30000)` with a timeout.
- Write JSON with `[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))` (no BOM).
- The folder picker needs STA: the batch file passes `-STA`; the dialog uses a TopMost owner form so it does not hide behind the console.
- Console and log text: ASCII only. Every user decision is logged (`Write-Log` / `Write-Say`).

Batch (`*.bat`):
- CRLF line endings, ASCII only.
- Inside `( ... )` blocks any unquoted `)` ends the block: write `^(` and `^)` in `echo`, and quote paths.
- `endlocal & exit /b %RC%` keeps the exit code.

## 11. Testing

You probably cannot execute AutoHotkey. Then: (a) re-read your change against sections 9-10, (b) mirror new pure logic in a quick Python script if you can (this was done for the date converter), (c) update `tests\run_tests.ahk`, (d) tell the user exactly what to run.

What exists:
- `tests\run_tests.ahk`: DateFormat (weekdays, tokens, literals, errors), Json (including the user's real `daily-notes.json`, escapes, BOM, errors), `NormalizeFolder`, `BuildEntry`. Message box shows `N passed, M failed`; exit code 1 on failure.
- `src\Obsill-Check.ahk`: prints config status, resolved settings, today's exact note path, whether the note/folder exist, and the newest `.md` in the folder.

Manual test checklist after any change that touches saving:
1. Self-check shows `RESULT: PASS` and the expected note name.
2. Hotkey opens the window; Enter saves; the note shows `- HH:mm text` (or the configured template).
3. A second entry is appended to the **same** file (look for one `Created daily note` log line only).
4. Multi-line entry with `Shift+Enter`: extra lines indented inside the same bullet.
5. Change the date format in Obsidian: the next entry uses the new name without restarting.
6. Make the note read-only or the vault unavailable: window stays open, message shown, text present in `logs\unsaved_entries.txt`.

## 12. Debugging playbook

| Symptom | Look at | Usual cause |
|---|---|---|
| "config.json was not found" dialog | project root | Setup not run, or the project folder moved |
| "vault not found" | `vaultRoot` | Vault moved/renamed; run setup again |
| Wrong note name | tray > Run self-check; `.obsidian\daily-notes.json` | Obsidian has not written the setting yet, or another vault is open |
| New note instead of appending | log line `Created daily note` appears again | Format/folder changed, so a different file name |
| Hotkey does nothing | `logs\obsill.log`; other scripts | Key combo owned by another program, or invalid hotkey string |
| Entry has no time | `entryTemplate` in `config.json`; which window opened | Custom template without `{time}`, or the entry came from another script |
| Setup problem | `logs\setup.log` (every step and answer is logged) | See the last lines before `Setup failed` |
| Two AutoHotkey processes | Task Manager > Details > Command line | Normal: Obsill + the user's own script |

Log line formats to grep: `Created daily note:`, `Saved entry to <path> (settings from <source>)`, `Created folder:`, `Save failed:`, `Config problem:`, `Uncaught error:`.

## 13. Recipes (step by step)

### 13.1 Add a date token (example: `HH`)
1. `DateFormat.ahk`: add the token to `Tokens` in the right position (longest first), add a branch in `_Render` using `==`, update the comment block and the error text listing supported tokens.
2. `tests\run_tests.ahk`: add positive tests and keep the "unsupported" tests for tokens that are still unsupported.
3. README "Supported date format tokens", AGENTS section 6, CHANGELOG, version bump.

### 13.2 Add a config key
1. `Config.ahk`: add a field with a default and read it with `_Str` (validate; throw a clear `Error` for bad values).
2. `Setup-Obsill.ps1`: add it to the `$config` ordered hashtable (and a prompt only if users must choose it).
3. `config.example.json`, README config table, AGENTS section 4, CHANGELOG.

### 13.3 Change the entry layout
Normally no code: edit `entryTemplate`. If code must change, edit only `DailyNote.BuildEntry` and update its tests (section 7 examples).

### 13.4 Add a tray menu item
In `Obsill.ahk` `BuildTrayMenu`: `tray.Add("Label", (*) => DoThing())`. Keep "Exit Obsill" last. Document it in README section 4.

### 13.5 Add a library file
Create `src\lib\Name.ahk` with `#Requires AutoHotkey v2.0`, a uniquely named class (check it is not a built-in), add `#Include` in every entry script that needs it and in `tests\run_tests.ahk`, then add it to the project structure in README and section 3.1 here.

### 13.6 Release
Bump `src\lib\Version.ahk`, add the CHANGELOG entry (date, bullets), re-check `config.example.json`, rebuild the zip, and confirm no non-ASCII characters (`grep -nP '[^\x00-\x7F]'`) and CRLF in `.bat` files.

## 14. Do and do not

Do:
- Read the file you edit completely first. Keep edits local. Match the existing style (4-space indent, comments explain **why**).
- Log with `ObsillLog` (AHK) or `Write-Log` (PS) for anything a user may need to debug.
- Return clear, user-readable error messages (they are shown in dialogs).
- Keep the user's data safe over being clever.

Do not:
- Do not rename files, classes or config keys (users' `config.json` and shortcuts depend on them) without a migration note.
- Do not add dependencies, network calls, telemetry, auto-updaters or admin-rights features.
- Do not parse JSON with regex in AHK; use `Json.Parse`.
- Do not hard-code the user's vault path, folder names or Windows user name anywhere.
- Do not use the Windows locale for day or month names.
- Do not silently catch and ignore errors in the save path.
- Do not delete or rewrite the user's notes; Obsill only appends (and creates the daily note if it is missing).
- Do not claim tests passed unless you actually ran them.

## 15. Decision log (why things are the way they are)

- **AHK-only runtime, PowerShell only for setup:** a PowerShell hotkey handler would add a visible start-up delay; AHK is instant. PowerShell is good at the folder picker and JSON.
- **`YYYY-MM-DD`, not `YYYY:MM:DD`:** Windows forbids `:` in file names; this is also Obsidian's default.
- **Weekday via own converter:** Moment tokens differ from `FormatTime`, and Windows-language day names could make Obsill's file name differ from Obsidian's.
- **Auto mode reads Obsidian's file on every save:** no stale copy; the cost is one tiny file read.
- **Config snapshot kept even in auto mode:** a safe fallback when Obsidian is mid-write; not refreshed automatically (only setup writes `config.json`).
- **Timestamp at window open:** an entry started at 23:58 and saved at 00:02 stays on the first day.
- **Separate check script:** `#SingleInstance Force` would otherwise kill the running logger.
- **Own JSON reader:** AHK v2 has no built-in JSON, and read-only parsing of small files is simple; no third-party library to trust.
- **Templates deferred:** the user has none; raw copying would leave `{{date}}` placeholders unexpanded, which is worse than a blank note.
- **Entry at end of file:** simplest and safest; heading insertion is a later option.

## 16. Roadmap and open questions

Planned for 0.0.2 (the user has asked for or agreed with these):
1. Make the bold timestamp the default: `entryTemplate` = `- **{time}:** {text}` (setup default + `config.example.json` + README).
2. Setup must **preserve** an existing config's customized values (`entryTemplate`, `hotkey`, `timeFormat`) instead of resetting them to defaults when re-run.
3. Refresh the `dailyNote` snapshot in `config.json`. Open design question: keep the rule "only setup writes config.json" (snapshot refreshed on setup) or deliberately allow Obsill to refresh it. Ask the user before choosing.

Later ideas: insert under a chosen heading, template support (`{{date}}`, `{{time}}`, `{{title}}`), Periodic Notes support, tags in the input window, localized day names.

Out of scope: anything networked, sync, mobile, plugins for Obsidian itself.

## 17. Definition of done and how to report

Before you say you are finished:
- [ ] Change is minimal and limited to what was asked.
- [ ] Sections 8 (invariants), 9 and 10 (pitfalls) re-checked against your diff.
- [ ] Tests added or updated; manual test lines written for anything you could not run.
- [ ] Version bumped, CHANGELOG, README, `config.example.json` and this file updated where affected.
- [ ] No non-ASCII characters in code files; `.bat` files are CRLF.

Report format: (1) what you changed, file by file; (2) what you ran and the result; (3) what you could **not** run, with the exact steps for the user; (4) any risk or question. Never present untested code as tested.
