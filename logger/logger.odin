package zephr_logger

import "core:log"
import "core:os"
import "core:fmt"

when ODIN_DEBUG {
    @(private)
    TerminalLoggerOpts :: log.Default_Console_Logger_Opts
} else {
    @(private)
    TerminalLoggerOpts :: log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Date, .Time}
}

logger: log.Logger

init :: proc() {
    log_file, err := os.open("zephr.log", os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
    if err != os.ERROR_NONE {
        fmt.eprintln("[ERROR] Failed to open log file. Logs will not be written")
        return
    }

    file_logger := log.create_file_logger(log_file)
    term_logger := log.create_console_logger(opt = TerminalLoggerOpts)

    logger = log.create_multi_logger(file_logger, term_logger)
}
