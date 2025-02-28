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

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* exiftool

LICENSE
GPLv2

]]

local darktable = require "darktable"
local du = require "lib/dtutils"
local filelib = require "lib/dtutils.file"
local syslib = require "lib/dtutils.system"

du.check_min_api_version("7.0.0", "autostyle") 

local gettext = darktable.gettext.gettext

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

local have_not_printed_config_message = true

script_data.metadata = {
  name = _("auto style"),
  purpose = _("automatically apply a style based on image EXIF tag"),
  author = "Marc Cousin <cousinmarc@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/autostyle/"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- run command and retrieve stdout
local function get_stdout(cmd)
  -- Open the command, for reading
  local fd = assert(io.popen(cmd, 'r'))
  darktable.control.read(fd)
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

-- Retrieve the attribute through exiftool
local function exiftool_attribute(path, attr)
  local cmd = "exiftool -" .. attr .. " '" .. path .. "'";
  local exifresult = get_stdout(cmd)
  local attribute = string.match(exifresult, ": (.*)")
  if (attribute == nil) then
    darktable.print_error( "Could not find the attribute " .. attr .. " using the command: <" .. cmd .. ">")
    -- Raise an error to the caller
    error( "Could not find the attribute " .. attr .. " using the command: <" .. cmd .. ">");
  end
  --  darktable.print_error("Returning attribute: " .. attribute)
  return attribute
end

-- Apply the style to an image, if it matches the tag condition
local function autostyle_apply_one_image (image)

  local pref = darktable.preferences.read("autostyle", "exif_tag", "string")

  if pref and string.len(pref) >= 6 then
  -- We need the tag, the value and the style_name provided from the configuration string
    local tag, value, style_name = string.match(pref, "(%g+)%s*=%s*([%g ]-)%s*=>%s*(%g+)")

    -- check they all exist (correct syntax)
    if (not tag) then
  	  darktable.print(string.format(_("EXIF tag not found in %s"), pref))
  	  return 0
    end
    if (not value) then
  	  darktable.print(string.format(_("value to match not found in %s"), pref))
  	  return 0
    end
    if (not style_name) then
  	  darktable.print(string.format(_("style name not found in %s"), pref))
  	  return 0
    end
    if not filelib.check_if_bin_exists("exiftool") then
  	  darktable.print(_("can't find exiftool"))
      return 0
    end
  	
  	
    -- First find the style (we have its name)
    local styles = darktable.styles
    local style
    for _, s in ipairs(styles) do
  	  if s.name == style_name then
  		  style = s
  	  end
    end
    if (not style) then
  	  darktable.print(string.format(_("style not found for autostyle: %s"), style_name))
      return 0
    end

    -- Apply the style to image, if it is tagged
    local ok, auto_dr_attr = pcall(exiftool_attribute, image.path .. '/' .. image.filename,tag)
    --darktable.print_error("dr_attr:" .. auto_dr_attr)
    -- If the lookup fails, stop here
    if (not ok) then
      darktable.print(string.format(_("couldn't get attribute %s from exiftool's output"), auto_dr_attr))
      return 0
    end
    if auto_dr_attr == value then
  	  darktable.print_log("Image " .. image.filename .. ": autostyle automatically applied " .. pref)
  	  darktable.styles.apply(style,image)
  	  return 1
    else
  	  darktable.print_log("Image " .. image.filename .. ": autostyle not applied, exif tag " .. pref  .. " not matched: " .. auto_dr_attr)
  	  return 0
    end
  elseif have_not_printed_config_message then
    have_not_printed_config_message = false
    darktable.print(string.format(_("%s is not configured, please configure the preference in Lua options"), script_data.metadata.name))
  end
end 


-- Receive the event triggered
local function autostyle_apply_one_image_event(event,image)
  autostyle_apply_one_image(image)
end

local function autostyle_apply(shortcut)
  local images = darktable.gui.action_images
  local images_processed = 0
  local images_submitted = 0
  for _,image in pairs(images) do
    images_submitted = images_submitted + 1
    images_processed = images_processed + autostyle_apply_one_image(image)
  end
  darktable.print(string.format(_("applied auto style to %d out of %d image(s)"), images_processed, images_submitted))
end

local function destroy()
  darktable.destroy_event("autostyle", "shortcut")
  darktable.destroy_event("autostyle", "post-import-image")
end

-- Registering events
darktable.register_event("autostyle", "shortcut", autostyle_apply,
       _("apply your chosen style from exiftool tags"))

darktable.preferences.register("autostyle", "exif_tag", "string", 
                              string.format("%s: EXIF_tag=value=>style", script_data.metadata.name),
                              _("apply a style automatically if an EXIF tag matches value, find the tag with exiftool"), "")

darktable.register_event("autostyle", "post-import-image",
  autostyle_apply_one_image_event)


script_data.destroy = destroy
return script_data
