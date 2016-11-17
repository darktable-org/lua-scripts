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
darktable geoJSON export script

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* mkdir
* convert (ImageMagick)
* xdg-open
* xdg-user-dir

WARNING
This script is only tested with Linux

USAGE
* require this script from your main Lua file

]]
   
local dt = require "darktable"
require "official/yield"

local gettext = dt.gettext
dt.configuration.check_version(...,{3,0,0},{4,0,0})
	
-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("geoJSON_export",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("geoJSON_export", msgid)
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

local function create_geoJSON_file(storage, image_table, extra_data)

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

    dt.print_error("Will try to export geoJSON file now")

    local xportDirectory = dt.preferences.read("geoJSON_export","ExportDirectory","string")

    -- Creates dir if not exsists
    local imageFoldername = "files/"
    local mkdirCommand = "mkdir -p "..exportDirectory.."/"..imageFoldername
    dt.control.execute( mkdirCommand) 

    -- Create the thumbnails
    for image,exported_image in pairs(image_table) do
        if ((image.longitude and image.latitude) and 
            (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
            local path, filename, filetype = string.match(image, "(.-)([^\\/]-%.?([^%.\\/]*))$")
	    filename = string.upper(string.gsub(filename,"%.", "_"))
        
            -- convert -size 92x92 filename.jpg -resize 92x92 +profile "*" thumbnail.jpg
            --	In this example, '-size 120x120' gives a hint to the JPEG decoder that the image is going to be downscaled to 
            --	120x120, allowing it to run faster by avoiding returning full-resolution images to  GraphicsMagick for the 
            --	subsequent resizing operation. The '-resize 120x120' specifies the desired dimensions of the output image. It 
            --	will be scaled so its largest dimension is 120 pixels. The '+profile "*"' removes any ICM, EXIF, IPTC, or other
            --	profiles that might be present in the input and aren't needed in the thumbnail.

            local convertToThumbCommand = "convert -size 96x96 "..exported_image.." -resize 92x92 -mattecolor \"#FFFFFF\" -frame 2x2 +profile \"*\" "..exportDirectory.."/"..imageFoldername.."thumb_"..filename..".jpg"
            dt.control.execute( convertToThumbCommand)
            local concertCommand = "convert -size 438x438 "..exported_image.." -resize 438x438 +profile \"*\" "..exportDirectory.."/"..imageFoldername..filename..".jpg"
            dt.control.execute( concertCommand)
        end

        -- delete the original image to not get into the kmz file
        os.remove(image)

        local pattern = "[/]?([^/]+)$"
        filmName = string.match(image.film.path, pattern)
    end

    local exportgeoJSONFilename    = filmName..".geoJSON"
    local exportMapBoxHTMLFilename = filmName..".html"

    -- Create the geoJSON file
    local geoJSON_file = [[
{ 
    "type": "FeatureCollection",
    "features": [
]]
  
    for image,exported_image in pairs(image_table) do
	filename = string.upper(string.gsub(image.filename,"%.", "_"))

	if ((image.longitude and image.latitude) and 
            (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
            geoJSON_file = geoJSON_file..
[[    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
]]
            geoJSON_file = geoJSON_file.."              \"coordinates\": ["..string.gsub(tostring(image.longitude),",", ".")..","..string.gsub(tostring(image.latitude),",", ".").."]\n"
            geoJSON_file = geoJSON_file..
[[    },
      "properties": {
        "title": "]]..image.title..[[",
        "description": "]]..image.description..[[",
        "image": "]]..imageFoldername..filename..[[.jpg",
        "icon": {
          "iconUrl": "]]..imageFoldername.."thumb_"..filename..[[.jpg",
          "iconSize": [96, 65],
          "iconAnchor": [48, 32],
          "popupAnchor": [0, -32],
          "className": "dot"
        }
      }
    }
    ,]]
        end
    end
    
    geoJSON_file = geoJSON_file:sub(0,geoJSON_file:len()-1)
    geoJSON_file = geoJSON_file..
[[
]
}
]]


    --HTML
    if ( dt.preferences.read("geoJSON_export","CreateMapBoxHTMLFile","bool") == true ) then
        local mapBoxKey = dt.preferences.read("geoJSON_export","mapBoxKey","string")
        local mapBoxHTML_file = [[
<!DOCTYPE html>
<html>
<head>
  <meta charset=utf-8 />
  <title>2014-05-31 Rieselfelder</title>
  <script src='https://api.tiles.mapbox.com/mapbox.js/v2.2.4/mapbox.js'></script>
  <link href='https://api.tiles.mapbox.com/mapbox.js/v2.2.4/mapbox.css' rel='stylesheet' />
  <style>
    body { margin:0; padding:0; }
    .map { position:absolute; top:0; bottom:0; width:100%; }
  </style>
</head>
<body>
<div id='map-tooltips-js' class='map'> </div>

<script>
  L.mapbox.accessToken = ']]..mapBoxKey..[[';
  var mapTooltipsJS = L.mapbox.map('map-tooltips-js', 'mapbox.light')
    .setView([0,0], 5);

  var myLayer = L.mapbox.featureLayer()
      .loadURL(']]..exportgeoJSONFilename..[[')      
      .addTo(mapTooltipsJS);

  // Set a custom icon on each marker based on feature properties.
  myLayer.on('layeradd', function(e) {
    var marker = e.layer,
      feature = marker.feature;
    marker.setIcon(L.icon(feature.properties.icon));
    var content = '<h2>'+ feature.properties.title+'<\/h2>' + '<p>'+ feature.properties.description+'<\/p>' + '<img src="'+feature.properties.image+'" alt="">';
    marker.bindPopup(content,{minWidth: 457});
  });
  // Center on click
  myLayer.on('click', function(e) {
     mapTooltipsJS.panTo(e.layer.getLatLng());
  });

  // https://www.mapbox.com/mapbox.js/example/v1.0.0/fit-map-to-markers/
  // Especially with dynamic data, it's useful to automatically fit all markers
  // in the map bounds instead of guessing and checking center and zoom values

  // Since this layer is loaded with the asynchronous method loadURL, that uses
  // AJAX in the background, we wait for all of the markers to be loaded by
  // waiting for the ready event. If you don't load your markers with an async
  // method and instead set them with setGeoJSON or similar, you don't need
  // to do this.
  myLayer.on('ready', function() {
    // featureLayer.getBounds() returns the corners of the furthest-out markers,
    // and map.fitBounds() makes sure that the map contains these.
    mapTooltipsJS.fitBounds(myLayer.getBounds());
  });

  // Lines
  // https://www.mapbox.com/mapbox.js/example/v1.0.0/line-marker/
  myLayer.on('ready', function(e) {
    var line = [];

    this.eachLayer(function(marker) {
      line.push(marker.getLatLng());
    });

    var polyline_options = {
      color: '#FF0000'
    };

    var polyline = L.polyline(line, polyline_options).addTo(mapTooltipsJS);
  });

  
</script>
</body>
</html>
]]

        local file = io.open(exportDirectory.."/"..exportMapBoxHTMLFilename, "w")
        file:write(mapBoxHTML_file)
        file:close()
    end

    local file = io.open(exportDirectory.."/"..exportgeoJSONFilename, "w")
    file:write(geoJSON_file)
    file:close()

    dt.print("geoJSON file created in "..exportDirectory)

-- Open the file with the standard programm    
    if ( dt.preferences.read("geoJSON_export","OpengeoJSONFile","bool") == true ) then
        local geoJSONFileOpenCommand
        geoJSONFileOpenCommand = "xdg-open "..exportDirectory.."/\""..exportgeoJSONFilename.."\""
        dt.control.execute( geoJSONFileOpenCommand) 
    end


end

-- Preferences
dt.preferences.register("geoJSON_export",
	"CreateMapBoxHTMLFile",
	"bool",
	_("geoJSON export: Create an additional HTML file"),
	_("Creates a HTML file, that loads the geoJASON file. (Needs a MapBox key"),
	false )
dt.preferences.register("geoJSON_export",
	"mapBoxKey",
	"string",
	_("geoJSON export: MapBox Key"),
	_("https://www.mapbox.com/studio/account/tokens"),
	'' )
dt.preferences.register("geoJSON_export",
	"OpengeoJSONFile",
	"bool",
	_("geoJSON export: Open geoJSON file after export"),
	_("Opens the geoJSON file after the export with the standard program for geoJSON files"),
	false )

local handle = io.popen("xdg-user-dir DESKTOP")
local result = handle:read()
handle:close()
dt.preferences.register("geoJSON_export",
	"ExportDirectory",
	"directory",
	_("geoJSON export: Export directory"),
	_("A directory that will be used to export the geoJSON files"),
	result )

-- Register
dt.register_storage("geoJSON_export", "geoJSON Export", nil, create_geoJSON_file)
