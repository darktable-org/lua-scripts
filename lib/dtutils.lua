--[[

    dtutils.lua - common darktable lua functions

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

dtutils = {}

local dt = require "darktable"

local log = require "lib/libLog"

local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("dtutils",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("dtutils", msgid)
end

--[[
  NAME
    dutils.split_filepath - split a filepath into parts

  SYNOPSIS
    result = dtutils.split_filepath(path_string)
      filepath - path and filename

  DESCRIPTION
    split_filepath splits a filepath into the path, filename, basename and filetype and puts
    that in a table

  RETURN VALUE
    result - a table containing the path, filename, basename, and filetype

  ERRORS



]]

function dtutils.split_filepath(str)
  local result = {}
  -- Thank you Tobias Jakobs for the awesome regular expression, which I tweaked a little
  result["path"], result["filename"], result["basename"], result["filetype"] = string.match(str, "(.-)(([^\\/]-)%.?([^%.\\/]*))$")
  return result
end

--[[
  NAME
    dutils.get_path - get the path from a file path

  SYNOPSIS
    result = dtutils.get_path(filepath)
      filepath - path and filename

  DESCRIPTION
    get_path strips the filename and filetype from a path and returns the path

  RETURN VALUE
    result - the path

  ERRORS


  
]]

function dtutils.get_path(str)
  local parts = dtutils.split_filepath(str)
  return parts["path"]
end

--[[
  NAME
    dutils.get_filename - get the filename and extension from a file path

  SYNOPSIS
    result = dtutils.get_filename(filepath)
      filepath - path and filename

  DESCRIPTION
    get_filename strips the path from a filepath and returns the filename

  RETURN VALUE
    result - the file name and type

  ERRORS


  
]]

function dtutils.get_filename(str)
  local parts = dtutils.split_filepath(str)
  return parts["filename"]
end

--[[
  NAME
    dutils.get_basename - get the filename without the path or extension

  SYNOPSIS
    result = dtutils.get_basename(filepath)
      filepath - path and filename

  DESCRIPTION
    get_basename returns the name of the file without the path or filetype

  RETURN VALUE
    result - the basename of the file

  ERRORS


  
]]

function dtutils.get_basename(str)
  local parts = dtutils.split_filepath(str)
  return parts["basename"]
end

--[[
  NAME
    dutils.get_filetype - get the filetype from a filename

  SYNOPSIS
    result = dtutils.get_filetype(filepath)
      filepath - path and filename

  DESCRIPTION
    get_filetype returns the filetype from the supplied filepath

  RETURN VALUE
    result - the filetype

  ERRORS


  
]]

function dtutils.get_filetype(str)
  local parts = dtutils.split_filepath(str)
  return parts["filetype"]
end

--[[
  NAME
    dutils.checkIfBinExists - check if an executable is in the path

  SYNOPSIS
    result = dtutils.checkIfBinExists(bin)
      bin - the binary to check for

  DESCRIPTION
    checkIfBinExists checks to see if the specified binary executable is
    in the path.

  RETURN VALUE
    result - true if the executable was found, false if not

  ERRORS


  
]]

function dtutils.checkIfBinExists(bin)
  local handle = io.popen("which "..bin)
  local result = handle:read()
  local ret
  handle:close()
  if (result) then
    dt.print_error("true checkIfBinExists: "..bin)
    ret = true
  else
    dt.print_error(bin.." not found")
    ret = false
  end
  return ret
end

--[[
  NAME
    dutils.checkIfFileExists - check if a file or path exist

  SYNOPSIS
    result = dtutils.checkIfFileExists(filepath)
      filepath - a file or path to check

  DESCRIPTION
    checkIfFileExists checks to see if a file or path exists

  RETURN VALUE
    result - true if the file or path exists, false if it doesn't

  ERRORS


  
]]

-- Thanks Tobias Jakobs for the idea and the correction
function dtutils.checkIfFileExists(filepath)
  local file = io.open(filepath,"r")
  local ret
  if file ~= nil then 
    io.close(file) 
    dt.print_error("true checkIfFileExists: "..filepath)
    ret = true
  else 
    dt.print_error(filepath.." not found")
    ret = false
  end
  return ret
end

--[[
  NAME
    dutils.filename_increment - add a two digit increment to a filename

  SYNOPSIS
    result = dtutils.filename_increment(filepath)
      filepath - file to increment

  DESCRIPTION
    filename_increment solves the problem of filename confllict by adding an 
    increment to the filename.  If the supplied filename has no increment then 
    "01" is added to the basename.  If the filename already has an increment, then
    1 is added to it and the filename returned.

  RETURN VALUE
    result - the incremented filename

  ERRORS


  
]]

function dtutils.filename_increment(filepath)

  -- break up the filepath into parts
  local path = dtutils.get_path(filepath)
  local basename = dtutils.get_basename(filepath)
  local filetype = dtutils.get_filetype(filepath)

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

  dt.print_error("original file was " .. filepath)
  dt.print_error("incremented file is " .. incremented_filepath)

  return incremented_filepath
end

--[[
  NAME
    dutils.groupIfNotMember - group a new file with an existing one

  SYNOPSIS
    result = dtutils.groupIfNotMember(image, new_image)
      image - an existing image in the darktable database
      new_image - the new image to group with the existing image

  DESCRIPTION
    groupIfNotMember checks a file to see if it's a member of the group
    with an existing image.  If not, then the group leader of the existing 
    image is found and the new image is grouped with it.

  RETURN VALUE
    none

  ERRORS


  
]]

function dtutils.groupIfNotMember(img, new_img)
  local image_table = img:get_group_members()
  local is_member = false
  for _,image in ipairs(image_table) do
    dt.print_error(image.filename .. " is a member")
    if image.filename == new_img.filename then
      is_member = true
      dt.print_error("Already in group")
    end
  end
  if not is_member then
    dt.print_error("group leader is "..img.group_leader.filename)
    new_img:group_with(img.group_leader)
    dt.print_error("Added to group")
  end
end

--[[
  NAME
    dutils.sanitize_filename - take care of spaces in filenames

  SYNOPSIS
    result = dtutils.sanitize_filename(filepath)
      filepath - an optional path and filename with spaces

  DESCRIPTION
    sanitize_filename escapes spaces in filenames so that the can be passed as arguments

  RETURN VALUE
    result - sanitized filename

  ERRORS
    Only spaces in filenames are sanitized, but not in the path

  
]]

function dtutils.sanitize_filename(filepath)
  local path = dtutils.get_path(filepath)
  local basename = dtutils.get_basename(filepath)
  local filetype = dtutils.get_filetype(filepath)

  local sanitized = string.gsub(basename, " ", "\\ ")

  return path .. sanitized .. "." .. filetype
end

--[[
  NAME
    dutils.show_status - show the status while exporting images

  SYNOPSIS
    result = dtutils.show_status(storage, image, format, filename, number, total, high_quality, extra_data)
      storage - the storage that the status is being shown for
      image - the current image
      format - the format of the export image
      filename - the filename being exported to
      number - the number of this image in the sequence
      total - the total number of images being exported
      high_quality - boolean
      extra_data - extra data from the storage

  DESCRIPTION
    show_status runs prior to each image being exported and prints out a status

  RETURN VALUE
    none

  ERRORS


  
]]

function dtutils.show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
end

--[[
  NAME
    dutils.extract_image_list - assemble the exported image filenames from an image_table into a string

  SYNOPSIS
    result = dtutils.extract_image_list(image_table)
      image_table - a table of images such as supplied by the exporter or by libPlugin.build_image_table

  DESCRIPTION
    extract_image_list concatenates the exported image names into a space separated string suitable for
    passing as an argument to a processor

  RETURN VALUE
    result - the assembled image list on success, or an empty image list on error

  ERRORS


  
]]

function dtutils.extract_image_list(image_table)
  local img_list = ""
  for _,exp_img in pairs(image_table) do
    img_list = img_list .. " " .. exp_img
  end
  return img_list
end

--[[
  NAME
    dutils.extract_collection_path - extract the collection path from an image table

  SYNOPSIS
    result = dtutils.extract_collection_path(image_table)
      image_table - a table of images such as supplied by the exporter or by libPlugin.build_image_table

  DESCRIPTION
    extract_collection_path looks at the first image in the image_table and returns the path

  RETURN VALUE
    result - the collection path on success, or nil if there was an error

  CAVEATS
    The collection path is determined from the first image.  If the table consists of images from different
    collections, then only the first collection is used.

  ERRORS


  
]]

function dtutils.extract_collection_path(image_table)
  collection_path = nil
  for i,_ in pairs(image_table) do
    collection_path = i.path
    break
  end
  return collection_path
end

--[[
  NAME
    dutils.split - split a string on a specified separator

  SYNOPSIS
    result = dtutils.split(str, pat)

  DESCRIPTION
    split separates a string into a table of strings.  The strings are separated at each
    occurrence of the supplied pattern.

  RETURN VALUE
    result - a table of strings on success, or an empty table on error

  ERRORS


  
]]

-- Thanks to http://lua-users.org/wiki/SplitJoin
function dtutils.split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
        table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

--[[
  NAME
    dutils.join - join a table of strings with a specified separator

  SYNOPSIS
    result = dtutils.join(tabl, pat)
      tabl - a table of strings
      pat - a separator

  DESCRIPTION
    join assembles a table of strings into a string with the specified pattern 
    in between each string

  RETURN VALUE
    result - the joined string on success, or an empty string on failure

  ERRORS


  
]]

-- Thanks to http://lua-users.org/wiki/SplitJoin
function dtutils.join(tabl, pat)
  returnstr = ""
  for i,str in pairs(tabl) do
    returnstr = returnstr .. str .. pat
  end
  return string.sub(returnstr, 1, -(pat:len() + 1))
end

--[[
  NAME
    dutils.makeOutputFileName- make an output filename from an image list

  SYNOPSIS
    result = dtutils.makeOutputFileName(img_list)
      img_list - a space separated list of filenames

  DESCRIPTION
    makeOutputFileName takes a string of filenames, breaks them apart, then
    combines them in a way that makes some sense.  This is useful in routines
    that do panoramas, hdr, or focus stacks.  The returned filename is a representation
    of the files used to construct the image.  If there are 3 or fewer images, then the file
    basenames are concatenated with a separator. If there is more than 3 images, the first and 
    last file basenames are concatenated with a separator.

  RETURN VALUE
    result - the constructed filename on success, nil on error

  ERRORS


  
]]

function dtutils.makeOutputFileName(img_list)
  local images = {}
  local cnt = 1
  local max_distinct_names = 3
  local name_separator = "-"
  local outputFileName = nil
  log.msg(log.debug, "img_list is ", img_list)

  local result = dtutils.split(img_list, " ")
  table.sort(result)
  for _,img in pairs(result) do
    images[cnt] = dtutils.get_basename(img)
    cnt = cnt + 1
  end

  cnt = cnt - 1

  if cnt > 1 then
    if cnt > max_distinct_names then
      -- take the first and last
      outputFileName = images[1] .. name_separator .. images[cnt]
    else
      -- join them
      outputFileName = dtutils.join(images, name_separator)
    end
  else
    -- return the single name
    outputFileName = images[cnt]
  end

  return outputFileName
end

--[[
  NAME
    dutils.chop_filetype - remove a filetype from a filename

  SYNOPSIS
    result = dtutils.chop_filetype(path)
      path - a filename with or without a path

  DESCRIPTION
    chop_filetype removes the filetype from the filename

  RETURN VALUE
    result - the path and filename without the filetype

  ERRORS


  
]]

function dtutils.chop_filetype(path)
  local length = dtutils.get_filetype(path):len() + 2
  return string.sub(path, 1, -length)
end

--[[
  NAME
    dutils.prequire - a protected lua require

  SYNOPSIS
    result = dtutils.prequire(req_name)
      req_name - name of thu lua code to load

  DESCRIPTION
    prequire is a protexted require that can survive an error in the code being loaded without
    bringing down the calling routine.

  RETURN VALUE
    result - the code or true on success, otherwise an error message

  ERRORS


  
]]

function dtutils.prequire(req_name)
  dt.print_error("Loading " .. req_name)
  local status, lib = pcall(require, req_name)
  if status then
    dt.print_error("Loaded " .. req_name)
  else
    dt.print_error("Error loading " .. req_name)
  end
  log.msg(log.debug, "return type of lib is ", type(lib))
  return lib
end

--[[
  NAME
    dutils.push - push a value on a stack

  SYNOPSIS
    result = dtutils.push(stack, value)
      stack - a table being used as the stack
      value - the value to be put on the stack

  DESCRIPTION
    Push a value on a stack

  RETURN VALUE
    result - false if stack isn't a table, true on success

  ERRORS


  
]]

function dtutils.push(stack, value)
  success = false
  if type(stack) == "table" then
    table.insert(stack, value)
    success = true
  end
end

--[[
  NAME
    dutils.pop - pop a value from a stack

  SYNOPSIS
    result = dtutils.pop(stack)
      stack - a table being used as a stack

  DESCRIPTION
    Remove the last value pushed on the stack and return it

  RETURN VALUE
    result = nil if stack isn't a table or the stack is empty, otherwise the value removed from the table

  ERRORS
    

  
]]

function dtutils.pop(stack)
  if type(stack) == "table" then
    if #stack >= 1
      return table.remove(stack)
    else
      return nil
    end
  else
    return nil
  end
end

--[[
  NAME
    dutils.fixSlliderFloat - correct decimal point problems with slidets and environments

  SYNOPSIS
    result = dtutils.fixSliderFloat(float_str)

  DESCRIPTION
    Some locales use a "," instead of "." for the decimal point.  This routine ensures that
    a "." is used as the decimal point.

  RETURN VALUE
    result = valid floating point number in string form

  ERRORS
    If a number without a decimal point is passed to the routine, it is simply returned with
    no change.


  
]]

function dtutils.fixSliderFloat(float_str)
  if string.match(float_str,"[,.]") then 
    local characteristic, mantissa = string.match(float_str, "(%d+)[,.](%d+)")
    float_str = characteristic .. '.' .. mantissa
  end
  return float_str
end

--[[
  NAME
    dutils.fileCopy - copy a file to another name/location

  SYNOPSIS
    result = dtutils.fileCopy(fromFile, toFile)
      fromFile - file to copy from
      toFile - file to copy to

  DESCRIPTION
    copy a file using a succession of methods from operating system
    to a pure lua solution

  RETURN VALUE
    result - nil on error, true on success

  ERRORS


  
]]

function dtutils.fileCopy(fromFile, toFile)
  local result = nil
  -- if cp exists, use it
  if dtutils.checkIfBinExists("cp") then
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
        dt.print_error("fileCopy Error: " .. errr)
      end
    else
      dt.print_error("fileCopy Error: " .. err)
    end
  end
  return result
end

--[[
  NAME
    dutils.fileMove - move a file from one directory to another

  SYNOPSIS
    result = dtutils.fileMove(fromFile, toFile)
      fromFile - the original file
      toFile - the new file location and name

  DESCRIPTION
    Move a file from one place to another.  Try a succession of methods from
    builtin to operating system to a pure lua solution.

  RETURN VALUE
    result - nil on error, some value on success

  ERRORS


  
]]

function dtutils.fileMove(fromFile, toFile)
  local success = os.rename(fromFile, toFile)
  if not success then
    -- an error occurred, so let's try using the operating system function
    if dtutils.checkIfBinExists("mv") then
      success = os.execute("mv '" .. fromFile .. "' '" .. toFile .. "'")
    end
    -- if the mv didn't exist or succeed, then...
    if not success then
      -- pure lua solution
      success = dtutils.fileCopy(fromFile, toFile)
      if success then
        os.remove(fromFile)
      else
        dt.print_error("fileMove Error: Unable to move " .. fromFile .. " to " .. toFile .. ".  Leaving " .. fromFile .. " in place.")
        dt.print(string.format(_("Unable to move edited file into collection. Leaving it as %s"), fromFile))
      end
    end
  end
  return success  -- nil on error, some value if success
end

--[[
  NAME
    dutils.updateComboboxChoices - change the list of choices in a combobox

  SYNOPSIS
    dtutils.updateComboboxChoices(combobox_widget, choice_table)
      combobox_widget - a combobox widget
      choice_table - a table of strings for the combobox choices

  DESCRIPTION
    Set the combobox choices to the supplied list.  Remove any extra choices from the end

  RETURN VALUE
    none

  ERRORS


  
]]

function dtutils.updateComboboxChoices(combobox, choice_table)
  local items = #combobox
  local choices = #choice_table
  for i, name in ipairs(choice_table) do 
    log.msg(log.debug, "Setting " .. i .. " to " .. name)
    combobox[i] = name
  end
  if choices < items then
    for j = items, choices + 1, -1 do
      log.msg(log.debug, "Removing choice " .. j)
      combobox[j] = nil
    end
  end
  combobox.value = 1
end

return dtutils
