local dtutils_file = {}
local dt = require "darktable"
local du = require "lib/dtutils"
local ds = require "lib/dtutils.string"
local dsys = require "lib/dtutils.system"

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

local gettext = dt.gettext.gettext

du.check_min_api_version("5.0.0", "dtutils.file")

local function _(msgid)
    return gettext(msgid)
end

--[[
    local function to run a test command on windows and return a true if it succeeds
    instead of returning true if it runs
]]

local function _win_os_execute(cmd)
  local result = nil
  local p = io.popen(cmd)
  local output = p:read("*a")
  p:close()
  if string.match(output, "true") then 
    result = true
  else
    result = false
  end
  return result
end

--[[
  local function to determine if a path name is a windows executable
]]

local function _is_windows_executable(path)
  local result = false
  if dtutils_file.test_file(path, "f") then
    if string.match(path, ".exe$") or string.match(path, ".EXE$") or
       string.match(path, ".com$") or string.match(path, ".COM$") or
       string.match(path, ".bat$") or string.match(path, ".BAT$") or
       string.match(path, ".cmd$") or string.match(path, ".CMD$") then
        result = true
    end
  end
  return result
end

dtutils_file.libdoc.functions["test_file"] = {
  Name = [[test_file]],
  Synopsis = [[test a file to see what it is]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.test_file(path, test)
      path - string - the path to check
      test - one of d, e, f, x where
        d - directory
        e - exists
        f - file
        x - executable]],
  Description = [[test_file checks a path to see if it is a directory]],
  Return_Value = [[result - boolean - true if path is a directory, nil if not]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.test_file(path, test)
  local cmd = "test -"
  local engine = os.execute
  local cmdstring = ""

  if dt.configuration.running_os == "windows" then
    cmd = "if exist "
    engine = _win_os_execute
  end

  if test == "d" then
    -- test if directory
    if dt.configuration.running_os == "windows" then
      cmdstring = cmd .. dtutils_file.sanitize_filename(path .. "\\*")  .. " echo true"
    else
      cmdstring = cmd .. test .. " " .. dtutils_file.sanitize_filename(path)
    end
  elseif test == "e" then
    -- test exists
    if dt.configuration.running_os == "windows" then
      cmdstring = cmd .. dtutils_file.sanitize_filename(path)  .. " echo true"
    else
      cmdstring = cmd .. test .. " " .. dtutils_file.sanitize_filename(path)
    end
  elseif test == "f" then
    -- test if file
    if dt.configuration.running_os == "windows" then
      if not dtutils_file.test_file(path, "d") then -- make sure it's not a directory
        cmdstring = cmd .. dtutils_file.sanitize_filename(path)  .. " echo true"
      else
        return false
      end
    else
      cmdstring = cmd .. test .. " " .. dtutils_file.sanitize_filename(path)
    end
  elseif test == "x" then
    -- test executable
    if dt.configuration.running_os == "windows" then
      return _is_windows_executable(path)
    else
      cmdstring = cmd .. test .. " " .. dtutils_file.sanitize_filename(path)
    end
  else
    dt.print_error("[test_file] unknown test " .. test)
    return false
  end

  return engine(cmdstring)
end

--[[
  local function to return a case insensitive pattern for matching 
  i.e. gimp becomes [Gg][Ii][Mm][Pp] which  should match any capitalization
  of gimp.
]]

local function _case_insensitive_pattern(pattern)
  return pattern:gsub("(.)", function(letter)
    return string.format("[%s$s]", letter:lower(), letter:upper())
  end)
end

--[[
  local function to search windows for an executable
]]

local function _search_for_bin_windows(bin)
  local result = false
  -- use where on path
  -- use where on program files 
  -- use where on program files (x86)
  local args = {"", '/R "C:\\Program Files"', '/R "C:\\Program Files (x86)"'}

  for _,arg in ipairs(args) do
    local cmd = "where " .. arg .. " " .. ds.sanitize(bin)
    local p = io.popen(cmd)
    local output = p:read("*a")
    p:close()
    local lines = du.split(output, "\n")
    local cibin = _case_insensitive_pattern(bin)
    for _,line in ipairs(lines) do
      if string.match(line, cibin) then
        dt.print_log("found win search match " .. line)
        if dtutils_file.test_file(line, "f") and dtutils_file.test_file(line, "x") then
          dtutils_file.set_executable_path_preference(bin, line)  -- save it so we don't have to search again
          return line
        end
      end
    end
  end
  return result
end

--[[
  local function to search *nix systems for an executable
]]

local function _search_for_bin_nix(bin)
  local result = false
  local p = io.popen("command -v " .. bin)
  local output = p:read("*a")
  p:close()
  if string.len(output) > 0 then
    local spath = dtutils_file.sanitize_filename(output:sub(1, -2))
    if dtutils_file.test_file(spath, "f") and dtutils_file.test_file(spath, "x") then
      dtutils_file.set_executable_path_preference(bin, spath)
      result = spath 
    end
  end
  return result
end

--[[
  local function to search macos systems for an executable
]]

local function _search_for_bin_macos(bin)
  local result = false
  
  result = _search_for_bin_nix(bin) -- see if it's in the path

  if not result then
    local search_start = "/Applications"

    if dtutils_file.check_if_file_exists("/Applications/" .. bin .. ".app") then
      search_start = "/Applications/" .. bin .. ".app"
    end

    local p = io.popen("find " .. search_start .. " -type f -name " .. bin .. " -print")
    local output = p:read("*a")
    p:close()
    local lines = du.split(output, "\n")

    for _,line in ipairs(lines) do
      local spath = dtutils_file.sanitize_filename(line:sub(1, -1))
      if dtutils_file.test_file(spath, "x") then
        dtutils_file.set_executable_path_preference(bin, spath) -- save it so we don't have to search again
        result = spath
      end
    end
  end

  return result
end

--[[
  local function to provide a generic search call that can be 
  split into operating system specific calls
]]

local function _search_for_bin(bin)
  local result = false

  if dt.configuration.running_os == "windows" then
    result = _search_for_bin_windows(bin)
    if result then
      result = dtutils_file.sanitize_filename(result)
    end
  elseif dt.configuration.running_os == "macos" then
    result = _search_for_bin_macos(bin)
  else
    result = _search_for_bin_nix(bin)
  end

  return result
end

--[[
  local function to check if an executable path is
  a windows executable on linux or macos, thus requiring wine to run
]]

local function _check_path_for_wine_bin(path)
  local result = false

  if string.len(path) > 0 then
    -- check for windows executable to run under wine
    if _is_windows_executable(path) then
      if dtutils_file.check_if_file_exists(path) then
        result = "wine " .. dtutils_file.sanitize_filename(path)
      end
    end
  end
  return result
end

--[[
  local function to check if an executable path is
  a valid executable.  Some generic checks are done before
  system specific checks are done.
]]

local function _check_path_for_bin(bin)
  local result = false
  local path = nil

  local PS = dt.configuration.running_os == "windows" and "\\" or "/"

  if string.match(bin, PS) then 
    path = bin
  else
    path = dtutils_file.get_executable_path_preference(bin)
    -- reset path preference is the returned preference is a directory
    if dtutils_file.test_file(path, "d") then
      dtutils_file.set_executable_path_preference(bin, "")
      path = nil
    end
  end

  if path and dtutils_file.test_file(path, "d") then
    path = nil
  end

  if path and dt.configuration.running_os ~= "windows" then
    result = _check_path_for_wine_bin(path)
  end

  if path and not result then
    if dtutils_file.test_file(path, "x") then
      result = dtutils_file.sanitize_filename(path)
    end
  end

  return result
end

--[[
  local function to the old check_if_bin_exists functionality
  on windows in order to decrease the amount of windows being
  created and destroyed by system calls.
]]

local function _old_check_if_bin_exists(bin)  -- only run on windows if preference checked
  local result = false
  local path = nil

  if string.match(bin, "\\") then

    path = bin
  else
    path = dtutils_file.get_executable_path_preference(bin)
  end

  if string.len(path) > 0 then
    if dtutils_file.check_if_file_exists(path) then
      if (string.match(path, ".exe$") or string.match(path, ".EXE$")) then
        result = dtutils_file.sanitize_filename(path)
      end
    end
  end
  return result
end

dtutils_file.libdoc.functions["check_if_bin_exists"] = {
  Name = [[check_if_bin_exists]],
  Synopsis = [[check if an executable exists]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.check_if_bin_exists(bin)
      bin - string - the binary to check for]],
  Description = [[check_if_bin_exists checks to see if the specified binary exists.
    check_if_bin_exists first checks to see if a preference for the binary has been
    registered and uses that if found, after it's verified to be an executable and 
    exist.  If no preference exissts, the user's path is checked for the executable.
    If the executable is not found in the users path, then a search of the operating
    system is conducted to see if the executable can be found.

    If an executalble is found, it's verified to exist and be an executable.  Once 
    the executable is verified, the path is saved as a preference to speed up 
    subsequent checks.  The executable path is sanitized and returned.

    If no executable is found, false is returned.]],
  Return_Value = [[result - string - the sanitized path of the binary, false if not found]],
  Limitations = [[If more than one executable that satisfies the search results is found, the 
    wrong one may be returned.  If the wrong value is returned, the user can still specify the
    correct execuable using tools/executable_manager.  Most packages are well behaved with the
    notiable exception being GIMP on windows.  Depending on the packager there are multiple 
    gimp executables, often with version numbers.  In this case, the user needs to specify
    the location of the correct executable using executable_manager.]],
  Example = [[]],
  See_Also = [[executable_manager]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.check_if_bin_exists(bin)
  local result = false

  if dt.configuration.running_os == "windows" and dt.preferences.read("dtutils.file", "use_old_check_if_bin_exists", "bool") then
    result = _old_check_if_bin_exists(bin)
  else

    result = _check_path_for_bin(bin)

    if not result then
      result = _search_for_bin(bin)
    end
  end
  return result
end

-- the following path, filename, etc functions have
-- moved to the string library since they are string
-- manipulation functions, and to prevent circular
-- library inclusiion.

-- these functions are left here for compatibility
-- with older scripts

function dtutils_file.split_filepath(str)
  return ds.split_filepath(str)
end

function dtutils_file.get_path(str)
  return ds.get_path(str)
end

function dtutils_file.get_filename(str)
  return ds.get_filename(str)
end

function dtutils_file.get_basename(str)
  return ds.get_basename(str)
end

function dtutils_file.get_filetype(str)
  return ds.get_filetype(str)
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
  local result = false
  if (dt.configuration.running_os == 'windows') then
    filepath = string.gsub(filepath, '[\\/]+', '\\')
    local p = io.popen("if exist " .. dtutils_file.sanitize_filename(filepath) .. " (echo 'yes') else (echo 'no')")
    local ans = p:read("*all")
    p:close()
    if string.match(ans, "yes") then
      result = true
    end
--    result = os.execute('if exist "'..filepath..'" (cmd /c exit 0) else (cmd /c exit 1)')
--    if not result then
--     result = false
--    end
  elseif (dt.configuration.running_os == "linux") then
    result = os.execute('test -e ' .. dtutils_file.sanitize_filename(filepath))
    if not result then
      result = false
    end
  else
    local file = io.open(filepath, "r")
    if file then
      result = true
      file:close()
    else
      result = false
    end
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
  if length > 2 then
    return string.sub(path, 1, -length)
  else
    return path
  end
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
  if dt.configuration.running_os == "windows" then
    result = os.execute('copy ' .. dtutils_file.sanitize_filename(fromFile) .. ' ' .. dtutils_file.sanitize_filename(toFile))
  elseif dtutils_file.check_if_bin_exists("cp") then
    result = os.execute("cp " .. dtutils_file.sanitize_filename(fromFile) .. ' ' .. dtutils_file.sanitize_filename(toFile))
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
      success = os.execute("mv " .. dtutils_file.sanitize_filename(fromFile) .. ' ' .. dtutils_file.sanitize_filename(toFile))
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
  Limitations = [[The filename will be incremented to 99]],
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
    elseif increment == "99" then
      dt.print_error("not incrementing, filename has already been incremented 99 times.")
      return filepath
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
    local increment = string.match(dtutils_file.get_basename(filepath), "_(%d-)$")
    if increment == "99" then
      break
    end
  end
  return filepath
end


dtutils_file.libdoc.functions["set_executable_path_preference"] = {
  Name = [[set_executable_path_preference]],
  Synopsis = [[set a preference for the path to an executable]],
  Usage = [[local df = require "lib/dtutils.file"

    df.set_executable_path_preference(executable, path)
      executable - string - the name of the executable to set the path for
      path - string - the path to the binary]],
  Description = [[set_executable_path_preference takes an executable name and path to the
  executable and registers the preference for later use.]],
  Return_Value = [[]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.set_executable_path_preference(executable, path)
  dt.preferences.write("executable_paths", executable, "string", path)
end


dtutils_file.libdoc.functions["get_executable_path_preference"] = {
  Name = [[get_executable_path_preference]],
  Synopsis = [[return the path to an executable from a preference]],
  Usage = [[local df = require "lib/dtutils.file"

    local result = df.get_executable_path_preference(executable)
      executable - string - the name of the executable to get the path for]],
  Description = [[get_executable_path_preference returns the path preference to
    the requested executable.]],
  Return_Value = [[result - string - path to the executable]],
  Limitations = [[executable should be the basename of the executable without extensions]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.get_executable_path_preference(executable)
  return dt.preferences.read("executable_paths", executable, "string")
end


dtutils_file.libdoc.functions["executable_path_widget"] = {
  Name = [[executable_path_widget]],
  Synopsis = [[create a widget to get executable path preferences]],
  Usage = [[local df = require "lib/dtutils.file"

    local widget = df.executable_path_widget(executables)
      executables - table - a table of strings that are executable names]],
  Description = [[executable_path_widget takes a table of executable names
    and builds a set of file selector widgets to get the path to the executable.
    The resulting widgets are wrapped in a box widget and returned.]],
  Return_Value = [[widget - widget - a widget containing a file selector widget for
    each executable.]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.executable_path_widget(executables)
  local box_widgets = {}
  table.insert(box_widgets, dt.new_widget("section_label"){label = "select executable(s)"})
  for _, executable in pairs(executables) do
    table.insert(box_widgets, dt.new_widget("label"){label = "select " .. executable .. " executable"})
    local path = dtutils_file.get_executable_path_preference(executable)
    if not path then
      path = ""
    end
    table.insert(box_widgets, dt.new_widget("file_chooser_button"){
      title = "select " .. executable .. " executable",
      value = path,
      is_directory = false,
      changed_callback = function(self)
        if dtutils_file.check_if_bin_exists(self.value) then
          dtutils_file.set_executable_path_preference(executable, self.value)
        end
      end
    }
  )
  end
  local box = dt.new_widget("box"){
    orientation = "vertical",
    table.unpack(box_widgets)
  }
  return box
end

dtutils_file.libdoc.functions["sanitize_filename"] = {
  Name = [[sanitize_filename]],
  Synopsis = [[make a filename safe to pass as an argument]],
  Usage = [[local df = require "lib/dtutils.file"

    local sanitized_filename = df.sanitize_filename(filename)
      filename - string - a filepath and filename]],
  Description = [[sanitize_file places quotes around the filename in an
    operating system specific manner.  The result is safe to pass as
    an argument to the operating system.]],
  Return_Value = [[sanitized_filename - string - quoted filename]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.sanitize_filename(filename)
  return ds.sanitize(filename)
end

dtutils_file.libdoc.functions["mkdir"] = {
  Name = [[mkdir]],
  Synopsis = [[create the directory(ies) if they do not already exists]],
  Usage = [[local df = require "lib/dtutils.file"

     df.mkdir(path)
      path - string - a directory path]],
  Description = [[mkdir creates directories if not already exists. It
    create whole parents subtree if needed
  ]],
  Return_Value = [[path - string - a directory path]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.mkdir(path)
  if not dtutils_file.check_if_file_exists(path) then
    local mkdir_cmd = dt.configuration.running_os == "windows" and "mkdir" or "mkdir -p"
    return dsys.external_command(mkdir_cmd.." "..dtutils_file.sanitize_filename(path))
  else
    return 0
  end
end

dtutils_file.libdoc.functions["rmdir"] = {
  Name = [[rmdir]],
  Synopsis = [[recursively remove a directory]],
  Usage = [[local df = require "lib/dtutils.file"

     df.rmdir(path)
      path - string - a directory path]],
  Description = [[rm allow to recursively remove directories]],
  Return_Value = [[path - string - a directory path]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.rmdir(path)
  local rm_cmd = dt.configuration.running_os == "windows" and "rmdir /S /Q" or "rm -r"
  return dsys.external_command(rm_cmd.." "..dtutils_file.sanitize_filename(path))
end

dtutils_file.libdoc.functions["create_tmp_file"] = {
  Name = [[create_tmp_file]],
  Synopsis = [[creates a temporary file]],
  Usage = [[local df = require "lib/dtutils.file

    local result = df.create_tmp_file()]],
  Description = [[create_tmp_file can be used to create temporary files]],
  Return_Value = [[result - string - path to the created temporary file.]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_file.create_tmp_file()
  local tmp_file = os.tmpname()

  local f = io.open(tmp_file, "w")
  if not f then
      log.msg(log.error, string.format("Error writing to `%s`", tmp_file))
      os.remove(tmp_file)
      return nil
  end

  return tmp_file
end

--[[
  The new check_if_bin_exists() does multiple calls to the operating system to check
  if the file exists and is an executable.  On windows, each call to the operating system
  causes a window to open in order to run the command, then the window closes when the 
  command exits.  If the user gets annoyed by the "flickering windows", then they can
  enable this preference to use the old check_if_bin_exists() that relys on the 
  executable path preferences and doesn't do as many checks.
]]

if dt.configuration.running_os == "windows" then
  dt.preferences.register("dtutils.file", "use_old_check_if_bin_exists", "bool",
    "lua scripts use old check_if_bin_exists()",
    "lessen flickering windows effect when scripts run",
    false)
end


return dtutils_file

