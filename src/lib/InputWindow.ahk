#Requires AutoHotkey v2.0

; The small "quick log" window.
;   Enter / Ctrl+Enter = save    Shift+Enter = new line    Esc = cancel
; The timestamp is taken when the window OPENS (stamp), not when Save is pressed,
; so an entry started at 23:58 and saved at 00:02 still belongs to the first day.
class InputWindow {
    static Current := ""

    ; Call once at startup. Makes Enter save, but only while the Obsill window is active.
    static RegisterKeys() {
        HotIfWinActive("ahk_class AutoHotkeyGUI ahk_pid " ProcessExist())
        Hotkey("Enter", (*) => InputWindow.Submit(), "On")
        Hotkey("^Enter", (*) => InputWindow.Submit(), "On")
        HotIfWinActive()
    }

    ; stamp   : YYYYMMDDHH24MISS captured when the hotkey was pressed
    ; timeText: the timestamp as shown to the user (e.g. 14:32)
    ; onSave  : callback(text, stamp) -> "" on success, or an error message
    static Open(stamp, timeText, onSave) {
        if IsObject(InputWindow.Current) {
            try WinActivate("ahk_id " InputWindow.Current.Gui.Hwnd)
            return
        }
        InputWindow.Current := InputWindow(stamp, timeText, onSave)
    }

    static Submit() {
        w := InputWindow.Current
        if (!IsObject(w) || w.Busy)
            return
        text := Trim(w.Edit.Value, " `t`r`n")
        if (text = "") {
            w.Status.Text := "Nothing to save."
            return
        }
        w.Busy := true
        w.Status.Text := "Saving..."
        problem := w.OnSave.Call(text, w.Stamp)
        w.Busy := false
        if (problem = "") {
            w.Destroy()
            return
        }
        w.Status.Text := "Save failed."
        MsgBox(problem "`n`nYour text is still in the window.", "Obsill", "Icon! 262144")
        try w.Edit.Focus()
    }

    static Cancel() {
        if IsObject(InputWindow.Current)
            InputWindow.Current.Destroy()
    }

    __New(stamp, timeText, onSave) {
        this.Stamp := stamp
        this.OnSave := onSave
        this.Busy := false

        this.Gui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Obsill - Quick log")
        this.Gui.SetFont("s10", "Segoe UI")
        this.Gui.MarginX := 12
        this.Gui.MarginY := 10

        this.Gui.AddText("w440", timeText "   |   Enter = save   Shift+Enter = new line   Esc = cancel")
        this.Edit := this.Gui.AddEdit("w440 r5")
        this.BtnSave := this.Gui.AddButton("w100 Default -Tabstop", "Save")
        this.BtnCancel := this.Gui.AddButton("x+8 yp w100 -Tabstop", "Cancel")
        this.Status := this.Gui.AddText("x+12 yp+6 w200 cRed", "")

        this.BtnSave.OnEvent("Click", (*) => InputWindow.Submit())
        this.BtnCancel.OnEvent("Click", (*) => InputWindow.Cancel())
        this.Gui.OnEvent("Close", (*) => InputWindow.Cancel())
        this.Gui.OnEvent("Escape", (*) => InputWindow.Cancel())

        this.Gui.Show("AutoSize Center")
        WinActivate("ahk_id " this.Gui.Hwnd)
        this.Edit.Focus()
    }

    Destroy() {
        InputWindow.Current := ""
        try this.Gui.Destroy()
    }
}
