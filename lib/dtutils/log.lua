--[[

    log.lua - darktable lua logging library

    Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local dtutils_log = {}

dtutils_log.libdoc = {
  Name = [[dtutils.log]],
  Synopsis = [[darktable lua logging library]],
  Usage = [[local log = require "lib/dtutils.log"]],
  Description = [[log provides a multi-level logging solution for use with
    the darktable lua scripts.]],
  Return_Value = [[log - library - the darktable lua logging functions]],
  Limitations = [[]],
  Example = [[]],
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

-- set the default log levels

dtutils_log.debug = {"DEBUG:", false}
dtutils_log.info = {"INFO:", false}
dtutils_log.warn = {"WARN:", false}
dtutils_log.error = {"ERROR:", true}
dtutils_log.success = {"SUCCESS:", true}

dtutils_log.libdoc.functions["caller"] = {
  Name = [[caller]],
  Synopsis = [[get the name and line number of the calling routine]],
  Usage = [[local log = require "lib/log"

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

function dtutils_log.caller(level)
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
      return name .. ": " .. source .. ": " .. lineno .. ":"
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
        log.debug   - debugging messages
        log.info    - informational messages
        log.warn    - warning messages 
        log.error   - error messages 
        log.success - success messages
      ... - string(s) - the message to print, which could be a comma separated set of strings]],
  Description = [[msg checks the level to see if it is enabled, then prints the level type and message if it is.
    debug messages print straight to the console, info and warn messages to dt.print_error() and error
    and success to dt.print()]],
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
  local message = {...}
  if level[2] == true then
    dtutils_log.print(level[1], dtutils_log.caller(3), unpack(message))
  end
end

dtutils_log.libdoc.functions["print"] = {
  Name = [[print]],
  Synopsis = [[print the supplied arguments]],
  Usage = [[local log = require "lib/log"

    log.print(...)
      ... - arguments to be printed that are converted with tostring()]],
  Description = [[print loops through the arguments converting each to a string then writing
    them to stdout.  Spaces are put between each argument on output.]],
  Return_Value = [[]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[http://stackoverflow.com/questions/7148678/lua-print-on-the-same-line]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_log.print(...)
  local write = io.write
  local n = select("#",...)
    for i = 1,n do
      local v = tostring(select(i,...))
      write(v)
      if i~=n then 
        write(' ') 
      end
    end
    write('\n')
end

dtutils_log.libdoc.functions["set_level"] = {
  Name = [[set_level]],
  Synopsis = [[set the logging level]],
  Usage = [[local log = require "lib/log"

    log.set_level(level)
      level - string - a string specifying the level, one of: "debug", "info", "warn", "error", "success"]],
  Description = [[set_level sets the logging level to the level specified.  Every level above the specified level 
    is also enabled, therefore specifying "debug" would turn on all levels and specifying "success"
    would turn all levels off except log.success.]],
  Return_Value = [[]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_log.set_level(level)
  level = level:lower()
  if string.match(level, "debug") then
    -- turn everything on
    dtutils_log.debug[2] = true
    dtutils_log.info[2] = true
    dtutils_log.warn[2] = true
    dtutils_log.error[2] = true
    dtutils_log.success[2] = true
  elseif string.match(level, "info") then
    -- turn off debug and everything else on
    dtutils_log.debug[2] = false
    dtutils_log.info[2] = true
    dtutils_log.warn[2] = true
    dtutils_log.error[2] = true
    dtutils_log.success[2] = true
  elseif string.match(level, "warn") then
    -- turn off debug and info and everything else on
    dtutils_log.debug[2] = false
    dtutils_log.info[2] = false
    dtutils_log.warn[2] = true
    dtutils_log.error[2] = true
    dtutils_log.success[2] = true
  elseif string.match(level, "error") or string.match("reset") then
    -- everything off except error and success
    dtutils_log.debug[2] = false
    dtutils_log.info[2] = false
    dtutils_log.warn[2] = false
    dtutils_log.error[2] = true
    dtutils_log.success[2] = true
  elseif string.match(level, "success") then
    -- everything off except success
    dtutils_log.debug[2] = false
    dtutils_log.info[2] = false
    dtutils_log.warn[2] = false
    dtutils_log.error[2] = false
    dtutils_log.success[2] = true
  else
    -- leave everything unchanged and return
    return
  end
end

dtutils_log.libdoc.functions["get_level"] = {
  Name = [[get_level]],
  Synopsis = [[get the current logging level]],
  Usage = [[local log = require "lib/log"

    local result = log.get_level()]],
  Description = [[get_level returns a string representing the current log level.]],
  Return_Value = [[result - string - one of "debug", "info", "warn", "error", or "success"]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_log.get_level()
  local result = nil
  if dtutils_log.debug[2] == true then
    result = "debug"
  elseif log.info[2] == true then
    result = "info"
  elseif log.warn[2] == true then
    result = "warn"
  elseif log.error[2] == true then
    result = "error"
  elseif log.success[2] == true then
    result = "success"
  end
  return result
end

dtutils_log.libdoc.functions["always"] = {
  Name = [[always]],
  Synopsis = [[always write out a log message]],
  Usage = [[local log = require "lib/log"

    log.always(level, ...)
      level - number - the number of stack levels to go back to identify the caller
      ... - string(s) - the message to print]],
  Description = [[always is meant specifically for the dtutils.debug library, but may be used for other
    purposes.  always is independent of the log level setting so that it will always work.
    The number of stack levels to look back for the caller may be specified.  It is normally
    3 when called from a routine, but is 4 when called from the debugging routines since the
    debugging routines add another stack level.]],
  Return_Value = [[]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_log.always(level, ...)
  local message = {...}
  dtutils_log.print(log.caller(level), unpack(message))
end

return dtutils_log
