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

local dtutils = {}

dtutils.libdoc = {
  Sections = {"Name", "Synopsis", "Description", "See_Also", "License"},
  Name = [[dtutils - A Darktable lua utilities library]],
  Synopsis = [[local du = require "lib/dtutils"]],
  Description = [[dtutils provides a common library of functions used to build
    lua scripts. There are also sublibraries that provide more functions.]],
  See_Also = [[dtutils.debug(3), dtutils.extensionts(3), dtutils.file(3), dtutils.processor(3)]],
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

dt.configuration.check_version(...,{3,0,0})

--[[
  NAME
    split - split a string on a specified separator

  SYNOPSIS
    local du = require "lib/dtutils"

    local result = du.split(str, pat)
      str - string - the string to split
      pat - string - the pattern to split on

  DESCRIPTION
    split separates a string into a table of strings.  The strings are separated at each
    occurrence of the supplied pattern.

  RETURN VALUE
    result - a table of strings on success, or an empty table on error

  EXAMPLE
    split("/a/long/path/name/to/a/file.txt", "/") would return a table like
      {"a", "long", "path", "name", "to", "a", "file.txt"}

]]

dtutils.libdoc.functions[#dtutils.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value", "Example"},
  Name = [[split - split a string on a specified separator]],
  Synopsis = [[local du = require "lib/dtutils"

    local result = du.split(str, pat)
      str - string - the string to split
      pat - string - the pattern to split on]],
  Description = [[split separates a string into a table of strings.  The strings are separated at each
    occurrence of the supplied pattern.]],
  Return_Value = [[result - a table of strings on success, or an empty table on error]],
  Example = [[split("/a/long/path/name/to/a/file.txt", "/") would return a table like
      {"a", "long", "path", "name", "to", "a", "file.txt"}]],
}

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
    join - join a table of strings with a specified separator

  SYNOPSIS
    local du = require "lib/dtutils"

    local result = du.join(tabl, pat)
      tabl - a table of strings
      pat - a separator

  DESCRIPTION
    join assembles a table of strings into a string with the specified pattern 
    in between each string

  RETURN VALUE
    result - the joined string on success, or an empty string on failure

  EXAMPLE
    join({"a", "long", "path", "name", "to", "a", "file.txt"}, " ") would return the string
      "a long path name to a file.txt"

]]

dtutils.libdoc.functions[#dtutils.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value", "Example"},
  Name = [[join - join a table of strings with a specified separator]],
  Synopsis = [[local du = require "lib/dtutils"

    local result = du.join(tabl, pat)
      tabl - a table of strings
      pat - a separator]],
  Description = [[join assembles a table of strings into a string with the specified pattern 
    in between each string]],
  Return_Value = [[result - the joined string on success, or an empty string on failure]],
  Example = [[join({"a", "long", "path", "name", "to", "a", "file.txt"}, " ") would return the string
      "a long path name to a file.txt"]],
}

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
    prequire - a protected lua require

  SYNOPSIS
    local du = require "lib/dtutils"

    local result = du.prequire(req_name)
      req_name - the filename of the lua code to load without the ".lua" filetype

  DESCRIPTION
    prequire is a protected require that can survive an error in the code being loaded without
    bringing down the calling routine.

  RETURN VALUE
    result - the code or true on success, otherwise an error message

  EXAMPLE
    prequire("lib/dtutils.file") which would load lib/dtutils/file.lua

]]

dtutils.libdoc.functions[#dtutils.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value", "Example"},
  Name = [[prequire - a protected lua require]],
  Synopsis = [[local du = require "lib/dtutils"

    local result = du.prequire(req_name)
      req_name - the filename of the lua code to load without the ".lua" filetype]],
  Description = [[prequire is a protected require that can survive an error in the code being loaded without
    bringing down the calling routine.]],
  Return_Value = [[result - the code or true on success, otherwise an error message]],
  Example = [[prequire("lib/dtutils.file") which would load lib/dtutils/file.lua]],
}

function dtutils.prequire(req_name)
  local status, lib = pcall(require, req_name)
  if status then
    log.msg(log.info, "Loaded " .. req_name)
  else
    log.msg(log.info, "Error loading " .. req_name)
  end
  return lib
end

--[[
  NAME
    push - push a value on a stack

  SYNOPSIS
    local du = require "lib/dtutils"

    du.push(stack, value)
      stack - table - a table being used as the stack
      value - any type - the value to be put on the stack

  DESCRIPTION
    Push a value on a stack

  RETURN VALUE
    none

]]

dtutils.libdoc.functions[#dtutils.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[push - push a value on a stack]],
  Synopsis = [[local du = require "lib/dtutils"

    du.push(stack, value)
      stack - table - a table being used as the stack
      value - any type - the value to be put on the stack]],
  Description = [[Push a value on a stack]],
  Return_Value = [[none]],
}

dtutils.push = table.insert

--[[
  NAME
    pop - pop a value from a stack

  SYNOPSIS
    local du = require "lib/dtutils"

    local result = du.pop(stack)
      stack - table - a table being used as a stack

  DESCRIPTION
    Remove the last value pushed on the stack and return it

  RETURN VALUE
    result = nil if stack isn't a table or the stack is empty, otherwise the value removed from the stack

]]

