#Requires AutoHotkey v2.0

; Minimal append-only logger -> <project>\logs\obsill.log
; Logging must never break capturing, so every call swallows its own errors.
; (The class is NOT called "Log" because AutoHotkey already has a built-in Log() function.)
class ObsillLog {
    static Path := ""
    static MaxBytes := 512 * 1024

    static Init(logDir) {
        try DirCreate(logDir)
        ObsillLog.Path := logDir "\obsill.log"
        try {
            if (FileExist(ObsillLog.Path) && FileGetSize(ObsillLog.Path) > ObsillLog.MaxBytes)
                FileMove(ObsillLog.Path, ObsillLog.Path ".old", true)
        }
    }

    static Write(level, message) {
        if (ObsillLog.Path = "")
            return
        line := FormatTime(, "yyyy-MM-dd HH:mm:ss") " [" level "] " message "`n"
        try FileAppend(line, ObsillLog.Path, "UTF-8-RAW")
    }

    static Info(message) {
        ObsillLog.Write("INFO", message)
    }

    static Warn(message) {
        ObsillLog.Write("WARN", message)
    }

    static Err(message) {
        ObsillLog.Write("ERROR", message)
    }
}
