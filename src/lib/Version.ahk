#Requires AutoHotkey v2.0

; Single source of truth for the version number.
; Setup-Obsill.ps1 reads it from here. Bump it here and in CHANGELOG.md.
class ObsillInfo {
    static Version := "0.0.1"
}