dtutils.libdoc.functions[#dtutils.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[pop - pop a value from a stack]],
  Synopsis = [[local du = require "lib/dtutils"

    local result = du.pop(stack)
      stack - table - a table being used as a stack]],
  Description = [[Remove the last value pushed on the stack and return it]],
  Return_Value = [[result = nil if stack isn't a table or the stack is empty, otherwise the value removed from the stack]],
}

dtutils.pop = table.remove

--[[
  NAME
    update_combobox_choices - change the list of choices in a combobox

  SYNOPSIS
    local du = require "lib/dtutils"

    du.update_combobox_choices(combobox_widget, choice_table)
      combobox_widget - lua_combobox - a combobox widget
      choice_table - table - a table of strings for the combobox choices

  DESCRIPTION
    Set the combobox choices to the supplied list.  Remove any extra choices from the end

  RETURN VALUE
    none

]]

dtutils.libdoc.functions[#dtutils.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[update_combobox_choices - change the list of choices in a combobox]],
  Synopsis = [[local du = require "lib/dtutils"

    du.update_combobox_choices(combobox_widget, choice_table)
      combobox_widget - lua_combobox - a combobox widget
      choice_table - table - a table of strings for the combobox choices]],
  Description = [[Set the combobox choices to the supplied list.  Remove any extra choices from the end]],
  Return_Value = [[none]],
}

function dtutils.update_combobox_choices(combobox, choice_table)
  local items = #combobox
  local choices = #choice_table
  for i, name in ipairs(choice_table) do 
    log.msg(log.debug, "Setting choice " .. i .. " to " .. name)
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

--[[
  NAME
    spairs - an iterator that provides sorted pairs from a table

  SYNOPSIS
    local du = require "lib/dtutils"

    for key, value in du.spairs(t, order) do
      t - table - table of key, value pairs
      order - function - an optional function to sort the pairs
                         if none is supplied, table.sort() is used

  DESCIRPTION
    spairs is an iterator that returns key, value pairs from a table in sorted
    order.  The sorting order is the result of table.sort() if no function is 
    supplied, otherwise sorting is done as specified in the function.

  EXAMPLE
    HighScore = { Robin = 8, Jon = 10, Max = 11 }

    -- basic usage, just sort by the keys
    for k,v in spairs(HighScore) do
      print(k,v)
    end
    --> Jon     10
    --> Max     11
    --> Robin   8

    -- this uses an custom sorting function ordering by score descending
    for k,v in spairs(HighScore, function(t,a,b) return t[b] < t[a] end) do
      print(k,v)
    end
    --> Max     11
    --> Jon     10
    --> Robin   8

  REFERENCE
    Code copied from http://stackoverflow.com/questions/15706270/sort-a-table-in-lua

]]

dtutils.libdoc.functions[#dtutils.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Example", "Reference"},
  Name = [[spairs - an iterator that provides sorted pairs from a table]],
  Synopsis = [[local du = require "lib/dtutils"

    for key, value in du.spairs(t, order) do
      t - table - table of key, value pairs
      order - function - an optional function to sort the pairs
                         if none is supplied, table.sort() is used]],
  Description = [[spairs is an iterator that returns key, value pairs from a table in sorted
    order.  The sorting order is the result of table.sort() if no function is 
    supplied, otherwise sorting is done as specified in the function.]],
  Example = [[HighScore = { Robin = 8, Jon = 10, Max = 11 }

    -- basic usage, just sort by the keys
    for k,v in spairs(HighScore) do
      print(k,v)
    end
    --> Jon     10
    --> Max     11
    --> Robin   8

    -- this uses an custom sorting function ordering by score descending
    for k,v in spairs(HighScore, function(t,a,b) return t[b] < t[a] end) do
      print(k,v)
    end
    --> Max     11
    --> Jon     10
    --> Robin   8]],
  Reference = [[Code copied from http://stackoverflow.com/questions/15706270/sort-a-table-in-lua]],
}

-- Sort a table
function dtutils.spairs(_table, order) -- Code copied from http://stackoverflow.com/questions/15706270/sort-a-table-in-lua
  -- collect the keys
  local keys = {}
  for _key in pairs(_table) do keys[#keys + 1] = _key end

  -- if order function given, sort by it by passing the table and keys a, b,
  -- otherwise just sort the keys 
  if order then
    table.sort(keys, function(a,b) return order(_table, a, b) end)
  else
    table.sort(keys)
  end

  -- return the iterator function
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], _table[keys[i]]
    end
  end
end

--[[
  
  NAME
    urlencode - encode a string in a websage manner

  SYNOPOIS
    local du = require "lib/dtutils"

    local result = du.urlencode(str)
      str - string - the string that needs to be made websafe

  DESCRIPTION
    urlencode converts a string into a websafe version suitable for
    use in a web browser.

  RETURN_VALUE
    result - string - a websafe string

  REFERENCE
    https://forums.coronalabs.com/topic/43048-remove-special-characters-from-string/

]]

dtutils.libdoc.functions[#dtutils.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value", "Reference"},
  Name = [[urlencode - encode a string in a websage manner]],
  Synopsis = [[local du = require "lib/dtutils"

    local result = du.urlencode(str)
      str - string - the string that needs to be made websafe]],
  Description = [[urlencode converts a string into a websafe version suitable for
    use in a web browser.]],
  Return_Value = [[result - string - a websafe string]],
  Reference = [[https://forums.coronalabs.com/topic/43048-remove-special-characters-from-string/]],
}

function dtutils.urlencode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w ])", function () return string.format ("%%%02X", string.byte()) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end

return dtutils
