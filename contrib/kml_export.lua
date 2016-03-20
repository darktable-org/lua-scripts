--[[
    This file is part of darktable,
    Copyright 2016 by Tobias Jakobs.

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
* require this script from your main Lua file

]]
   
local dt = require "darktable"
local gettext = dt.gettext
dt.configuration.check_version(...,{3,0,0})
	
-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("kml_export",dt.configuration.config_dir.."/lua/")

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

local function checkIfBinExists(bin)
    local handle = io.popen("which "..bin)
    local result = handle:read()
    local ret
    handle:close()
    if (not result) then
        dt.print_error(bin.." not found")
        ret = false
    end
    ret = true
    return ret
end

local function create_kml_file(storage, image_table, extra_data)

    if not checkIfBinExists("mkdir") then
        return
    end
    if not checkIfBinExists("convert") then
        return
    end
    if not checkIfBinExists("xdg-open") then
        return
    end
    if not checkIfBinExists("xdg-user-dir") then
        return
    end

    dt.print_error("Will try to export KML file now")

    local imageFoldername
    if ( dt.preferences.read("kml_export","CreateKMZ","bool") == true ) then
        if not checkIfBinExists("zip") then
            return
        end
        exportDirectory = dt.configuration.tmp_dir
        imageFoldername = ""
    else
        exportDirectory = dt.preferences.read("kml_export","ExportDirectory","string")

        -- Creates dir if not exsists
        imageFoldername = "files/"
        local mkdirCommand = "mkdir -p "..exportDirectory.."/"..imageFoldername
        coroutine.yield("RUN_COMMAND", mkdirCommand) 
    end


    -- Create the thumbnails
    for _,image in pairs(image_table) do
        if ((_.longitude and _.latitude) and 
            (_.longitude ~= 0 and _.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
            local path, filename, filetype = string.match(image, "(.-)([^\\/]-%.?([^%.\\/]*))$")
	    filename = string.upper(string.gsub(filename,"%.", "_"))
        
            -- convert -size 92x92 filename.jpg -resize 92x92 +profile "*" thumbnail.jpg
            --	In this example, '-size 120x120' gives a hint to the JPEG decoder that the image is going to be downscaled to 
            --	120x120, allowing it to run faster by avoiding returning full-resolution images to  GraphicsMagick for the 
            --	subsequent resizing operation. The '-resize 120x120' specifies the desired dimensions of the output image. It 
            --	will be scaled so its largest dimension is 120 pixels. The '+profile "*"' removes any ICM, EXIF, IPTC, or other
            --	profiles that might be present in the input and aren't needed in the thumbnail.

            local convertToThumbCommand = "convert -size 96x96 "..image.." -resize 92x92 -mattecolor \"#FFFFFF\" -frame 2x2 +profile \"*\" "..exportDirectory.."/"..imageFoldername.."thumb_"..filename..".jpg"
            -- USE coroutine.yield. It does not block the UI
            coroutine.yield("RUN_COMMAND", convertToThumbCommand)
            local concertCommand = "convert -size 438x438 "..image.." -resize 438x438 +profile \"*\" "..exportDirectory.."/"..imageFoldername..filename..".jpg"
            coroutine.yield("RUN_COMMAND", concertCommand)
        end

        -- delete the original image to not get into the kmz file
        os.remove(image)

        local pattern = "[/]?([^/]+)$"
        filmName = string.match(_.film.path, pattern)
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
    
    for image,_ in pairs(image_table) do
	filename = string.upper(string.gsub(image.filename,"%.", "_"))

	if ((image.longitude and image.latitude) and 
            (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
            kml_file = kml_file.."  <Placemark>\n"
	    if (image.title and image.title ~= "") then
              kml_file = kml_file.."    <name>"..image.title.."</name>\n"
            else
              kml_file = kml_file.."    <name>"..image.filename.."</name>\n"
            end
            
            kml_file = kml_file.."    <description>"..image.description.."</description>\n"
            
            kml_file = kml_file.."    <Style>\n"
            kml_file = kml_file.."      <IconStyle>\n"
            kml_file = kml_file.."        <Icon>\n"
            kml_file = kml_file.."          <href>"..imageFoldername.."thumb_"..filename..".jpg</href>\n" 
            kml_file = kml_file.."        </Icon>\n"
            kml_file = kml_file.."      </IconStyle>\n"
            kml_file = kml_file.."      <BalloonStyle>\n"
            kml_file = kml_file.."        <text><![CDATA[<img src=\""..imageFoldername..filename..".jpg\"><br/>]]></text>\n"
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
      
      for image,_ in spairs(image_table, function(t,a,b) return t[b] < t[a] end) do
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
        -- USE coroutine.yield. It does not block the UI
        local createKMZCommand = "zip --test --move --junk-paths "
        createKMZCommand = createKMZCommand .."\""..exportDirectory.."/"..exportKMZFilename.."\" "
        createKMZCommand = createKMZCommand .."\""..dt.configuration.tmp_dir.."/"..exportKMLFilename.."\" \""..dt.configuration.tmp_dir.."/"..imageFoldername.."\"*"
	coroutine.yield("RUN_COMMAND", createKMZCommand)
    end

-- Open the file with the standard programm    
    if ( dt.preferences.read("kml_export","OpenKmlFile","bool") == true ) then
	local kmlFileOpenCommand

        if ( dt.preferences.read("kml_export","CreateKMZ","bool") == true ) then
            kmlFileOpenCommand = "xdg-open "..exportDirectory.."/\""..exportKMZFilename.."\""
        else
            kmlFileOpenCommand = "xdg-open "..exportDirectory.."/\""..exportKMLFilename.."\""
	end
        coroutine.yield("RUN_COMMAND", kmlFileOpenCommand) 
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
