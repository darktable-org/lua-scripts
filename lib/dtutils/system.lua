local dtutils_system = {}

local dt = require "darktable"
local ds = require "lib/dtutils.string"

dtutils_system.libdoc = {
  Name = [[dtutils.system]],
  Synopsis = [[a library of system utilities for use in darktable lua scripts]],
  Usage = [[local ds = require "lib/dtutils.system"]],
  Description = [[This library contains routines for interfacing to the operating system from
    darktable lua scripts.]],
  Return_Value = [[du - library - the darktable lua system library]],
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
  Copyright = [[Copyright (c) 2018 Bill Ferguson <wpferguson@gmail.com>]],
  functions = {}
}

dtutils_system.libdoc.functions["external_command"] = {
  Name = [[external_command]],
  Synopsis = [[pass a command to the operating system for execution and return the result]],
  Usage = [[local dsys = require "lib/dtutils.system"

    local result = dsys.external_command(command)
      command - string - a string containing the command and arguments to be passed to the operating system for execution.]],
  Description = [[external_command passes a command to the operating system for execution and returns the results.]], 
  Return_Value = [[result - the return value signalling success or failure.]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_system.external_command(command)
  local result = nil

  if dt.configuration.running_os == "windows" then
    result = dtutils_system.windows_command(command)
  else
    result = dt.control.execute(command)
  end

  return result
end

dtutils_system.libdoc.functions["windows_command"] = {
  Name = [[windows_command]],
  Synopsis = [[pass a command to the windows operating system for execution and return the result]],
  Usage = [[local dsys = require "lib/dtutils.system"

    local result = dsys.windows_command(command)
      command - string - a string containing the command and arguments to be passed to the operating system for execution.]],
  Description = [[The normal method of executing an operating system command is using dt.control.execute(), but that doesn't 
    work with Windows when more than one item in the command is quoted.  In order to ensure command execution on Windows we 
    create a batch file in the temporary directory, put the command in it, execute the batch file, then return the result.]], 
  Return_Value = [[result - the return value signalling success or failure.]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_system.windows_command(command)
  local result = 1

  local fname = dt.configuration.tmp_dir .. "/run_command.bat"

  local file = io.open(fname, "w")
  if file then
    dt.print_log("opened file")
    file:write("@echo off\n")
    file:write('for /f "tokens=2 delims=:." %%x in (\'chcp\') do set cp=%%x\n')
    file:write("chcp 65001>nul\n") -- change the encoding of the terminal to handle non-english characters in path
    file:write("\n")
    file:write(command .. "\n")
    file:write("\n") 
    file:write("chcp %cp%>nul\n")
    file:close()

    result = dt.control.execute(fname)
    dt.print_log("result from windows command was " .. result)

    os.remove(fname)
  else
    dt.print_error("Windows command failed: unable to create batch file")
  end

  return result
end


dtutils_system.libdoc.functions["launch_default_app"] = {
  Name = [[launch_default_app]],
  Synopsis = [[open file in default application]],
  Usage = [[local dsys = require "lib/dtutils.file"

    result = dsys.launch_default_app(path)
      path - string - a file path]],
  Description = [[launch_default_app allows opening a file in the application that is assigned as default 
    for that filetype in the users's system]],
  Return_Value = [[result - the return value signalling success or failure.]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_system.launch_default_app(path) 
  local open_cmd = "xdg-open "
  if (dt.configuration.running_os == "windows") then
    open_cmd = "" -- On Windows we don't need any command. (start e.g. has problems with spaces in the filename, even if we put quoter around them.) https://stackoverflow.com/questions/13691827/opening-file-with-spaces-in-windows-via-command-prompt
  elseif  (dt.configuration.running_os == "macos") then
    open_cmd = "open "
  end   
  return dtutils_system.external_command(open_cmd .. path)
end

return dtutils_system
