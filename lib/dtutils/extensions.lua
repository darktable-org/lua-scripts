--[[

  NAME
    dtutils/extensions.lua - a library of extenstions to the lua libraries

  SYNOPSIS
    require "lib/dtutils.extensions"

  DESCRIPTION
    This library contains extensions to the lua libraries.

]]

local dtutils_extensions = {}
dtutils_extensions.libdoc = {
  Sections = {"Name", "Synopsis", "Description", "License"},
  Name = "dtutils.extensions - a library of extenstions to the lua libraries",
  Synopsis = [[require "lib/dtutils.extensions"]],
  Description = [[This library contains extensions to the lua libraries.]],
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

--[[
  
  NAME
    string.strip_accents - strip accents from characters

  SYNOPSIS
    require "lib/dtutils.extensions"

    result = string.strip_accents(str)
      str - string - the string with characters that need accents removed

  DESCRIPTION
    strip_accents removes accents from accented characters returning the 
    unaccented character.

  RETURN VALUE
    result - string - the string containing unaccented characters
  
]]

dtutils_extensions.libdoc.functions[#dtutils_extensions.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[string.strip_accents - strip accents from characters]],
  Synopsis = [[require "lib/dtutils.extensions"

    result = string.strip_accents(str)
      str - string - the string with characters that need accents removed]],
  Description = [[strip_accents removes accents from accented characters returning the 
    unaccented character.]],
  Return_Value = [[result - string - the string containing unaccented characters]],
}

-- Strip accents from a string
-- Copied from https://forums.coronalabs.com/topic/43048-remove-special-characters-from-string/
function string.strip_accents( str )
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

--[[
  
  NAME
    string.escape_xml_characters - escape characters for xml documents

  SYNOPSIS
    require "lib/dtutils.extensions"
    
    result = string.escape_xml_characters(str)
      str - string - the string that needs escaped

  DESCRIPTION
    escape_xml_characters provides the escape sequences for
    "&", '"', "'", "<", and ">" with the corresponding "&amp;",
    "&quot;", "&apos;", "&lt;", and "&gt;".

  RETURNN VALUE
    result - string - the string containing escapes for the xml characters
  
]]

dtutils_extensions.libdoc.functions[#dtutils_extensions.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = "string.escape_xml_characters - escape characters for xml documents",
  Synopsis = [[    require "lib/dtutils.extensions"
    
    result = string.escape_xml_characters(str)
      str - string - the string that needs escaped]],
  Description = [[escape_xml_characters provides the escape sequences for
    "&", '"', "'", "<", and ">" with the corresponding "&amp;",
    "&quot;", "&apos;", "&lt;", and "&gt;".]],
  Return_Value = [[result - string - the string containing escapes for the xml characters]],
}

-- Escape XML characters
-- Keep &amp; first, otherwise it will double escape other characters
-- https://stackoverflow.com/questions/1091945/what-characters-do-i-need-to-escape-in-xml-documents
function string.escape_xml_characters( str )

  str = string.gsub(str,"&", "&amp;")
  str = string.gsub(str,"\"", "&quot;")
  str = string.gsub(str,"'", "&apos;")
  str = string.gsub(str,"<", "&lt;")
  str = string.gsub(str,">", "&gt;")

  return str
end

return dtutils_extensions
