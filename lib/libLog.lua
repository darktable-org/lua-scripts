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

local dt = require "darktable"

libLog = {}

-- set the default log levels

libLog.debug = {"DEBUG:", false}
libLog.info = {"INFO:", false}
libLog.warn = {"WARN:", false}
libLog.error = {"ERROR:", true}
libLog.success = {"SUCCESS:", true}

--[[
  NAME
    libLog.msg - print a log message

  SYNOPSIS
    libLog.msg(level, message)
      level - one of libLog.debug, libLog.info, libLog.warn, libLog.error, libLog.success
      message - the message to print

  DESCRIPTION
    msg checks the level to see if it is enabled, then prints the level type and message if it is.
    debug messages print straight to the console, info and warn messages to dt.print_error() and error
    and success to dt.print()

  RETURN VALUE
    none

  ERRORS



]]

function libLog.msg(level, message)
  if level[2] == true then
    if level[1] == "DEBUG:" then
      print(level[1], message)
    elseif level[1] == "INFO:" or level[1] == "WARN:" then
      dt.print_error(level[1], message)
    else
      dt.print(level[1], message)
    end
  end
end

--[[
  NAME
    libLog.setLevel - set the logging level

  SYNOPSIS
    libLog.setLevel(level)
      level - a string specifying the level, one of: "debug", "info", "warn", "error", "success"

  DESCRIPTION
    setLevel sets the logging level to the level specified.  Every level above the specified level 
    is also enabled, therefore specifying "debug" would turn on all levels and specifying "success"
    would turn all levels off except libLog.success.

  RETURN VALUE
    none

  ERRORS



]]
function libLog.setLevel(level)
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
    libLog.success[2] = false
  else
    dt.print_error("No such log level " .. level)
  end
end


return libLog