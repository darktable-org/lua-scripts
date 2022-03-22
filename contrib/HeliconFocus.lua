--[[
    This file is part of darktable,
    copyright (c) 2022 Christian Birzer

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    darktable is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
HeliconFocus

This script will add a new panel to integrate Helicon Focus stacking software into darktable
to be able to pass or export a bunch of images to Helicon Focus, reimport the result(s) and
optionally group the images and optionally copy and add tags to the imported image(s)

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
you must have Helicon Focus (commercial software) installed on your system.

USAGE
* Choose the executable of the Helicon Focus software in the preferences / Lua options / Helicon Focus executable
* Select two or more images
* Expand the Helicon Focus panel
* 'use original RAW': If checked, the script passes the file names of the selected RAW images to helicon focus. If
  unchecked, the images are exported to a temporary folder in tif format and these are used in Helicon Focus
* 'group': If checked, the selected source images and the imported results are grouped together and the first result image
  is set as group leader
* 'copy tags': If checked, all tags from all source images are copied to the resulting image
* 'new tags': Enter a comma seperated list of tags that shall be added to the resulting image on import.
* 'stack': Press this button to start export (if selected) and start the Helicon Focus application
* Stack you images in Helicon Focus. Save them. The default output path will be set to the path of your input files.
* Close Helicon Focus after saving to start the import of the resulting image(s).
* More than one image (e.g. different stacking settings) can be saved and all of them will be imported after closing Helicon Focus

WARNING
This script was only tested on Windows

]]

local dt = require 'darktable'
local du = require "lib/dtutils"
local df = require 'lib/dtutils.file'
local dsys = require 'lib/dtutils.system'

du.check_min_api_version("7.0.0", "HeliconFocus")

local script_data = {}
local temp

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again

local GUI = { --GUI Elements Table
  optionwidgets = {
    label_settings       = {},
    group                = {},
    use_original         = {},
    label_import_options = {},
    copy_tags            = {},
    add_tags_box         = {},
    add_tags_label       = {},
    add_tags             = {},
  },
  options = {},
  run = {},
}

local mod = 'module_HeliconFocus'
local os_path_seperator = '/'
if dt.configuration.running_os == 'windows' then os_path_seperator = '\\' end

-- Tell gettext where to find the .mo file translating messages for a particular domain
local gettext = dt.gettext
gettext.bindtextdomain('HDRMerge', dt.configuration.config_dir..'/lua/locale/')
local function _(msgid)
    return gettext.dgettext('HeliconFocus', msgid)
end

-- declare a local namespace and a couple of variables we'll need to install the module
local mE = {}
mE.event_registered = false  -- keep track of whether we've added an event callback or not
mE.module_installed = false  -- keep track of whether the module is module_installed

local function create_temp_directory()
  local temp_directory_name = os.tmpname()
  if dt.configuration.running_os == "windows" then
      temp_directory_name = dt.configuration.tmp_dir .. temp_directory_name -- windows os.tmpname() defaults to root directory
  end
  temp_directory_name = temp_directory_name.."darktable"

  df.mkdir( temp_directory_name )

  return temp_directory_name
end


--[[ export the given single image to tiff and write the file path of the tiff file to the
      file that is given in inputfilelist
      param:  image - source image to export
              tempdirname - path to the temporary directory where to write the exported files to
              inputfilelist - file that is read by Helicon Focus for the input images to process
]]
local function export_image( image, tempdirname, inputfilelist )
  local curr_image = image.path..os_path_seperator..image.filename
  dt.print_log( "exporting "..curr_image )

  local exporter = dt.new_format("tiff")
  exporter.bpp = 16

  local export_file = tempdirname..os_path_seperator..image.filename..".tif"
  exporter:write_image(image, export_file)
  dt.print_log( "exported file: "..export_file )
  inputfilelist:write( export_file..'\n' )
end

--[[ this is the companion function for export_image that does not export the
    given image but just writes the path of the original to the list of files
    param:  image - source image to use
            tempdirname - path to the temporary directory, not used here
            inputfilelist - file that is read by Helicon Focus for the input images to process
    ]]
local function take_original_raw( image, tempdirname, inputfilelist )
  local curr_image = image.path..os_path_seperator..image.filename
  inputfilelist:write( curr_image..'\n' )
end


