--[[

    dtutils/file.lua - common darktable lua file functions

    Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.
    Copyright (C) 2016 Tobias Jakobs

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

local dtutils_file = {}
dtutils_file.libdoc = {
  Sections = {"Name", "Synopsis", "Description", "License"},
  Name = [[dtutils.file - common darktable lua file functions]],
  Synopsis = [[local df = require "lib/dtutils.file"]],
  Description = [[dtutils.file provides common file manipulation functions used in
  constructing Darktable lua scripts]],
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
  functions = {}
}

local dt = require "darktable"

local log = require "lib/libLog"

local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("dtutils.file",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("dtutils.file", msgid)
end

--[[
  NAME
    check_if_bin_exists - check if an executable is in the path

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.check_if_bin_exists(bin)
      bin - string - the binary to check for

  DESCRIPTION
    check_if_bin_exists checks to see if the specified binary executable is
    in the path.

  RETURN VALUE
    result - boolean - true if the executable was found, false if not

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[check_if_bin_exists - check if an executable is in the path]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.check_if_bin_exists(bin)
      bin - string - the binary to check for]],
  Description = [[check_if_bin_exists checks to see if the specified binary executable is
    in the path.]],
  Return_Value = [[result - boolean - true if the executable was found, false if not]],
}

function dtutils_file.check_if_bin_exists(bin)
  local result = os.execute("which " .. bin)
  if not result then
    result = false
  end
  return result
end

--[[
  NAME
    split_filepath - split a filepath into parts

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.split_filepath(filepath)
      filepath - string - path and filename

  DESCRIPTION
    split_filepath splits a filepath into the path, filename, basename and filetype and puts
    that in a table

  RETURN VALUE
    result - table - a table containing the path, filename, basename, and filetype

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[split_filepath - split a filepath into parts]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.split_filepath(filepath)
      filepath - string - path and filename]],
  Description = [[split_filepath splits a filepath into the path, filename, basename and filetype and puts
    that in a table]],
  Return_Value = [[result - table - a table containing the path, filename, basename, and filetype]],
}

function dtutils_file.split_filepath(str)
  local result = {}
  -- Thank you Tobias Jakobs for the awesome regular expression, which I tweaked a little
  result["path"], result["filename"], result["basename"], result["filetype"] = string.match(str, "(.-)(([^\\/]-)%.?([^%.\\/]*))$")
  return result
end

--[[
  NAME
    get_path - get the path from a file path

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.get_path(filepath)
      filepath - string - path and filename

  DESCRIPTION
    get_path strips the filename and filetype from a path and returns the path

  RETURN VALUE
    result - string - the path

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[get_path - get the path from a file path]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.get_path(filepath)
      filepath - string - path and filename]],
  Description = [[get_path strips the filename and filetype from a path and returns the path]],
  Return_Value = [[result - string - the path]],
}

function dtutils_file.get_path(str)
  local parts = dtutils_file.split_filepath(str)
  return parts["path"]
end

--[[
  NAME
    get_filename - get the filename and extension from a file path

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.get_filename(filepath)
      filepath - string - path and filename

  DESCRIPTION
    get_filename strips the path from a filepath and returns the filename

  RETURN VALUE
    result - string - the file name and type

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[get_filename - get the filename and extension from a file path]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.get_filename(filepath)
      filepath - string - path and filename]],
  Description = [[get_filename strips the path from a filepath and returns the filename]],
  Return_Value = [[result - string - the file name and type]],
}

function dtutils_file.get_filename(str)
  local parts = dtutils_file.split_filepath(str)
  return parts["filename"]
end

--[[
  NAME
    get_basename - get the filename without the path or extension

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.get_basename(filepath)
      filepath - string - path and filename

  DESCRIPTION
    get_basename returns the name of the file without the path or filetype

  RETURN VALUE
    result - string - the basename of the file

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[get_basename - get the filename without the path or extension]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.get_basename(filepath)
      filepath - string - path and filename]],
  Description = [[get_basename returns the name of the file without the path or filetype]],
  Return_Value = [[result - string - the basename of the file]],
}

function dtutils_file.get_basename(str)
  local parts = dtutils_file.split_filepath(str)
  return parts["basename"]
end

--[[
  NAME
    get_filetype - get the filetype from a filename

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.get_filetype(filepath)
      filepath - string - path and filename

  DESCRIPTION
    get_filetype returns the filetype from the supplied filepath

  RETURN VALUE
    result - string - the filetype

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[get_filetype - get the filetype from a filename]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.get_filetype(filepath)
      filepath - string - path and filename]],
  Description = [[get_filetype returns the filetype from the supplied filepath]],
  Return_Value = [[result - string - the filetype]],
}

function dtutils_file.get_filetype(str)
  local parts = dtutils_file.split_filepath(str)
  return parts["filetype"]
end

--[[
  NAME
    check_if_file_exists - check if a file or path exist

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.check_if_file_exists(filepath)
      filepath - string - a file or path to check

  DESCRIPTION
    check_if_file_exists checks to see if a file or path exists

  RETURN VALUE
    result - boolean - true if the file or path exists, false if it doesn't

]]

