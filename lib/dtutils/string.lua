local dtutils_string = {}

local dt = require "darktable"

dtutils_string.libdoc = {
  Name = [[dtutils.string]],
  Synopsis = [[a library of string utilities for use in darktable lua scripts]],
  Usage = [[local ds = require "lib/dtutils.string"]],
  Description = [[This library contains string manipulation routines to aid in building
    darktable lua scripts.]],
  Return_Value = [[du - library - the darktable lua string library]],
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
  Copyright = [[Copyright (c) 2016 Bill Ferguson <wpferguson@gmail.com>]],
  functions = {}
}

dtutils_string.libdoc.functions["strip_accents"] = {
  Name = [[strip_accents]],
  Synopsis = [[strip accents from characters]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.strip_accents(str)
      str - string - the string with characters that need accents removed]],
  Description = [[strip_accents removes accents from accented characters returning the 
    unaccented character.]],
  Return_Value = [[result - string - the string containing unaccented characters]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[Copied from https://forums.coronalabs.com/topic/43048-remove-special-characters-from-string/]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_string.strip_accents( str )
  local tableAccents = {}
    tableAccents["à"] = "a"
    tableAccents["á"] = "a"
    tableAccents["â"] = "a"
    tableAccents["ã"] = "a"
    tableAccents["ä"] = "a"
    tableAccents["ç"] = "c"
    tableAccents["è"] = "e"
    tableAccents["é"] = "e"
    tableAccents["ê"] = "e"
    tableAccents["ë"] = "e"
    tableAccents["ì"] = "i"
    tableAccents["í"] = "i"
    tableAccents["î"] = "i"
    tableAccents["ï"] = "i"
    tableAccents["ñ"] = "n"
    tableAccents["ò"] = "o"
    tableAccents["ó"] = "o"
    tableAccents["ô"] = "o"
    tableAccents["õ"] = "o"
    tableAccents["ö"] = "o"
    tableAccents["ù"] = "u"
    tableAccents["ú"] = "u"
    tableAccents["û"] = "u"
    tableAccents["ü"] = "u"
    tableAccents["ý"] = "y"
    tableAccents["ÿ"] = "y"
    tableAccents["À"] = "A"
    tableAccents["Á"] = "A"
    tableAccents["Â"] = "A"
    tableAccents["Ã"] = "A"
    tableAccents["Ä"] = "A"
    tableAccents["Ç"] = "C"
    tableAccents["È"] = "E"
    tableAccents["É"] = "E"
    tableAccents["Ê"] = "E"
    tableAccents["Ë"] = "E"
    tableAccents["Ì"] = "I"
    tableAccents["Í"] = "I"
    tableAccents["Î"] = "I"
    tableAccents["Ï"] = "I"
    tableAccents["Ñ"] = "N"
    tableAccents["Ò"] = "O"
    tableAccents["Ó"] = "O"
    tableAccents["Ô"] = "O"
    tableAccents["Õ"] = "O"
    tableAccents["Ö"] = "O"
    tableAccents["Ù"] = "U"
    tableAccents["Ú"] = "U"
    tableAccents["Û"] = "U"
    tableAccents["Ü"] = "U"
    tableAccents["Ý"] = "Y"
        
  local normalizedString = ""

  for strChar in string.gmatch(str, "([%z\1-\127\194-\244][\128-\191]*)") do
    if tableAccents[strChar] ~= nil then
      normalizedString = normalizedString..tableAccents[strChar]
    else
      normalizedString = normalizedString..strChar
    end
  end
        
  return normalizedString
 
end

dtutils_string.libdoc.functions["escape_xml_characters"] = {
  Name = [[escape_xml_characters]],
  Synopsis = [[escape characters for xml documents]],
  Usage = [[local ds = require "lib/dtutils.string"
    
    local result = ds.escape_xml_characters(str)
      str - string - the string that needs escaped]],
  Description = [[escape_xml_characters provides the escape sequences for
    "&", '"', "'", "<", and ">" with the corresponding "&amp;",
    "&quot;", "&apos;", "&lt;", and "&gt;".]],
  Return_Value = [[result - string - the string containing escapes for the xml characters]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[https://stackoverflow.com/questions/1091945/what-characters-do-i-need-to-escape-in-xml-documents]],
  License = [[]],
  Copyright = [[]],
}

-- Keep &amp; first, otherwise it will double escape other characters
function dtutils_string.escape_xml_characters( str )

  str = string.gsub(str,"&", "&amp;")
  str = string.gsub(str,"\"", "&quot;")
  str = string.gsub(str,"'", "&apos;")
  str = string.gsub(str,"<", "&lt;")
  str = string.gsub(str,">", "&gt;")

  return str
end

dtutils_string.libdoc.functions["urlencode"] = {
  Name = [[urlencode]],
  Synopsis = [[encode a string in a websage manner]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.urlencode(str)
      str - string - the string that needs to be made websafe]],
  Description = [[urlencode converts a string into a websafe version suitable for
    use in a web browser.]],
  Return_Value = [[result - string - a websafe string]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[https://forums.coronalabs.com/topic/43048-remove-special-characters-from-string/]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_string.urlencode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w ])", function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end


dtutils_string.libdoc.functions["is_not_sanitized"] = {
  Name = [[is_not_sanitized]],
  Synopsis = [[Check if a string has been sanitized]],
  Usage = [[local ds = require "lib/dtutils.string"
    local result = ds.is_not_sanitized(str)
      str - string - the string that needs to be made safe]],
  Description = [[is_not_sanitized checks a string to see if it
    has been made safe use passing as an argument in a system command.]],
  Return_Value = [[result - boolean - true if the string is not sanitized otherwise false]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

local function _is_not_sanitized_posix(str)
   -- A sanitized string must be quoted.
   if not string.match(str, "^'.*'$") then
       return true
   -- A quoted string containing no quote characters within is sanitized.
   elseif string.match(str, "^'[^']*'$") then
       return false
   end
   
   -- Any quote characters within a sanitized string must be properly
   -- escaped.
   local quotesStripped = string.sub(str, 2, -2)
   local escapedQuotesRemoved = string.gsub(quotesStripped, "'\\''", "")
   if string.find(escapedQuotesRemoved, "'") then
       return true
   else
       return false
   end
end

local function _is_not_sanitized_windows(str)
   if not string.match(str, "^\".*\"$") then
      return true
   else
      return false
   end
end

function dtutils_string.is_not_sanitized(str)
  if dt.configuration.running_os == "windows" then
      return _is_not_sanitized_windows(str)
  else
      return _is_not_sanitized_posix(str)
  end
end

dtutils_string.libdoc.functions["sanitize"] = {
  Name = [[sanitize]],
  Synopsis = [[surround a string in quotes making it safe to pass as an argument]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.sanitize(str)
      str - string - the string that needs to be made safe]],
  Description = [[sanitize converts a string into a version suitable for
    use passing as an argument in a system command.]],
  Return_Value = [[result - string - a websafe string]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

local function _sanitize_posix(str)
  if _is_not_sanitized_posix(str) then
      return "'" .. string.gsub(str, "'", "'\\''") .. "'"
  else
       return str
  end
end

local function _sanitize_windows(str)
  if _is_not_sanitized_windows(str) then
      return "\"" .. string.gsub(str, "\"", "\"^\"\"") .. "\""
  else
      return str
  end
end

function dtutils_string.sanitize(str)
  if dt.configuration.running_os == "windows" then
      return _sanitize_windows(str)
  else
      return _sanitize_posix(str)
  end
end

dtutils_string.libdoc.functions["sanitize_lua"] = {
  Name = [[sanitize_lua]],
  Synopsis = [[escape lua 'magic' characters from a pattern string]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.sanitize_lua(str)
      str - string - the string that needs to be made safe]],
  Description = [[sanitize_lua escapes lua 'magic' characters so that
    a string may  be used in lua string/patten matching.]],
  Return_Value = [[result - string - a lua pattern safe string]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_string.sanitize_lua(str)
  str = string.gsub(str, "%-", "%%-")
  str = string.gsub(str, "%(", "%%(")
  str = string.gsub(str, "%)", "%%)")
  return str
end

dtutils_string.libdoc.functions["split_filepath"] = {
  Name = [[split_filepath]],
  Synopsis = [[split a filepath into parts]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.split_filepath(filepath)
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

function dtutils_string.split_filepath(str)
  -- strip out single quotes from quoted pathnames
  str = string.gsub(str, "'", "")
  str = string.gsub(str, '"', '')
  local result = {}
  -- Thank you Tobias Jakobs for the awesome regular expression, which I tweaked a little
  result["path"], result["filename"], result["basename"], result["filetype"] = string.match(str, "(.-)(([^\\/]-)%.?([^%.\\/]*))$")
  if result["basename"] == "" and result["filetype"]:len() > 1 then
    result["basename"] = result["filetype"]
    result["filetype"] = ""
  end
  return result
end

dtutils_string.libdoc.functions["get_path"] = {
  Name = [[get_path]],
  Synopsis = [[get the path from a file path]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.get_path(filepath)
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

function dtutils_string.get_path(str)
  local parts = dtutils_string.split_filepath(str)
  return parts["path"]
end

dtutils_string.libdoc.functions["get_filename"] = {
  Name = [[get_filename]],
  Synopsis = [[get the filename and extension from a file path]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.get_filename(filepath)
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

function dtutils_string.get_filename(str)
  local parts = dtutils_string.split_filepath(str)
  return parts["filename"]
end

dtutils_string.libdoc.functions["get_basename"] = {
  Name = [[get_basename]],
  Synopsis = [[get the filename without the path or extension]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.get_basename(filepath)
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

function dtutils_string.get_basename(str)
  local parts = dtutils_string.split_filepath(str)
  return parts["basename"]
end

dtutils_string.libdoc.functions["get_filetype"] = {
  Name = [[get_filetype]],
  Synopsis = [[get the filetype from a filename]],
  Usage = [[local ds = require "lib/dtutils.string"

    local result = ds.get_filetype(filepath)
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

function dtutils_string.get_filetype(str)
  local parts = dtutils_string.split_filepath(str)
  return parts["filetype"]
end



return dtutils_string
