--[[
Autostyle
Automatically apply a given style when an exif tag is present in the file. This tagged is checked with exiftool, in order to be able to match very exotic tags.
I wrote this initially to be able to apply a style to compensate for Auto-DR from my Fujifilm camera

AUTHOR
Marc Cousin (cousinmarc@gmail.com)

INSTALATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR
is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "autostyle"

USAGE
* set the exif configuration string in your lua configuration
  mine, for instance, is AutoDynamicRange=200%=>DR200"
  meaning that I automatically want to apply my DR200 style on all
  images where exiftool returns '200%' for the AutoDynamicRange tag
* if you want to be able to apply it manually to already imported
  images, define a shortcut (lua shortcuts). As I couldn't find an event for
  when a development is removed, so the autostyle won't be applied again, 
  this shortcut is also helpful then
* import your images, or use the shortcut on your already imported images
* To determine which tag you want, list all tags with exiftool:
  exiftool -j XE021351.RAF, and find the one you want to use
  you can check it with 
  > exiftool -AutoDynamicRange XE021351.RAF
  Auto Dynamic Range              : 200%


LICENSE
GPLv2

]]

local darktable = require "darktable"


-- Forward declare the functions
local autostyle_apply_one_image,autostyle_apply_one_image_event,autostyle_apply,exiftool_attribute,capture

-- Tested it with darktable 1.6.1 and darktable git from 2014-01-25
darktable.configuration.check_version(...,{2,0,2},{2,1,0},{3,0,0})

-- Receive the event triggered
function autostyle_apply_one_image_event(event,image)
  autostyle_apply_one_image(image)
end

-- Apply the style to an image, if it matches the tag condition
function autostyle_apply_one_image (image)
  -- We need the tag, the value and the style_name provided from the configuration string
  local tag,value,style_name=string.match(darktable.preferences.read("autostyle","exif_tag","string"),"(%g+)%s*=%s*(%g+)%s*=>%s*(%g+)")

  -- check they all exist (correct syntax)
  if (not tag) then
	  darktable.print("EXIF TAG not found in " .. darktable.preferences.read("autostyle","exif_tag","string"))
	  return
  end
  if (not value) then
	  darktable.print("value to match not found in " .. darktable.preferences.read("autostyle","exif_tag","string"))
	  return
  end
  if (not style_name) then
	  darktable.print("style name not found in " .. darktable.preferences.read("autostyle","exif_tag","string"))
	  return
  end

  -- First find the style (we have its name)
  local styles= darktable.styles
  local style
  for _,s in ipairs(styles) do
	  if s.name == style_name then
		  style=s
	  end
  end
  if (not style) then
	  darktable.print("style not found for autostyle: " .. style_name)
  end

  -- Apply the style to image, if it is tagged
  local ok,auto_dr_attr= pcall(exiftool_attribute,image.path .. '/' .. image.filename,tag)
  -- If the lookup fails, stop here
  if (not ok) then
    return
  end
  if auto_dr_attr==value then
--	  darktable.print("Image " .. image.filename .. ": autostyle automatically applied " .. darktable.preferences.read("autostyle","exif_tag","string") )
	  darktable.styles.apply(style,image)
--  else
--	  darktable.print("Image " .. image.filename .. ": autostyle not applied, exif tag " .. darktable.preferences.read("autostyle","exif_tag","string")  .. " not matched: " .. auto_dr_attr)
  end
end 


function autostyle_apply( shortcut)
  local images = darktable.gui.action_images
  for _,image in pairs(images) do
    autostyle_apply_one_image(image)
  end
end

-- Retrieve the attribute through exiftool
function exiftool_attribute(path,attr)
  local cmd="exiftool -" .. attr .. " '" ..path.. "'";
  local exifresult=get_stdout(cmd)
  local attribute=string.match(exifresult,": (.*)")
  if (attribute == nil) then
    darktable.print( "Could not find the attribute " .. attr .. " using the command: <" .. cmd .. ">")
    -- Raise an error to the caller
    error( "Could not find the attribute " .. attr .. " using the command: <" .. cmd .. ">");
  end
  return attribute
end

-- run command and retrieve stdout
function get_stdout(cmd)
  -- Open the command, for reading
  local fd = assert(io.popen(cmd, 'r'))
  -- yield to other lua threads until data is ready to be read
  coroutine.yield("FILE_READABLE",fd)
  -- slurp the whole file
  local data = assert(fd:read('*a'))

  fd:close()
  -- Replace carriage returns and linefeeds with spaces
  data = string.gsub(data, '[\n\r]+', ' ')
  -- Remove spaces at the beginning
  data = string.gsub(data, '^%s+', '')
  -- Remove spaces at the end
  data = string.gsub(data, '%s+$', '')
  return data
end

-- Registering events
darktable.register_event("shortcut",autostyle_apply,
       "Apply your chosen style from exiftool tags")

darktable.preferences.register("autostyle","exif_tag","string","Autostyle: EXIF_tag=value=>style","apply a style automatically if an EXIF_tag matches value. Find the tag with exiftool","")

darktable.register_event("post-import-image",autostyle_apply_one_image_event)