--[[ read the file(s) written by helicon from the file thats name is given in outputfilelistname and
      import them to dt.
      param:  outputfilelistname - name of the file to which helicon wrote the names of the saved images
]]
local function reimport_images( outputfilelistname )
  local outputfilelist = io.open(outputfilelistname, 'r' )

  local images = {}
  if outputfilelist ~= nil then
    for exportedfilename in outputfilelist:lines() do
      dt.print_log( "helicon wrote file " .. exportedfilename )

      dt.print( _( "importing file " )..exportedfilename )
      image = dt.database.import( exportedfilename )
      images[ #images + 1 ] = image
    end

    outputfilelist:close()
  end
  return images
end

local function copy_tags( all_tags, image )

  local image_tags = dt.tags.get_tags( image )
    for _,tag in pairs( image_tags ) do
      if string.match( tag.name, 'darktable|' ) == nil then
        dt.print_log( "image: "..image.filename .. "  tag: "..tag.name )
        all_tags[ #all_tags + 1 ] = tag
      end
    end

    dt.print_log( "#all_tags: ".. #all_tags )
end

function insert_tags( image, tags )
  for _,tag in pairs( tags ) do
    dt.tags.attach(tag, image )
    dt.print_log( 'image: '..image.filename..'  adding tag ', tag.name )
  end
end

--removes spaces from the front and back of passed in text
local function clean_spaces(text)
  text = string.gsub(text,'^%s*','')
  text = string.gsub(text,'%s*$','')
  return text
end


local function add_additional_tags( image )
  local set_tag = GUI.optionwidgets.add_tags.text
  if set_tag ~= nil then -- add additional user-specified tags
    for tag in string.gmatch(set_tag, '[^,]+') do
      tag = clean_spaces(tag)
      tag = dt.tags.create(tag)
      dt.tags.attach(tag, image)
    end
  end
end

local function save_preferences()
  dt.preferences.write(mod, 'group', 'bool', GUI.optionwidgets.group.value )
  dt.preferences.write(mod, 'use_original', 'bool', GUI.optionwidgets.use_original.value )
  dt.preferences.write(mod, 'copy_tags', 'bool', GUI.optionwidgets.copy_tags.value )
  dt.preferences.write(mod, 'add_tags', 'string', GUI.optionwidgets.add_tags.text )
end

local function load_preferences()
  GUI.optionwidgets.group.value = dt.preferences.read(mod, 'group', 'bool' )
  GUI.optionwidgets.use_original.value = dt.preferences.read(mod, 'use_original', 'bool' )
  GUI.optionwidgets.copy_tags.value = dt.preferences.read(mod, 'copy_tags', 'bool' )
  -- temp = dt.preferences.read(mod, 'add_tags', 'string')
  -- if temp == '' then
  --   temp = nil
  -- end
  GUI.optionwidgets.add_tags.text = dt.preferences.read(mod, 'add_tags', 'string') -- temp

end

-- stop running export
local function stop_job(job)
  job.valid = false
end

-- main function
local function start_stacking()
  dt.print_log( "starting stacking..." )

  save_preferences()

  -- create a new progress_bar displayed in darktable.gui.libs.backgroundjobs
  job = dt.gui.create_job( _"exporting images...", true, stop_job )

  images = dt.gui.selection() --get selected images
  if #images < 2 then --ensure enough images selected
    dt.print(_('not enough images selected, select at least 2 images to stack'))
    return
  end

  local firstimagepath = ''
  local tempdirname = create_temp_directory()
  local inputfilelistname  = tempdirname..os_path_seperator..'inputfiles.txt'
  local outputfilelistname = tempdirname..os_path_seperator..'outfiles.txt'

  local inputfilelist = io.open(inputfilelistname, "w+")
  if not inputfilelist then
    dt.print_log( "inputfilelist error" )
    dt.print( _"error while writing list of input files" )
    df.rmdir( tempdirname )
    inputfilelist:close()
    return
  end

  local all_tags = {}
  local images_to_group = {}

  for i,image in pairs(images) do
    if GUI.optionwidgets.use_original.value == true then
      take_original_raw( image, tempdirname, inputfilelist )
    else
      export_image( image, tempdirname, inputfilelist )
    end
    copy_tags( all_tags, image )
    if i == 1 then
      firstimagepath = df.sanitize_filename( image.path )
    else
      -- remember image to group later:
      images_to_group[ #images_to_group ] = image
    end

    if dt.control.ending or not job.valid then
      dt.print_log( _"exporting images canceled!")
      inputfilelist:close()
      df.rmdir( tempdirname )
      return
    end

    -- update progress_bar
    job.percent = i / #images

    -- sleep for a short moment to give stop_job callback function a chance to run
    dt.control.sleep(10)
  end

  -- stop job and remove progress_bar from ui, but only if not alreay canceled
  if(job.valid) then
    job.valid = false
  end

  inputfilelist:close()

  local helicon_commandline = df.sanitize_filename( dt.preferences.read( mod, "HeliconFocusExe", "string" ) )

  helicon_commandline = helicon_commandline .. ' -i ' .. df.sanitize_filename( inputfilelistname )
                                            .. ' -o ' .. df.sanitize_filename( outputfilelistname )
                                            .. ' --preferred-output-path ' .. firstimagepath

  dt.print_log( 'preferred output path: '..firstimagepath )
  dt.print_log( 'temp directory: '..tempdirname )
  dt.print_log( 'outptufilelist: '..outputfilelistname )
  dt.print_log( 'commandline: '..helicon_commandline )

  dt.print_log( 'starting helicon' )
  resp = dsys.external_command( helicon_commandline )
  dt.print_log( 'helicon returned '..tostring( resp ) )

  if resp ~= 0 then
    dt.print( _'could not start HeliconFocus application' )
    df.rmdir( tempdirname )
    return
  end

  stackedimages = reimport_images( outputfilelistname )
  if #stackedimages == 0 then
    dt.print( _"no image to import" )
    df.rmdir( tempdirname )
    return
  end

  -- group source images:
  if GUI.optionwidgets.group.value ~= false then
    for _,imagetogroup in pairs( images_to_group ) do
      imagetogroup:group_with( images[ 1 ] )
    end
  end

  dt.print_log( 'group with: '..images[ 1 ].filename )
  -- group stacked images and add tags:
  for _,stackedimage in pairs( stackedimages ) do
    dt.print_log( 'stacking: '..stackedimage.filename.. ' to '..images[ 1 ].filename )

    -- group output images
    if GUI.optionwidgets.group.value ~= false then
      stackedimage:group_with( images[ 1 ] )
    end

    -- copy tags:
    if GUI.optionwidgets.copy_tags.value ~= false then
      insert_tags( stackedimage, all_tags )
    end

    add_additional_tags( stackedimage )

  end

  stackedimages[ 1 ]:make_group_leader()

  -- cleanup:
  df.rmdir( tempdirname )

end

GUI.optionwidgets.use_original = dt.new_widget('check_button' ) {
  label = _('use original RAW'),
  value = false,
  tooltip = _('stack original RAW images instead of exported TIFF'),
  clicked_callback = function(self)
    dt.print_log( "use_original: "..tostring( self.value ) )
  end,
  reset_callback = function(self)
    self.value = false
  end
}

GUI.optionwidgets.group = dt.new_widget('check_button') {
  label = _('group'),
  value = false,
  tooltip = _('group selected source images and imported result image(s) together'),
  clicked_callback = function(self)
    dt.print_log( "group: "..tostring( self.value ) )
  end,
  reset_callback = function(self)
    self.value = false
  end
}

GUI.optionwidgets.copy_tags = dt.new_widget('check_button') {
  label = _('copy tags'),
  value = false,
  tooltip = _('copy all tags from all source images to the imported result image(s)'),
  clicked_callback = function(self)
    dt.print_log( "copy tags: "..tostring( self.value ) )
  end,
  reset_callback = function(self) self.value = false end
}

GUI.optionwidgets.label_settings = dt.new_widget('section_label'){
  label = _('settings')
}

GUI.optionwidgets.label_import_options = dt.new_widget('section_label'){
  label = _('import options')
}

GUI.optionwidgets.add_tags_label = dt.new_widget('label') {
  label = _('new tags'),
  ellipsize = 'start',
  halign = 'start'
}

GUI.optionwidgets.add_tags = dt.new_widget('entry'){
  tooltip = _('Additional tags to be added on import. Seperate with commas, all spaces will be removed'),
  placeholder = _('Enter tags, seperated by commas'),
  editable = true
}

GUI.optionwidgets.add_tags_box = dt.new_widget('box') {
  orientation = 'horizontal',
  GUI.optionwidgets.add_tags_label,
  GUI.optionwidgets.add_tags
}

GUI.options = dt.new_widget('box') {
  orientation = 'vertical',
  GUI.optionwidgets.label_settings,
  GUI.optionwidgets.use_original,
  GUI.optionwidgets.group,
  GUI.optionwidgets.label_import_options,
  GUI.optionwidgets.copy_tags,
  GUI.optionwidgets.add_tags_box
}

GUI.run = dt.new_widget('button'){
  label = _('stack'),
  tooltip =_('run Helicon Focus to stack selected images'),
  clicked_callback = function() start_stacking() end
}

dt.preferences.register(
  mod, -- script
  "HeliconFocusExe",	-- name
	"file",	-- type
  _('Helicon Focus executable'),	-- label
	_('Select the executable HeliconFocus.exe'),	-- tooltip
  "" -- default,
)


load_preferences()

local function install_module()
  if not mE.module_installed then
    dt.register_lib( -- register  module
      'HeliconFocus_Lib', -- Module name
      _('Helicon Focus'), -- name
      true,   -- expandable
      true,   -- resetable
      {[dt.gui.views.lighttable] = {'DT_UI_CONTAINER_PANEL_RIGHT_CENTER', 99}},   -- containers
      dt.new_widget('box'){
        orientation = 'vertical',
        GUI.options,
        GUI.run

      },

      nil,-- view_enter
      nil -- view_leave
    )
  end
end


local function destroy()
  dt.gui.libs["HeliconFocus_Lib"].visible = false
end

local function restart()
  dt.gui.libs["HeliconFocus_Lib"].visible = true

end

if dt.gui.current_view().id == "lighttable" then -- make sure we are in lighttable view
  install_module()  -- register the lib
else
  if not mE.event_registered then -- if we are not in lighttable view then register an event to signal when we might be
    -- https://www.darktable.org/lua-api/index.html#darktable_register_event
    dt.register_event(
      "mdouleExample", "view-changed",  -- we want to be informed when the view changes
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then  -- if the view changes from darkroom to lighttable
          install_module()  -- register the lib
        end
      end
    )
    mE.event_registered = true  --  keep track of whether we have an event handler installed
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data