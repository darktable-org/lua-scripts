--[[
    This file is part of darktable,
    Copyright 2016 by Tobias Jakobs.
    Copyright 2016 by Erik Augustin.

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
--[[
darktable KML export script

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* mkdir
* zip (only if you create KMZ files)
* convert (ImageMagick)
* xdg-open
* xdg-user-dir

WARNING
This script is only tested with Linux

USAGE
* require script "official/yield" from your main Lua file in the first line
* require this script from your main Lua file
* when choosing file format, pick JPEG or PNG as Google Earth doesn't support other formats

]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
require "official/yield"
local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0},{4,0,0},{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("kml_export",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("kml_export", msgid)
end

-- Sort a table
local function spairs(_table, order) -- Code copied from http://stackoverflow.com/questions/15706270/sort-a-table-in-lua
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

local function show_status(storage, image, format, filename, number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
end

-- Strip accents from a string
-- Copied from https://forums.coronalabs.com/topic/43048-remove-special-characters-from-string/
function string.stripAccents( str )
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

-- Escape XML characters
-- Keep &amp; first, otherwise it will double escape other characters
-- https://stackoverflow.com/questions/1091945/what-characters-do-i-need-to-escape-in-xml-documents
function string.escapeXmlCharacters( str )

    str = string.gsub(str,"&", "&amp;")
    str = string.gsub(str,"\"", "&quot;")
    str = string.gsub(str,"'", "&apos;")
    str = string.gsub(str,"<", "&lt;")
    str = string.gsub(str,">", "&gt;")

    return str
end

local function create_kml_file(storage, image_table, extra_data)
    if not df.check_if_bin_exists("mkdir") then
        dt.print_error(_("mkdir not found"))
        return
    end
    if not df.check_if_bin_exists("convert") then
        dt.print_error(_("convert not found"))
        return
    end
    if not df.check_if_bin_exists("xdg-open") then
        dt.print_error(_("xdg-open not found"))
        return
    end
    if not df.check_if_bin_exists("xdg-user-dir") then
        dt.print_error(_("xdg-user-dir not found"))
        return
    end

    dt.print_error("Will try to export KML file now")

    local imageFoldername
    if ( dt.preferences.read("kml_export","CreateKMZ","bool") == true ) then
        if not df.check_if_bin_exists("zip") then
            dt.print_error(_("zip not found"))
            return
        end

        exportDirectory = dt.configuration.tmp_dir
        imageFoldername = ""
    else
        exportDirectory = dt.preferences.read("kml_export","ExportDirectory","string")

        -- Creates dir if not exsists
        imageFoldername = "files/"
        local mkdirCommand = "mkdir -p "..exportDirectory.."/"..imageFoldername
        dt.control.execute(mkdirCommand)
    end


    -- Create the thumbnails
    for image,exported_image in pairs(image_table) do
        if ((image.longitude and image.latitude) and
            (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
            local path, filename, filetype = string.match(exported_image, "(.-)([^\\/]-%.?([^%.\\/]*))$")
            filename = string.upper(string.gsub(filename,"%.%w*", ""))

            -- convert -size 92x92 filename.jpg -resize 92x92 +profile "*" thumbnail.jpg
            --	In this example, '-size 120x120' gives a hint to the JPEG decoder that the image is going to be downscaled to
            --	120x120, allowing it to run faster by avoiding returning full-resolution images to  GraphicsMagick for the
            --	subsequent resizing operation. The '-resize 120x120' specifies the desired dimensions of the output image. It
            --	will be scaled so its largest dimension is 120 pixels. The '+profile "*"' removes any ICM, EXIF, IPTC, or other
            --	profiles that might be present in the input and aren't needed in the thumbnail.

            local convertToThumbCommand = "convert -size 96x96 "..exported_image.." -resize 92x92 -mattecolor \"#FFFFFF\" -frame 2x2 +profile \"*\" "..exportDirectory.."/"..imageFoldername.."thumb_"..filename..".jpg"
            dt.control.execute(convertToThumbCommand)
        else
            -- Remove exported image if it has no GPS data
            os.remove(exported_image)
        end

        local pattern = "[/]?([^/]+)$"
        filmName = string.match(image.film.path, pattern)

        -- Strip accents from the filename, because GoogleEarth can't open them
        -- https://github.com/darktable-org/lua-scripts/issues/54
        filmName = string.stripAccents(filmName)
    end

    exportKMLFilename = filmName..".kml"
    exportKMZFilename = filmName..".kmz"

    -- Create the KML file
    local kml_file = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    kml_file = kml_file.."<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n"
    kml_file = kml_file.."<Document>\n"

    --image_table = dt.gui.selection();
    kml_file = kml_file.."<name>"..filmName.."</name>\n"
    kml_file = kml_file.."    <description>Exported from darktable</description>\n"

    for image,exported_image in pairs(image_table) do
    -- Extract filename, e.g DSC9784.ARW -> DSC9784
    filename = string.upper(string.gsub(image.filename,"%.%w*", ""))
    -- Extract extension from exported image (user can choose JPG or PNG), e.g DSC9784.JPG -> .JPG
    extension = string.match(exported_image,"%.%w*$")

	if ((image.longitude and image.latitude) and
            (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
            kml_file = kml_file.."  <Placemark>\n"

            local image_title, image_description
            if (image.title and image.title ~= "") then
                image_title = string.escapeXmlCharacters(image.title)
            else
                image_title = image.filename
            end
            -- Characters should not be escaped in CDATA, but we are using HTML fragment, so we must escape them
            image_description = string.escapeXmlCharacters(image.description)

            kml_file = kml_file.."    <name>"..image_title.."</name>\n"
            kml_file = kml_file.."    <description>"..image_description.."</description>\n"
            kml_file = kml_file.."    <Style>\n"
            kml_file = kml_file.."      <IconStyle>\n"
            kml_file = kml_file.."        <Icon>\n"
            kml_file = kml_file.."          <href>"..imageFoldername.."thumb_"..filename..".jpg</href>\n"
            kml_file = kml_file.."        </Icon>\n"
            kml_file = kml_file.."      </IconStyle>\n"
            kml_file = kml_file.."      <BalloonStyle>\n"
            kml_file = kml_file.."        <text><![CDATA[<p><b>"..image_title.."</b></p><img src=\""..imageFoldername..filename..extension.."\"><p>"..image_description.."</p>]]></text>\n"
            kml_file = kml_file.."        <textColor>ff000000</textColor>\n"
            kml_file = kml_file.."        <displayMode>default</displayMode>\n"
            kml_file = kml_file.."      </BalloonStyle>\n"
            kml_file = kml_file.."    </Style>\n"

            kml_file = kml_file.."    <Point>\n"
            kml_file = kml_file.."      <extrude>1</extrude>\n"
            kml_file = kml_file.."      <coordinates>"..string.gsub(tostring(image.longitude),",", ".")..","..string.gsub(tostring(image.latitude),",", ".")..",0</coordinates>\n"
            kml_file = kml_file.."      <TimeStamp>\n"
            kml_file = kml_file.."        <when>"..string.gsub(image.exif_datetime_taken," ", "T").."Z".."</when>\n"
            kml_file = kml_file.."      </TimeStamp>\n"
            kml_file = kml_file.."    </Point>\n"

            kml_file = kml_file.."  </Placemark>\n"
        end
    end

-- Connects all images with an path
    if ( dt.preferences.read("kml_export","CreatePath","bool") == true ) then
      kml_file = kml_file.."  <Placemark>\n"
      kml_file = kml_file.."    <name>Path</name>\n"  -- ToDo: I think a better name would be nice
      --kml_file = kml_file.."    <description></description>\n"

      kml_file = kml_file.."   <Style>\n"
      kml_file = kml_file.."     <LineStyle>\n"
      kml_file = kml_file.."       <color>ff0000ff</color>\n"
      kml_file = kml_file.."       <width>5</width>\n"
      kml_file = kml_file.."     </LineStyle>\n"
      kml_file = kml_file.."   </Style>\n"

      kml_file = kml_file.."    <LineString>\n"
      kml_file = kml_file.."      <coordinates>\n"

      for image,exported_image in spairs(image_table, function(t,a,b) return t[b] < t[a] end) do
	  if ((image.longitude and image.latitude) and
              (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
             ) then
              local altitude = 0;
              if (image.elevation) then
                altitude = image.elevation;
              end
              kml_file = kml_file.."        "..string.gsub(tostring(image.longitude),",", ".")..","..string.gsub(tostring(image.latitude),",", ".")..",altitude\n"
          end
      end
      kml_file = kml_file.."      </coordinates>\n"
      kml_file = kml_file.."    </LineString>\n"

      kml_file = kml_file.."  </Placemark>\n"
    end

    kml_file = kml_file.."</Document>\n"
    kml_file = kml_file.."</kml>"

    local file = io.open(exportDirectory.."/"..exportKMLFilename, "w")
    file:write(kml_file)
    file:close()

    dt.print("KML file created in "..exportDirectory)

-- Compress the files to create a KMZ file
    if ( dt.preferences.read("kml_export","CreateKMZ","bool") == true ) then
       exportDirectory = dt.preferences.read("kml_export","ExportDirectory","string")

        local createKMZCommand = "zip --test --move --junk-paths "
        createKMZCommand = createKMZCommand .."\""..exportDirectory.."/"..exportKMZFilename.."\" "           -- KMZ filename
        createKMZCommand = createKMZCommand .."\""..dt.configuration.tmp_dir.."/"..exportKMLFilename.."\" "  -- KML file

        for image,exported_image in pairs(image_table) do
          if ((image.longitude and image.latitude) and
              (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
             ) then
            local filename = string.upper(string.gsub(image.filename,"%.%w*", ""))

            createKMZCommand = createKMZCommand .."\""..dt.configuration.tmp_dir.."/"..imageFoldername.."thumb_"..filename..".jpg\" " -- thumbnails
            createKMZCommand = createKMZCommand .."\""..exported_image.."\" "  -- images
          end
        end

	dt.control.execute(createKMZCommand)
    end

-- Open the file with the standard programm
    if ( dt.preferences.read("kml_export","OpenKmlFile","bool") == true ) then
		local kmlFileOpenCommand

        if ( dt.preferences.read("kml_export","CreateKMZ","bool") == true ) then
            kmlFileOpenCommand = "xdg-open "..exportDirectory.."/\""..exportKMZFilename.."\""
        else
            kmlFileOpenCommand = "xdg-open "..exportDirectory.."/\""..exportKMLFilename.."\""
		end
        dt.control.execute(kmlFileOpenCommand)
    end


end

-- Preferences
dt.preferences.register("kml_export",
	"OpenKmlFile",
	"bool",
	_("KML export: Open KML/KMZ file after export"),
	_("Opens the KML file after the export with the standard program for KML files"),
	false )

local handle = io.popen("xdg-user-dir DESKTOP")
local result = handle:read()
if (result == nil) then
	result = ""
end
handle:close()
dt.preferences.register("kml_export",
	"ExportDirectory",
	"directory",
	_("KML export: Export directory"),
	_("A directory that will be used to export the KML/KMZ files"),
	result )

dt.preferences.register("kml_export",
	"CreatePath",
	"bool",
	_("KML export: Connect images with path"),
	_("connect all images with a path"),
	false )
dt.preferences.register("kml_export",
	"CreateKMZ",
	"bool",
	_("KML export: Create KMZ file"),
	_("Compress all imeges to one KMZ file"),
	true )

-- Register
dt.register_storage("kml_export", _("KML/KMZ Export"), nil, create_kml_file)
