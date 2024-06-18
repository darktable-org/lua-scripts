
local dtutils_log = {}

dtutils_log.libdoc = {
  Name = [[dtutils.log]],
  Synopsis = [[darktable lua logging library]],
  Usage = [[local log = require "lib/dtutils.log"]],
  Description = [[log provides a multi-level logging solution for use with
    the darktable lua scripts.  With this library you can leave log messages 
    scattered through out your code and only turn them on as necessary.]],
  Return_Value = [[log - library - the darktable lua logging functions]],
  Limitations = [[]],
  Example = [[local log = require "lib/dtutils.log"

  local cur_level = log.log_level()
  log.log_level(log.warn)

  print out warning, error and success messages as code is running

  log.log_level(log.debug)

  print out debugging messages too because this isnt working

  log.log_level(log.info)

  I want to make sure this is working ok

  log.log_level(cur_level)

  reset the logging level back to normal]],
  See_Also = [[]],
  Reference = [[]],
  License = [[This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.]],
  Copyright = [[Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.]],
  functions = {}
}

local dt = require "darktable"
local dt_print_error = dt.print_error
local dt_print_log = dt.print_log
local dt_print = dt.print


-- set the default log levels

dtutils_log.debug = {
  label = "DEBUG: ", 
  enabled = false,
  engine = dt_print_log,
  caller_info = 3,
  level = 1,
}
dtutils_log.info = {
  label = "INFO: ", 
  enable = false,
  engine = dt_print_log,
  caller_info = 1,
  level = 2,
}
dtutils_log.warn = {
  label = "WARN: ", 
  enabled = false,
  engine = dt_print_log,
  caller_info = 2,
  level = 3,
}
dtutils_log.error = {
  label = "ERROR: ",
  enabled = true,
  engine = dt_print_log,
  caller_info = 3,
  level = 4,
}
dtutils_log.success = {
  label = "SUCCESS: ", 
  enabled = true,
  engine = dt_print_log,
  caller_info = 2,
  level = 5,
}
dtutils_log.screen = {
  label = "",
  enabled = true,
  engine = dt_print,
  caller_info = 0,
  level = 9,
}
dtutils_log.always = {
  label = "",
  enabled = true,
  engine = dt_print_log,
  caller_info = 3,
  level = 9,
}
dtutils_log.critical = {
  label = "CRITICAL: ",
  enabled = true,
  engine = print,
  caller_info = 3,
  level = 9,
}

