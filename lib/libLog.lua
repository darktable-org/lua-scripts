--[[

    libLog.lua - darktable lua logging library

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

local libLog = {}
libLog.libdoc = {
  Sections = {"Name", "Synopsis", "Description", "License", "Copyright"},
  Name = "libLog - darktable lua logging library",
  Synopsis = [[local log = require "lib/libLog"]],
  Description = [[libLog provides a multi-level logging solution for use with
    the darktable lua scripts.]],
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
  Copyright = "Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.",
  functions = {}
}

local dt = require "darktable"

-- set the default log levels

libLog.debug = {"DEBUG:", false}
libLog.info = {"INFO:", false}
libLog.warn = {"WARN:", false}
libLog.error = {"ERROR:", true}
libLog.success = {"SUCCESS:", true}

libLog.libdoc.functions[#libLog.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = "caller - get the name of the calling routine",
  Synopsis = [[local log = require "lib/libLog"

result = log.caller(level)
      level - number - the  number of stack levels to go down to retrieve the caller routine information]],
  Description = "caller gets the name of the calling routine and returns it",
  Return_Value = [[result - string - the name and line number of the calling function or 'callback: ' if the attempt to get the 
                      caller returns nil]],
}

--[[
  NAME
    caller - get the name of the calling routine

  SYNOPSIS
    local log = require "lib/libLog"

    local result = log.caller(level)
      level - number - the  number of stack levels to go down to retrieve the caller routine information

  DESCRIPTION
    caller gets the name of the calling routine and returns it

  RETURN VALUE
    result - string - the name of the calling function and line number or 'callback: ' if the attempt to get the 
                      caller returns nil


]]

function libLog.caller(level)
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

libLog.libdoc.functions[#libLog.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Limitations"},
  Name = "msg - print a log message",
  Synopsis = [[local log = require "lib/libLog"

    log.msg(level, ...)
      level - table - the type of message, one of: 
        libLog.debug   - debugging messages
        libLog.info    - informational messages
        libLog.warn    - warning messages 
        libLog.error   - error messages 
        libLog.success - success messages
      ... - string(s) - the message to print, which could be a comma separated set of strings]],
  Description = [[msg checks the level to see if it is enabled, then prints the level type and message if it is.
    debug messages print straight to the console, info and warn messages to dt.print_error() and error
    and success to dt.print()]],
  Limitations = [[If you use libLog.msg in a callback, the name of the calling routine can't be determined.  A solution
    is to include some means of reference such as the name of the callback as an argument, i.e. 

      libLog.msg(libLog.debug, "libPlugin.format_combobox:", "value is " .. self.value)

    which would result in

      DEBUG: callback: libPlugin.format_combobox: value is JPEG]],
}

--[[
  NAME
    msg - print a log message

  SYNOPSIS
    local log = require "lib/libLog"

    log.msg(level, ...)
      level - table - the type of message, one of: 
        libLog.debug   - debugging messages
        libLog.info    - informational messages
        libLog.warn    - warning messages 
        libLog.error   - error messages 
        libLog.success - success messages
      ... - string(s) - the message to print, which could be a comma separated set of strings

  DESCRIPTION
    msg checks the level to see if it is enabled, then prints the level type and message if it is.
    debug messages print straight to the console, info and warn messages to dt.print_error() and error
    and success to dt.print()

  RETURN VALUE
    none

  LIMITATIONS
    If you use libLog.msg in a callback, the name of the calling routine can't be determined.  A solution
    is to include some means of reference such as the name of the callback as an argument, i.e. 

      libLog.msg(libLog.debug, "libPlugin.format_combobox:", "value is " .. self.value)

    which would result in

      DEBUG: callback: libPlugin.format_combobox: value is JPEG

]]

function libLog.msg(level, ...)
  local message = {...}
  if level[2] == true then
    libLog.print(level[1], libLog.caller(3), unpack(message))
  end
end

libLog.libdoc.functions[#libLog.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value", "Reference"},
  Name = "print - print the supplied arguments",
  Synopsis = [[local log = require "lib/libLog"

    log.print(...)
      ... - arguments to be printed that are converted with tostring()]],
  Description = [[print loops through the arguments converting each to a string then writing
    them to stdout.  Spaces are put between each argument on output.]],
  Return_Value = "none",
  Reference = "http://stackoverflow.com/questions/7148678/lua-print-on-the-same-line",
}

--[[
  NAME
    libLog.print - print the supplied arguments

  SYNOPSIS
    local log = require "lib/libLog"

    log.print(...)
      ... - arguments to be printed that are converted with tostring()

  DESCRIPTION
    print loops through the arguments converting each to a string then writing
    them to stdout.  Spaces are put between each argument on output.

  RETURN VALUE
    none

  REFERENCE
    http://stackoverflow.com/questions/7148678/lua-print-on-the-same-line

]]

function libLog.print(...)
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

libLog.libdoc.functions[#libLog.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[set_level - set the logging level]],
  Synopsis = [[local log = require "lib/libLog"

    log.set_level(level)
      level - string - a string specifying the level, one of: "debug", "info", "warn", "error", "success"]],
  Description = [[set_level sets the logging level to the level specified.  Every level above the specified level 
    is also enabled, therefore specifying "debug" would turn on all levels and specifying "success"
    would turn all levels off except libLog.success.]],
  Return_Value = "none",
}

--[[
  NAME
    set_level - set the logging level

  SYNOPSIS
    local log = require "lib/libLog"

    log.set_level(level)
      level - string - a string specifying the level, one of: "debug", "info", "warn", "error", "success"

  DESCRIPTION
    set_level sets the logging level to the level specified.  Every level above the specified level 
    is also enabled, therefore specifying "debug" would turn on all levels and specifying "success"
    would turn all levels off except libLog.success.

  RETURN VALUE
    none

]]

function libLog.set_level(level)
  level = level:lower()
  if string.match(level, "debug") then
    -- turn everything on
    libLog.debug[2] = true
    libLog.info[2] = true
    libLog.warn[2] = true
    libLog.error[2] = true
    libLog.success[2] = true
  elseif string.match(level, "info") then
    -- turn off debug and everything else on
    libLog.debug[2] = false
    libLog.info[2] = true
    libLog.warn[2] = true
    libLog.error[2] = true
    libLog.success[2] = true
  elseif string.match(level, "warn") then
    -- turn off debug and info and everything else on
    libLog.debug[2] = false
    libLog.info[2] = false
    libLog.warn[2] = true
    libLog.error[2] = true
    libLog.success[2] = true
  elseif string.match(level, "error") or string.match("reset") then
    -- everything off except error and success
    libLog.debug[2] = false
    libLog.info[2] = false
    libLog.warn[2] = false
    libLog.error[2] = true
    libLog.success[2] = true
  elseif string.match(level, "success") then
    -- everything off except success
    libLog.debug[2] = false
    libLog.info[2] = false
    libLog.warn[2] = false
    libLog.error[2] = false
    libLog.success[2] = true
  else
    -- leave everything unchanged and return
    return
  end
end

libLog.libdoc.functions[#libLog.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[get_level - get the current logging level]],
  Synopsis = [[local log = require "lib/libLog"

    local result = libLog.get_level()]],
  Description = "get_level returns a string representing the current log level.",
  Return_Value = [[result - string - one of "debug", "info", "warn", "error", or "success"]],
}

--[[
  NAME
    get_level - get the current logging level

  SYNOPSIS
    local log = require "lib/libLog"

    local result = log.get_level()

  DESCRIPTION
    get_level returns a string representing the current log level.

  RETURN VALUE
    result - string - one of "debug", "info", "warn", "error", or "success"

]]

function libLog.get_level()
  local result = nil
  if libLog.debug[2] == true then
    result = "debug"
  elseif libLog.info[2] == true then
    result = "info"
  elseif libLog.warn[2] == true then
    result = "warn"
  elseif libLog.error[2] == true then
    result = "error"
  elseif libLog.success[2] == true then
    result = "success"
  end
  return result
end

libLog.libdoc.functions[#libLog.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description"},
  Name = [[always - always write out a log message]],
  Synopsis = [[local log = require "lib/libLog"

    log.always(level, ...)
      level - number - the number of stack levels to go back to identify the caller
      ... - string(s) - the message to print]],
  Description = [[always is meant specifically for the dtutils.debug library, but may be used for other
    purposes.  always is independent of the log level setting so that it will always work.
    The number of stack levels to look back for the caller may be specified.  It is normally
    3 when called from a routine, but is 4 when called from the debugging routines since the
    debugging routines add another stack level.]],
}

--[[
  NAME
    always - always write out a log message

  SYNOPSIS
    local log = require "lib/libLog"

    log.always(level, ...)
      level - number - the number of stack levels to go back to identify the caller
      ... - string(s) - the message to print

  DESCRIPTION
    always is meant specifically for the dtutils.debug library, but may be used for other
    purposes.  always is independent of the log level setting so that it will always work.
    The number of stack levels to look back for the caller may be specified.  It is normally
    3 when called from a routine, but is 4 when called from the debugging routines since the
    debugging routines add another stack level.
]]

function libLog.always(level, ...)
  local message = {...}
  libLog.print(libLog.caller(level), unpack(message))
end

return libLog