-- Thanks Tobias Jakobs for the idea
dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[check_if_file_exists - check if a file or path exist]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.check_if_file_exists(filepath)
      filepath - string - a file or path to check]],
  Description = [[check_if_file_exists checks to see if a file or path exists]],
  Return_Value = [[result - boolean - true if the file or path exists, false if it doesn't]],
}

function dtutils_file.check_if_file_exists(filepath)
  local result = os.execute("test -e " .. filepath)
  if not result then
    result = false
  end
  return result
end

--[[
  NAME
    chop_filetype - remove a filetype from a filename

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.chop_filetype(path)
      path - string - a filename with or without a path

  DESCRIPTION
    chop_filetype removes the filetype from the filename

  RETURN VALUE
    result - string - the path and filename without the filetype

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[chop_filetype - remove a filetype from a filename]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.chop_filetype(path)
      path - string - a filename with or without a path]],
  Description = [[chop_filetype removes the filetype from the filename]],
  Return_Value = [[result - string - the path and filename without the filetype]],
}

function dtutils_file.chop_filetype(path)
  local length = dtutils_file.get_filetype(path):len() + 2
  return string.sub(path, 1, -length)
end

--[[
  NAME
    file_copy - copy a file to another name/location

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.file_copy(fromFile, toFile)
      fromFile - string - name of file to copy from
      toFile - string - name of file to copy to

  DESCRIPTION
    copy a file using a succession of methods from operating system
    to a pure lua solution

  RETURN VALUE
    result - boolean - nil on error, true on success

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[file_copy - copy a file to another name/location]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.file_copy(fromFile, toFile)
      fromFile - string - name of file to copy from
      toFile - string - name of file to copy to]],
  Description = [[copy a file using a succession of methods from operating system
    to a pure lua solution]],
  Return_Value = [[result - boolean - nil on error, true on success]],
}

function dtutils_file.file_copy(fromFile, toFile)
  local result = nil
  -- if cp exists, use it
  if dtutils_file.check_if_bin_exists("cp") then
    result = os.execute("cp '" .. fromFile .. "' '" .. toFile .. "'")
  end
  -- if cp was not present, or if cp failed, then a pure lua solution
  if not result then
    local fileIn, err = io.open(fromFile, 'rb')
    if fileIn then
      local fileOut, errr = io.open(toFile, 'w')
      if fileOut then
        local content = fileIn:read(4096)
        while content do
          fileOut:write(content)
          content = fileIn:read(4096)
        end
        result = true
        fileIn:close()
        fileOut:close()
      else
        log.msg(log.error, errr)
      end
    else
      log.msg(log.error, err)
    end
  end
  return result
end

--[[
  NAME
    file_move - move a file from one directory to another

  SYNOPSIS
     local df = require "lib/dtutils.file"

    local result = df.file_move(fromFile, toFile)
      fromFile - string - name of the original file
      toFile - string - the new file location and name

  DESCRIPTION
    Move a file from one place to another.  Try a succession of methods from
    builtin to operating system to a pure lua solution.

  RETURN VALUE
    result - boolean - nil on error, some value on success

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[file_move - move a file from one directory to another]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.file_move(fromFile, toFile)
      fromFile - string - name of the original file
      toFile - string - the new file location and name]],
  Description = [[Move a file from one place to another.  Try a succession of methods from
    builtin to operating system to a pure lua solution.]],
  Return_Value = [[result - boolean - nil on error, some value on success]],
}

function dtutils_file.file_move(fromFile, toFile)
  local success = os.rename(fromFile, toFile)
  if not success then
    -- an error occurred, so let's try using the operating system function
    if dtutils_file.check_if_bin_exists("mv") then
      success = os.execute("mv '" .. fromFile .. "' '" .. toFile .. "'")
    end
    -- if the mv didn't exist or succeed, then...
    if not success then
      -- pure lua solution
      success = dtutils_file.file_copy(fromFile, toFile)
      if success then
        os.remove(fromFile)
      else
        log.msg(log.error, "Unable to move " .. fromFile .. " to " .. toFile .. ".  Leaving " .. fromFile .. " in place.")
      end
    end
  end
  return success  -- nil on error, some value if success
end

--[[
  NAME
    filename_increment - add a two digit increment to a filename

  SYNOPSIS
    local df = require "lib/dtutils.file"

    local result = df.filename_increment(filepath)
      filepath - string - filename to increment

  DESCRIPTION
    filename_increment solves the problem of filename confllict by adding an 
    increment to the filename.  If the supplied filename has no increment then 
    "01" is added to the basename.  If the filename already has an increment, then
    1 is added to it and the filename returned.

  RETURN VALUE
    result - string - the incremented filename

]]

dtutils_file.libdoc.functions[#dtutils_file.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[filename_increment - add a two digit increment to a filename]],
  Synopsis = [[local df = require "lib/dtutils.file"

    local result = df.filename_increment(filepath)
      filepath - string - filename to increment]],
  Description = [[filename_increment solves the problem of filename confllict by adding an 
    increment to the filename.  If the supplied filename has no increment then 
    "01" is added to the basename.  If the filename already has an increment, then
    1 is added to it and the filename returned.]],
  Return_Value = [[result - string - the incremented filename]],
}

function dtutils_file.filename_increment(filepath)

  -- break up the filepath into parts
  local path = dtutils_file.get_path(filepath)
  local basename = dtutils_file.get_basename(filepath)
  local filetype = dtutils_file.get_filetype(filepath)

  -- check to see if we've incremented before
  local increment = string.match(basename, "_(%d-)$")

  if increment then
    -- we do 2 digit increments so make sure we didn't grab part of the filename
    if string.len(increment) > 2 then
      -- we got the filename so set the increment to 01
      increment = "01"
    else
      increment = string.format("%02d", tonumber(increment) + 1)
      basename = string.gsub(basename, "_(%d-)$", "")
    end
  else
    increment = "01"
  end
  local incremented_filepath = path .. basename .. "_" .. increment .. "." .. filetype

  return incremented_filepath
end

return dtutils_file