dtutils_log.libdoc.functions["caller"] = {
  Name = [[caller]],
  Synopsis = [[get the name and line number of the calling routine]],
  Usage = [[local log = require "lib/dtutils.log"

result = log.caller(level)
      level - number - the  number of stack levels to go down to retrieve the caller routine information]],
  Description = [[caller gets the name and line number of the calling routine and returns it]],
  Return_Value = [[result - string - the name and line number of the calling function or 'callback: ' if the attempt to get the 
    caller returns nil]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_log.caller(level, info)
  local name = debug.getinfo(level).name
  local lineno = nil
  local source = nil
    if name then
      lineno = debug.getinfo(level).currentline
      -- returns the path to the file prefixed with @
      source = debug.getinfo(level).source
      -- we just need the filename, so grab it from the string
      -- Thanks, Tobias Jakobs  :-)
      source = string.match(source, "@.-([^\\/]-%.?[^%.\\/]*)$")

      if info == 0 then
        return ""
      elseif info == 1 then
        return source .. ": "
      elseif info == 2 then
        return source .. ": " .. name .. ": "
      else
        return source .. ": " .. name .. ": " .. lineno .. ":"
      end
    else
      return "callback:"
    end
end

dtutils_log.libdoc.functions["msg"] = {
  Name = [[msg]],
  Synopsis = [[print a log message]],
  Usage = [[local log = require "lib/log"

    log.msg(level, ...)
      level - table - the type of message, one of: 
        log.debug    - debugging messages
        log.info     - informational messages
        log.warn     - warning messages 
        log.error    - error messages 
        log.success  - success messages
        log.always   - an internal message for debugging
        log.screen   - output 1 line of text to the screen
        log.critical - print a critical message to the console

      ... - string(s) - the message to print, which could be a comma separated set of strings]],
  Description = [[msg checks the level to see if it is enabled, then prints the level type and message if it is.
    Messages are output using the engine configured in each log level.]],
  Return_Value = [[]],
  Limitations = [[If you use log.msg in a callback, the name of the calling routine can't be determined.  A solution
    is to include some means of reference such as the name of the callback as an argument, i.e. 

      log.msg(log.debug, "libPlugin.format_combobox:", "value is " .. self.value)

    which would result in

      DEBUG: callback: libPlugin.format_combobox: value is JPEG]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_log.msg(level, ...)
  if level.enabled then
    local args = {...}
    local call_level = 3
    if level == dtutils_log.always then
      call_level = args[1]
      table.remove(args, 1)
    end
    local log_msg = level.label
    if level.engine ~= dt_print and call_level ~= 0 then
      log_msg = log_msg .. dtutils_log.caller(call_level, level.caller_info) .. " "
    elseif log_msg:len() > 2 then
      log_msg = log_msg .. " "
    end
    for i = 1,#args do
      log_msg = log_msg .. tostring(args[i]) .. " "
    end
    level.engine(log_msg)
  end
end

dtutils_log.libdoc.functions["log_level"] = {
  Name = [[log_level]],
  Synopsis = [[get or set the log level]],
  Usage = [[local log = require "lib/log"

    local result = log.log_level(...)
      ... - arguments - if none is supplied, then the current log level is returned as one of:
      log.debug, log.info, log.warn, log.error, log.success.  If one of log.debug, log.info, log.warn,
      log.error, or log.success is supplied as the argument then the log level is set to that value.  All
      log levels greater than or equal in value will be enabled.  Any levels of lesser value will be disabled.]],
  Description = [[log_level gets and sets the logging level.  When called with no arguments the current log level
  is returned as one of log.debug, log.info, log.warn, log.error, or log.success.  When called with one of log.debug, 
  log.info, log.warn, log.error or log.success then the log level is set.  When setting the log level all levels 
  equal or greater are enabled and any of lesser value are disabled.  See the example.]],
  Return_Value = [[result - the log level, one of log.debug, log.info, log.warn, log.error or log.success]],
  Limitations = [[]],
  Example = [[Assume that the current log level is log.error.  Calling log.log_level() will return log.error.
  Calling log.log_level(log.info) will leave log.debug disabled, and enable log.info, log.warn, log.error and 
  log.success.  log.info will be returned as the log_level.]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_log.log_level(...)
  local levels = {"debug", "info", "warn", "error", "success"}
  local args = {...}
  local log_level = nil
  if #args > 0 then
    log_level = args[1]
    if log_level == dtutils_log.critical or
       log_level == dtutils_log.screen or
       log_level == dtutils_log.always then
       -- these aren't valid for setting levels
      return nil
    else
      for _,v in ipairs(levels) do
        if dtutils_log[v].level >= log_level.level then
          dtutils_log[v].enabled = true
        else
          dtutils_log[v].enabled = false
        end
      end
    end
  else
    for _,v in ipairs(levels) do
      if dtutils_log[v].enabled == true then
        log_level = dtutils_log[v]
        break
      end
    end
  end
  return log_level
end

dtutils_log.libdoc.functions["engine"] = {
  Name = [[engine]],
  Synopsis = [[get and set the output engine]],
  Usage = [[local log = require "lib/dtutils.log"

result = log.engine(level, ...)
      level - table - the log level to get or set the engine for, one of log.debug, log.info, log.warn, log.error
      log.success, log.always, log.screen, log.critical
      ... - function - the output function, one of dt.print, dt.print_error, dt.print_log, print
      if not function is included, the current engine is returned for the specified log level]],
  Description = [[engine returns the output engine for the specified log level if a second argument is not
  supplied.  If a function is supplied as the second argment, then the output engine for the specified log level
  is set to that.]],
  Return_Value = [[result - function - the current output engine]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_log.print_engine(level, ...)
  local engines = {"dt_print", "dt_print_error", "dt_print_log", "print"}
  local args = {...}
  local cur_engine = ""
  if #args == 0 then
    cur_engine = level.engine
  else
    for _,v in ipairs(engines) do
      if args[1] == v then
        level.engine = args[1]
        cur_engine = level.engine
      end
    end
  end
  return cur_engine
end

return dtutils_log
