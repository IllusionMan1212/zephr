package zephr_logger

import "core:log"
import "core:os"
import "core:fmt"

import "shared:android"

when ODIN_DEBUG {
    @(private)
    TerminalLoggerOpts :: log.Default_Console_Logger_Opts
} else {
    @(private)
    TerminalLoggerOpts :: log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Date, .Time}
}

logger: log.Logger

init :: proc() {
    // NOTE: This guard is needed so we don't reopen the log file on activity recreation in android.
    if zephr_ctx.logger_fd != os.Handle(0) {
        return
    }

	when ODIN_PLATFORM_SUBTARGET == .Android {
		log_file, err := os.open(create_appdata_path("zephr.log", context.temp_allocator), os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
		if err != os.ERROR_NONE {
			android.__android_log_print(.ERROR, "zephr", "[ERROR] Failed to open log file. Logs will not be written. Error code: %d", err)
			return
		}
		zephr_ctx.logger_fd = log_file
	} else {
		log_file, err := os.open("zephr.log", os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o644)
		if err != os.ERROR_NONE {
			fmt.eprintfln("[ERROR] Failed to open log file. Logs will not be written. Error code: %d", err)
			return
		}
		zephr_ctx.logger_fd = log_file
	}

    file_logger := log.create_file_logger(log_file)
    term_logger := log.create_console_logger(opt = TerminalLoggerOpts)

    logger = log.create_multi_logger(file_logger, term_logger)
}

@(private)
logger_init :: proc() {

    when ODIN_PLATFORM_SUBTARGET == .Android {
        log_file, err := os.open(create_appdata_path("zephr.log", context.temp_allocator), os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o664)
        if err != os.ERROR_NONE {
            android.__android_log_print(.ERROR, "zephr", "[ERROR] Failed to open log file. Logs will not be written. Error code: %d", err)
            return
        }
        zephr_ctx.logger_fd = log_file
    } else {
        log_file, err := os.open("zephr.log", os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o664)
        if err != os.ERROR_NONE {
            fmt.eprintln("[ERROR] Failed to open log file. Logs will not be written. Error code: %d", err)
            return
        }
        zephr_ctx.logger_fd = log_file
    }

}
