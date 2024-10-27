--[[
  This file is part of darktable,
  Copyright 2018 by Tobias Jakobs.
  Copyright 2018 by Erik Augustin.

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
* zip (at the moment Linux only and only if you create KMZ files)
* magick (ImageMagick)
* xdg-user-dir (Linux)

WARNING
This script is only tested with Linux

USAGE
* require this script from your main Lua file
* when choosing file format, pick JPEG or PNG as Google Earth doesn't support other formats

]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local ds = require "lib/dtutils.string"
local dsys = require "lib/dtutils.system"

local gettext = dt.gettext.gettext

local PS = dt.configuration.running_os == "windows" and "\\" or "/"

du.check_min_api_version("7.0.0", "kml_export") 

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("kml export"),
  purpose = _("export KML/KMZ data to a file"),
  author = "Tobias Jakobs",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/kml_export"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function show_status(storage, image, format, filename, number, total, high_quality, extra_data)
  dt.print(string.format(_("export image %i/%i"), number, total))
end

-- Add duplicate index to filename
-- image.filename does not have index, exported_image has index
function addDuplicateIndex( index, filename )
  if index > 0 then
    filename = filename.."_"
    if index < 10 then
      filename = filename.."0"
    end
    filename = filename..index
  end

  return filename 
end

local function create_kml_file(storage, image_table, extra_data)

  local magickPath 
  if dt.configuration.running_os == "linux" then
    magickPath = 'convert'
  else
    magickPath = dt.preferences.read("kml_export","magickPath","string")
  end

  if not df.check_if_bin_exists(magickPath) then
    dt.print_error("magick not found")
    return
  end
  if dt.configuration.running_os == "linux" then
    if not df.check_if_bin_exists("xdg-user-dir") then
      dt.print_error("xdg-user-dir not found")
      return
    end
  end
  dt.print_log("Will try to export KML file now")

  local imageFoldername
  if ( dt.preferences.read("kml_export","CreateKMZ","bool") == true 
       and dt.configuration.running_os == "linux") then
    if not df.check_if_bin_exists("zip") then
      dt.print_error("zip not found")
      return
    end
    exportDirectory = dt.configuration.tmp_dir
    imageFoldername = ""
  else
    exportDirectory = dt.preferences.read("kml_export","ExportDirectory","string")
    -- Creates dir if not exsists
    imageFoldername = "files"..PS
    df.mkdir(df.sanitize_filename(exportDirectory..PS..imageFoldername))
  end

  -- Create the thumbnails
  for image,exported_image in pairs(image_table) do
    if ((image.longitude and image.latitude) and
      (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
       ) then
      local path, filename, filetype = string.match(exported_image, "(.-)([^\\/]-%.?([^%.\\/]*))$")
      filename = string.upper(string.gsub(filename,"%.%w*", ""))

      -- magick -size 92x92 filename.jpg -resize 92x92 +profile "*" thumbnail.jpg
      -- In this example, '-size 120x120' gives a hint to the JPEG decoder that the image is going to be downscaled to
      -- 120x120, allowing it to run faster by avoiding returning full-resolution images to  GraphicsMagick for the
      -- subsequent resizing operation. The '-resize 120x120' specifies the desired dimensions of the output image. It
      -- will be scaled so its largest dimension is 120 pixels. The '+profile "*"' removes any ICM, EXIF, IPTC, or other
      -- profiles that might be present in the input and aren't needed in the thumbnail.

      local convertToThumbCommand = ds.sanitize(magickPath) .. " -size 96x96 " .. exported_image .. " -resize 92x92 -mattecolor \"#FFFFFF\" -frame 2x2 +profile \"*\" " .. exportDirectory .. PS .. imageFoldername .. "thumb_" .. filename .. ".jpg"

      if (exported_image ~= exportDirectory..PS..imageFoldername..filename.."."..filetype) then
        df.file_copy(exported_image, exportDirectory..PS..imageFoldername..filename.."."..filetype)
	    end
      dsys.external_command(convertToThumbCommand)

    else
      -- Remove exported image if it has no GPS data
      os.remove(exported_image)
    end

    local pattern = "[/]?([^/]+)$"
    filmName = string.match(image.film.path, pattern)

    -- Strip accents from the filename, because GoogleEarth can't open them
    -- https://github.com/darktable-org/lua-scripts/issues/54
    filmName = ds.strip_accents(filmName)

    -- Remove chars we don't like to have in filenames
    filmName = string.gsub(filmName, [[\]], "") 
    filmName = string.gsub(filmName, [[/]], "")
    filmName = string.gsub(filmName, [[:]], "") 
    filmName = string.gsub(filmName, [["]], "")
    filmName = string.gsub(filmName, "<", "") 
    filmName = string.gsub(filmName, ">", "") 
    filmName = string.gsub(filmName, "|", "")
    filmName = string.gsub(filmName, "*", "")
    filmName = string.gsub(filmName, "?", "")
    filmName = string.gsub(filmName,'[.]', "") -- At least Windwows has problems with the "." and the start command
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
    -- Handle duplicates
    filename = addDuplicateIndex( image.duplicate_index, filename )
    -- Extract extension from exported image (user can choose JPG or PNG), e.g DSC9784.JPG -> .JPG
    extension = string.match(exported_image,"%.%w*$")

    if ((image.longitude and image.latitude) and
      (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
       ) then
      kml_file = kml_file.."  <Placemark>\n"

      local image_title, image_description
      if (image.title and image.title ~= "") then
        image_title = ds.escape_xml_characters(image.title)
      else
        image_title = filename..extension
      end
      -- Characters should not be escaped in CDATA, but we are using HTML fragment, so we must escape them
      image_description = ds.escape_xml_characters(image.description)

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

    for image,exported_image in du.spairs(image_table, function(t,a,b) return b.exif_datetime_taken > a.exif_datetime_taken end) do
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

  local file = io.open(exportDirectory..PS..exportKMLFilename, "w")

  file:write(kml_file)
  file:close()

  dt.print("KML file created in "..exportDirectory)

  -- Compress the files to create a KMZ file
  if ( dt.preferences.read("kml_export","CreateKMZ","bool") == true 
       and dt.configuration.running_os == "linux") then
    exportDirectory = dt.preferences.read("kml_export","ExportDirectory","string")

    local createKMZCommand = "zip --test --move --junk-paths "
    createKMZCommand = createKMZCommand .."\""..exportDirectory..PS..exportKMZFilename.."\" "           -- KMZ filename
    createKMZCommand = createKMZCommand .."\""..dt.configuration.tmp_dir..PS..exportKMLFilename.."\" "  -- KML file

    for image,exported_image in pairs(image_table) do
      if ((image.longitude and image.latitude) and
        (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
         ) then
        local filename = string.upper(string.gsub(image.filename,"%.%w*", ""))
        -- Handle duplicates
        filename = addDuplicateIndex( image.duplicate_index, filename )

        createKMZCommand = createKMZCommand .."\""..dt.configuration.tmp_dir..PS..imageFoldername.."thumb_"..filename..".jpg\" " -- thumbnails
        createKMZCommand = createKMZCommand .."\""..exported_image.."\" "  -- images
      end
    end

     dt.control.execute(createKMZCommand)
  end

  -- Open the file with the standard programm
  if ( dt.preferences.read("kml_export","OpenKmlFile","bool") == true ) then
    local path

    if ( dt.preferences.read("kml_export","CreateKMZ","bool") == true
	     and dt.configuration.running_os == "linux") then
      path = exportDirectory..PS..exportKMZFilename
    else
      path = exportDirectory..PS..exportKMLFilename
    end

    dsys.launch_default_app(df.sanitize_filename(path))
  end

end

local function destroy()
  dt.destroy_storage("kml_export")
end

-- Preferences
if dt.configuration.running_os == "windows" then
  dt.preferences.register("kml_export",
    "OpenKmlFile",
    "bool",
    _("KML export: Open KML file after export"),
    _("opens the KML file after the export with the standard program for KML files"),
    false )
else
  dt.preferences.register("kml_export",
    "OpenKmlFile",
    "bool",
    _("KML export: open KML/KMZ file after export"),
    _("opens the KML file after the export with the standard program for KML files"),
    false )
end

local defaultDir = ''
if dt.configuration.running_os == "windows" then
  defaultDir = os.getenv("USERPROFILE")
elseif dt.configuration.running_os == "macos" then
  defaultDir =  os.getenv("HOME")
else
  local handle = io.popen("xdg-user-dir DESKTOP")
  defaultDir = handle:read()
  handle:close()
end


dt.preferences.register("kml_export",
  "ExportDirectory",
  "directory",
  _("KML export: export directory"),
  _("a directory that will be used to export the KML/KMZ files"),
  defaultDir )

if dt.configuration.running_os ~= "linux" then  
  dt.preferences.register("kml_export", 
    "magickPath",	-- name
	"file",	-- type
	_("KML export: ImageMagick binary location"),	-- label
	_("install location of magick[.exe], requires restart to take effect"),	-- tooltip
	"magick")	-- default
end  
  
dt.preferences.register("kml_export",
  "CreatePath",
  "bool",
  _("KML export: connect images with path"),
  _("connect all images with a path"),
  false )

if dt.configuration.running_os == "linux" then  
  dt.preferences.register("kml_export",
    "CreateKMZ",
    "bool",
    _("KML export: create KMZ file"),
    _("compress all imeges to one KMZ file"),
    true )
end

-- Register
if dt.configuration.running_os == "windows" then
  dt.register_storage("kml_export", _("KML export"), nil, create_kml_file)
else
  dt.register_storage("kml_export", _("KML/KMZ export"), nil, create_kml_file)
end

script_data.destroy = destroy

return script_data

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
