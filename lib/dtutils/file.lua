local dtutils_file = {}
local dt = require "darktable"

local log = require "lib/dtutils.log"

dtutils_file.libdoc = {
  Name = [[dtutils.file]],
  Synopsis = [[common darktable lua file functions]],
  Usage = [[local df = require "lib/dtutils.file"]],
  Description = [[[dtutils.file provides common file manipulation functions used in
  constructing Darktable lua scripts]],
  Return_Value = [[df - library - the file functions]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = log.libdoc.License,
  Copyright = [[Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.]],
  Copyright = [[Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.
    Copyright (C) 2016 Tobias Jakobs]],
  functions = {}
}

local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0},{4,0,0},{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("dtutils.file",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("dtutils.file", msgid)
end

dtutils_file.libdoc.functions["check_if_bin_exists"] = {
  Name = [[check_if_bin_exists]],
  Synopsis = [[check if an executable is in the path]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.check_if_bin_exists(bin)
      bin - string - the binary to check for]],
  Description = [[check_if_bin_exists checks to see if the specified binary executable is
    in the path.]],
  Return_Value = [[result - boolean - true if the executable was found, false if not]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.check_if_bin_exists(bin)
  local result = os.execute("which " .. bin)
  if not result then
    result = false
  end
  return result
end

dtutils_file.libdoc.functions["split_filepath"] = {
  Name = [[split_filepath]],
  Synopsis = [[split a filepath into parts]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.split_filepath(filepath)
      filepath - string - path and filename]],
  Description = [[split_filepath splits a filepath into the path, filename, basename and filetype and puts
    that in a table]],
  Return_Value = [[result - table - a table containing the path, filename, basename, and filetype]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.split_filepath(str)
  -- strip out single quotes from quoted pathnames
  str = string.gsub(str, "'", "")
  local result = {}
  -- Thank you Tobias Jakobs for the awesome regular expression, which I tweaked a little
  result["path"], result["filename"], result["basename"], result["filetype"] = string.match(str, "(.-)(([^\\/]-)%.?([^%.\\/]*))$")
  return result
end

dtutils_file.libdoc.functions["get_path"] = {
  Name = [[get_path]],
  Synopsis = [[get the path from a file path]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.get_path(filepath)
      filepath - string - path and filename]],
  Description = [[get_path strips the filename and filetype from a path and returns the path]],
  Return_Value = [[result - string - the path]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.get_path(str)
  local parts = dtutils_file.split_filepath(str)
  return parts["path"]
end

dtutils_file.libdoc.functions["get_filename"] = {
  Name = [[get_filename]],
  Synopsis = [[get the filename and extension from a file path]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.get_filename(filepath)
      filepath - string - path and filename]],
  Description = [[get_filename strips the path from a filepath and returns the filename]],
  Return_Value = [[result - string - the file name and type]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.get_filename(str)
  local parts = dtutils_file.split_filepath(str)
  return parts["filename"]
end

dtutils_file.libdoc.functions["get_basename"] = {
  Name = [[get_basename]],
  Synopsis = [[get the filename without the path or extension]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.get_basename(filepath)
      filepath - string - path and filename]],
  Description = [[get_basename returns the name of the file without the path or filetype
]],
  Return_Value = [[result - string - the basename of the file]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.get_basename(str)
  local parts = dtutils_file.split_filepath(str)
  return parts["basename"]
end

dtutils_file.libdoc.functions["get_filetype"] = {
  Name = [[get_filetype]],
  Synopsis = [[get the filetype from a filename]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.get_filetype(filepath)
      filepath - string - path and filename]],
  Description = [[get_filetype returns the filetype from the supplied filepath]],
  Return_Value = [[result - string - the filetype]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.get_filetype(str)
  local parts = dtutils_file.split_filepath(str)
  return parts["filetype"]
end


-- Thanks Tobias Jakobs for the idea
dtutils_file.libdoc.functions["check_if_file_exists"] = {
  Name = [[check_if_file_exists]],
  Synopsis = [[check if a file or path exist]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.check_if_file_exists(filepath)
      filepath - string - a file or path to check]],
  Description = [[check_if_file_exists checks to see if a file or path exists]],
  Return_Value = [[result - boolean - true if the file or path exists, false if it doesn't]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.check_if_file_exists(filepath)
  local result = os.execute("test -e " .. filepath)
  if not result then
    result = false
  end
  return result
end

dtutils_file.libdoc.functions["chop_filetype"] = {
  Name = [[chop_filetype]],
  Synopsis = [[remove a filetype from a filename]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.chop_filetype(path)
      path - string - a filename with or without a path]],
  Description = [[chop_filetype removes the filetype from the filename]],
  Return_Value = [[result - string - the path and filename without the filetype]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.chop_filetype(path)
  local length = dtutils_file.get_filetype(path):len() + 2
  return string.sub(path, 1, -length)
end

dtutils_file.libdoc.functions["file_copy"] = {
  Name = [[file_copy]],
  Synopsis = [[copy a file to another name/location]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.file_copy(fromFile, toFile)
      fromFile - string - name of file to copy from
      toFile - string - name of file to copy to]],
  Description = [[copy a file using a succession of methods from operating system
    to a pure lua solution]],
  Return_Value = [[result - boolean - nil on error, true on success]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
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

dtutils_file.libdoc.functions["file_move"] = {
  Name = [[file_move]],
  Synopsis = [[move a file from one directory to another]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.file_move(fromFile, toFile)
      fromFile - string - name of the original file
      toFile - string - the new file location and name]],
  Description = [[Move a file from one place to another.  Try a succession of methods from
    builtin to operating system to a pure lua solution.]],
  Return_Value = [[result - boolean - nil on error, some value on success]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
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

dtutils_file.libdoc.functions["filename_increment"] = {
  Name = [[filename_increment]],
  Synopsis = [[add a two digit increment to a filename]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.filename_increment(filepath)
      filepath - string - filename to increment]],
  Description = [[filename_increment solves the problem of filename confllict by adding an 
    increment to the filename.  If the supplied filename has no increment then 
    "01" is added to the basename.  If the filename already has an increment, then
    1 is added to it and the filename returned.]],
  Return_Value = [[result - string - the incremented filename]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
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


dtutils_file.libdoc.functions["create_unique_filename"] = {
  Name = [[create_unique_filename]],
  Synopsis = [[create a unique filename from the supplied argment]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.create_unique_filename(filepath)
      filepath - string - the path and filename requested]],
  Description = [[create_unique_filename takes a requested filepath and checks to see if
  it exists.  If if doesn't then it's returned intact.  If it already exists, then a two
  digit increment is added to the filename and it is tested again.  The increment keeps 
  increasing until either a unique filename is found or there have been 100 attempts.]],
  Return_Value = [[result - string - the incremented filename]],
  Limitations = [[create_unique_filename will only attempt 100 increments.]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.create_unique_filename(filepath)
  while dtutils_file.check_if_file_exists(filepath) do
    filepath = dtutils_file.filename_increment(filepath)
    -- limit to 99 more exports of the original export
    if string.match(dtfileutils.get_basename(filepath), "_(d-)$") == "99" then 
      break 
    end
  end
  return filepath
end

return dtutils_file
