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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


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

  DESCRIPTION


  RETURN VALUE


  ERRORS


  
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

  DESCRIPTION


  RETURN VALUE


  ERRORS


  
]]

function dtutils.show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
end

--[[
  NAME
    dutils.tellme - recursively dump the requested data

  SYNOPSIS
    dtutils.tellme(offset, story)

  DESCRIPTION


  EXAMPLE
    dtutils.tellme("",_G)

  RETURN VALUE


  ERRORS


  
]]

function dtutils.tellme(offset, story)
  local n,v
  for n,v in pairs(story) do
    if n ~= "loaded" and n ~= "_G" then
      io.write (offset .. n .. " " )
      print (v)
      if type(v) == "table" then
              tellme(offset .. "--> ",v)
      end
    end
  end
end

function dtutils.extract_image_list(image_table)
  local img_list = ""
  for _,exp_img in pairs(image_table) do
    img_list = img_list .. " " .. exp_img
  end
  return img_list
end

function dtutils.extract_collection_path(image_table)
  collection_path = nil
  for i,_ in pairs(image_table) do
    collection_path = i.path
    break
  end
  return collection_path
end

-- Thanks to http://lua-users.org/wiki/SplitJoin for the split and split_path functions
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

function dtutils.join(tabl, pat)
  returnstr = ""
  for i,str in pairs(tabl) do
    returnstr = returnstr .. str .. pat
  end
  return string.sub(returnstr, 1, -(pat:len() + 1))
end

function dtutils.makeOutputFileName(img_list)
  local images = {}
  local cnt = 1
  local max_distinct_names = 3
  local name_separator = "-"
  local outputFileName = nil
  print("img_list is ", img_list)

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

function dtutils.chop_filetype(path)
  local length = dtutils.get_filetype(path):len() + 2
  return string.sub(path, 1, -length)
end

function dtutils.prequire(req_name)
  dt.print_error("Loading " .. req_name)
  local status, lib = pcall(require, req_name)
  if status then
    dt.print_error("Loaded " .. req_name)
  else
    dt.print_error("Error loading " .. req_name)
  end
  print("return type of lib is ", type(lib))
  return lib
end

function dtutils.push(stack, value)
  success = false
  if type(stack) == "table" then
    table.insert(stack, value)
    success = true
  end
end

function dtutils.pop(stack)
  if type(stack) == "table" then
    return table.remove(stack)
  else
    return nil
  end
end

function dtutils.fixSliderFloat(float_str)
  if string.match(float_str,"[,.]") then 
    local characteristic, mantissa = string.match(float_str, "(%d+)[,.](%d+)")
    float_str = characteristic .. '.' .. mantissa
  end
  return float_str
end

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

function dtutils.getTargetDir(img_list)
  local target = nil
  for img,_ in pairs(img_list) do
    target = img.path
    break
  end
  return target
end

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
end

return dtutils
