--[[HDRMerge plugin for darktable

  copyright (c) 2018  Kevin Ertel
  
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

--[[About this Plugin
This plugin adds the module 'HDRMerge' to darktable's lighttable view

----REQUIRED SOFTWARE----
HDRMerge ver. 4.5 or greater

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file in to your 'lua/contrib' folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in
On the initial startup go to darktable settings > lua options and set your executable paths and other preferences, then restart darktable

Select bracketed images and press the Run HDRMerge button. The resulting DNG will be auto-imported into darktable.
Additional tags or style can be applied on auto import as well, if you desire.

Base Options:
Select your desired BPS (bits per sample and Embedded Preview Size. 

Batch Options:
Select if you want to run in batch mode or not
Select the gap, in seconds, between images for auto grouping in batch mode

See HDRMerge manual for further detail: http://jcelaya.github.io/hdrmerge/documentation/2014/07/11/user-manual.html

Auto-import Options:
Select a style, whether you want tags to be copied from the original, and any additional tags you desire added when the new image is auto-imported
]]

local dt = require 'darktable'
local du = require "lib/dtutils"
local df = require 'lib/dtutils.file'
local dsys = require 'lib/dtutils.system'

du.check_min_api_version("7.0.0", "HDRmerge") 

-- Tell gettext where to find the .mo file translating messages for a particular domain
local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("HDR merge"),
  purpose = _("merge bracketed images into an HDR DNG image"),
  author = "Kevin Ertel",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/HDRmerge"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them


local mod = 'module_HDRMerge'
local os_path_seperator = '/'
if dt.configuration.running_os == 'windows' then os_path_seperator = '\\' end
local CURR_API_STRING = dt.configuration.api_version_string

local temp
local HDRM = { --HDRMerge Program Table
  name = 'HDRMerge',
  bin = '',
  first_run = true,
  install_error = false,
  arg_string = '',
  images_string = '',
  args = {
    bps         = {text = '-b ', style = 'integer'},
    size        = {text = '-p ', style = 'string'},
    batch       = {text = '-B ', style = 'bool'},
    gap         = {text = '-g ', style = 'integer'}
  }
}
local GUI = { --GUI Elements Table
  HDR = {
    bps         ={},
    size        ={},
    batch       ={},
    gap         ={}
  },
  Target = {
    style       ={},
    copy_tags   ={},
    add_tags    ={}
  },
  run = {},
  stack = {},
  options = {},
  exes = {
    HDRMerge = {},
    update = {},
  }
}

HDRM.module_installed = false
HDRM.event_registered = false


--Detect User Styles--
local styles = dt.styles
local styles_count = 1 -- 'none' = 1
for _,i in pairs(dt.styles) do
  if type(i) == 'userdata' then styles_count = styles_count + 1 end
end

local function InRange(test, low, high) --tests if test value is within range of low and high (inclusive)
  if test >= low and test <= high then
    return true
  else
    return false
  end
end

local function GetFileName(full_path) --Parses a full path (path/filename_identifier.extension) into individual parts
--[[Input: Folder1/Folder2/Folder3/Img_0001.CR2
    
  Returns:
  path: Folder1/Folder2/Folder3/
  filename: Img_0001
  identifier: 0001
  extension: .CR2
  
  EX:
  path_1, file_1, id_1, ext_1 = GetFileName(full_path_1)
  ]]
  local path = string.match(full_path, '.*[\\/]')
  local filename = string.gsub(string.match(full_path, '[%w-_]*%.') , '%.' , '' ) 
  local identifier = string.match(filename, '%d*$')
  local extension = string.match(full_path, '%.%w*')
  return path, filename, identifier, extension
end

local function CleanSpaces(text) --removes spaces from the front and back of passed in text
  text = string.gsub(text,'^%s*','')
  text = string.gsub(text,'%s*$','')
  return text
end

local function BuildExecuteCmd(prog_table) --creates a program command using elements of the passed in program table
  local result = CleanSpaces(prog_table.bin)..' '..CleanSpaces(prog_table.arg_string)..' '..CleanSpaces(prog_table.images_string)
  return result
end

local function PreCall(prog_tbl) --looks to see if this is the first call, if so checks to see if program is installed properly
  for _,prog in pairs(prog_tbl) do
    if prog.first_run then
      prog.bin = df.check_if_bin_exists(prog.name)
      if not prog.bin then 
        prog.install_error = true
        dt.preferences.write(mod, 'bin_exists', 'bool', false)
      else
        prog.bin = CleanSpaces(prog.bin)
      end
      prog.first_run = false
    end
  end
  if not dt.preferences.read(mod, 'bin_exists', 'bool') then
    GUI.stack.active = 2
    dt.print(_('please update you binary location'))
  end
end

local function ExeUpdate(prog_tbl)
  dt.preferences.write(mod, 'bin_exists', 'bool', true)
  for _,prog in pairs(prog_tbl) do
    dt.preferences.write('executable_paths', prog.name, 'string', GUI.exes[prog.name].value)
    prog.bin = df.check_if_bin_exists(prog.name)
    if not prog.bin then 
      prog.install_error = true
      dt.preferences.write(mod, 'bin_exists', 'bool', false)
    else
      prog.bin = CleanSpaces(prog.bin)
    end
    prog.first_run = false
  end
  if dt.preferences.read(mod, 'bin_exists', 'bool') then
    GUI.stack.active = 1
    dt.print(_('update successful'))
  else
    dt.print(_('update unsuccessful, please try again'))
  end
end

local function UpdateActivePreference() --sliders & entry boxes do not have a click/changed callback, so their values must be saved to the active preference
  temp = GUI.HDR.gap.value
  dt.preferences.write(mod, 'active_gap', 'integer', temp)
  temp = GUI.Target.add_tags.text
  dt.preferences.write(mod, 'active_add_tags', 'string', temp)
end

local function main()
  PreCall({HDRM}) --check if furst run then check if install OK
  if HDRM.install_error then
    dt.print_error('HDRMerge install issue')
    dt.print(_('HDRMerge install issue, please ensure the binary path is correct'))
    return
  end
  images = dt.gui.selection() --get selected images
  if #images < 2 then --ensure enough images selected
    dt.print(_('not enough images selected, select at least 2 images to merge'))
    return
  end
  
  UpdateActivePreference() --save current gui elements to active preference so those values will be pre-loaded at next startup
  
  --create image string and output path
  HDRM.images_string = ''
  local out_path = ''
  local smallest_id = math.huge
  local smallest_name = ''
  local largest_id  = 0
  local source_raw = {}
  for _,image in pairs(images) do --loop to concat the images string, also track the image indexes for use in creating the final image name (eg; IMG_1034-1037.dng)
    local curr_image = image.path..os_path_seperator..image.filename
    HDRM.images_string = HDRM.images_string..df.sanitize_filename(curr_image)..' '
    out_path = image.path
    _unused, source_name, source_id = GetFileName(image.filename)
    source_id = tonumber(source_id) or 0
    if source_id < smallest_id then 
      smallest_id = source_id
      smallest_name = source_name
      source_raw = image
    end
    if source_id > largest_id then largest_id = source_id end
  end
  out_path = out_path..os_path_seperator..smallest_name..'-'..largest_id..'.dng'
  out_path = df.create_unique_filename(out_path)
  
  --create argument string
  HDRM.arg_string = HDRM.args.bps.text..GUI.HDR.bps.value..' '..HDRM.args.size.text..GUI.HDR.size.value..' '
  if GUI.HDR.batch.value then 
    HDRM.arg_string = HDRM.arg_string..HDRM.args.batch.text..HDRM.args.gap.text..math.floor(GUI.HDR.gap.value)..' -a'
  else
    HDRM.arg_string = HDRM.arg_string..'-o '..df.sanitize_filename(out_path)
  end
  
  -- create run command and execute
  local run_cmd = BuildExecuteCmd(HDRM)
  resp = dsys.external_command(run_cmd)
  
  if resp == 0 and not GUI.HDR.batch.value then
    local imported = dt.database.import(out_path) -- import the new file
    if GUI.Target.style.selected > 1 then -- apply selected style
      local set_style = styles[GUI.Target.style.selected - 1]
      dt.styles.apply(set_style , imported)
    end
    if GUI.Target.copy_tags.value then -- copy tags from the original file (ignore 'darktable' generated tags)
      local all_tags = dt.tags.get_tags(source_raw) 
      for _,tag in pairs(all_tags) do
        if string.match(tag.name, 'darktable|') == nil then dt.tags.attach(tag, imported) end
      end
    end
    local set_tag = GUI.Target.add_tags.text
    if set_tag ~= nil then -- add additional user-specified tags
      for tag in string.gmatch(set_tag, '[^,]+') do
        tag = CleanSpaces(tag)
        tag = dt.tags.create(tag)
        dt.tags.attach(tag, imported) 
      end
    end
    dt.print(_('HDRMerge completed successfully'))
  else
    dt.print_error('HDRMerge failed')
    dt.print(_('HDRMerge failed'))
  end

end

local function install_module()
  if not HDRM.module_installed then
    dt.register_lib( -- register HDRMerge module
      'HDRMerge_Lib', -- Module name
      _('HDRMerge'), -- name
      true,   -- expandable
      true,   -- resetable
      {[dt.gui.views.lighttable] = {'DT_UI_CONTAINER_PANEL_RIGHT_CENTER', 99}},   -- containers
      dt.new_widget('box'){
        orientation = 'vertical',
        GUI.stack
      }
    )
    HDRM.module_installed = true
  end
end

local function destroy()
  dt.gui.libs["HDRMerge_Lib"].visible = false
end

local function restart()
  dt.gui.libs["HDRMerge_Lib"].visible = true
end

-- GUI Elements --
local lbl_hdr = dt.new_widget('section_label'){
  label = _('HDRMerge options')
}
temp = dt.preferences.read(mod, 'active_bps_ind', 'integer')
if not InRange(temp, 1, 3) then temp = 3 end 
GUI.HDR.bps = dt.new_widget('combobox'){
  label = _('bits per sample'), 
  tooltip =_('number of bits per sample in the output image'),
  selected = temp,
  '16','24','32',             
  changed_callback = function(self)
    dt.preferences.write(mod, 'active_bps', 'integer', self.value) 
    dt.preferences.write(mod, 'active_bps_ind', 'integer', self.selected)
  end,
  reset_callback = function(self) 
    self.selected = 3
    dt.preferences.write(mod, 'active_bps', 'integer', self.value) 
    dt.preferences.write(mod, 'active_bps_ind', 'integer', self.selected)
  end
} 
temp = dt.preferences.read(mod, 'active_size_ind', 'integer')
if not InRange(temp, 1, 3) then temp = 2 end 
GUI.HDR.size = dt.new_widget('combobox'){
  label = _('embedded preview size'), 
  tooltip =_('size of the embedded preview in output image'),
  selected = temp,
  _('none'),_('half'),_('full'),             
  changed_callback = function(self)
    dt.preferences.write(mod, 'active_size', 'string', self.value) 
    dt.preferences.write(mod, 'active_size_ind', 'integer', self.selected)
  end,
  reset_callback = function(self) 
    self.selected = 2
    dt.preferences.write(mod, 'active_size', 'string', self.value) 
    dt.preferences.write(mod, 'active_size_ind', 'integer', self.selected)
  end
} 
GUI.HDR.batch = dt.new_widget('check_button'){
  label = _('batch mode'),
  value = dt.preferences.read(mod, 'active_batch', 'bool'),
  tooltip = _('enable batch mode operation \nNOTE: resultant files will NOT be auto-imported'),
  clicked_callback = function(self)
    dt.preferences.write(mod, 'active_batch', 'bool', self.value)
    GUI.HDR.gap.sensitive = self.value
  end,
  reset_callback = function(self) self.value = false end
}
temp = dt.preferences.read(mod, 'active_gap', 'integer')
if not InRange(temp, 1, 3600) then temp = 3 end
GUI.HDR.gap = dt.new_widget('slider'){
  label = _('batch gap [sec.]'),
  tooltip = _('gap, in seconds, between batch mode groups'),
  soft_min = 1,
  soft_max = 30,
  hard_min = 1,
  hard_max = 3600,
  step = 1,
  digits = 0,
  value = temp,
  sensitive = GUI.HDR.batch.value,
  reset_callback = function(self) 
    self.value = 3
  end
}
local lbl_import = dt.new_widget('section_label'){
  label = _('import options')
}
GUI.Target.style = dt.new_widget('combobox'){
  label = _('apply style on import'),
  tooltip = _('apply selected style on auto-import to newly created image'),
  selected = 1,
  _('none'),
  changed_callback = function(self)
    dt.preferences.write(mod, 'active_style', 'string', self.value) 
    dt.preferences.write(mod, 'active_style_ind', 'integer', self.selected)
  end,
  reset_callback = function(self) 
    self.selected = 1
    dt.preferences.write(mod, 'active_style', 'string', self.value) 
    dt.preferences.write(mod, 'active_style_ind', 'integer', self.selected)
  end 
}
for k=1, (styles_count-1) do
  GUI.Target.style[k+1] = styles[k].name
end
temp = dt.preferences.read(mod, 'active_style_ind', 'integer')
if not InRange(temp, 1, styles_count) then temp = 1 end
GUI.Target.style.selected = temp
GUI.Target.copy_tags = dt.new_widget('check_button'){
  label = _('copy tags'),
  value = dt.preferences.read(mod, 'active_copy_tags', 'bool'),
  tooltip = _('copy tags from first source image'),
  clicked_callback = function(self) dt.preferences.write(mod, 'active_copy_tags', 'bool', self.value) end,
  reset_callback = function(self) self.value = true end
}
temp = dt.preferences.read(mod, 'active_add_tags', 'string')
if temp == '' then temp = nil end 
GUI.Target.add_tags = dt.new_widget('entry'){
  tooltip = _('additional tags to be added on import, separate with commas, all spaces will be removed'),
  text = temp,
  placeholder = _('enter tags, separated by commas'),
  editable = true
}
GUI.run = dt.new_widget('button'){
  label = _('merge'),
  tooltip =_('run HDRMerge with the above settings'),
  clicked_callback = function() main() end
}
GUI.exes.HDRMerge = dt.new_widget('file_chooser_button'){
  title = _('select HDRmerge executable'),
  value = df.get_executable_path_preference(HDRM.name),
  is_directory = false
}
GUI.exes.update = dt.new_widget('button'){
  label = _('update'),
  tooltip =_('update the binary path with current value'),
  clicked_callback = function() ExeUpdate({HDRM}) end
}
GUI.options = dt.new_widget('box'){
  orientation = 'vertical',
  lbl_hdr,
  GUI.HDR.bps,
  GUI.HDR.size,
  GUI.HDR.batch,
  GUI.HDR.gap,
  lbl_import,
  GUI.Target.style,
  GUI.Target.copy_tags,
  GUI.Target.add_tags,
  GUI.run
}
local exes_box = dt.new_widget('box'){
  orientation = 'vertical',
  GUI.exes.HDRMerge,
  GUI.exes.update
}
GUI.stack = dt.new_widget('stack'){
  GUI.options,
  exes_box
}
if dt.preferences.read(mod, 'bin_exists', 'bool') then
  GUI.stack.active = 1
else
  GUI.stack.active = 2
end

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not HDRM.event_registered then
    dt.register_event(
      "HDRmerge", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    HDRM.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data