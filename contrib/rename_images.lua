--[[

    rename.lua - rename image file(s)

    Copyright (C) 2020, 2021 Bill Ferguson <wpferguson@gmail.com>.

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
    rename - rename an image file or files

    This shortcut resets the GPS information to that contained within
    the image file.  If no GPS info is in the image file, the GPS data
    is cleared.

    USAGE
    * require this script from your luarc file or start it from script_manager
    * select an image or images
    * enter a renaming pattern
    * click the button to rename the files

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES

    TODO 
    * Add pattern builder
    * Add new name preview
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local ds = require "lib/dtutils.string"

du.check_min_api_version("7.0.0", "rename_images") 

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- namespace variable
local rename = {
  presets = {},
  widgets = {},
}
rename.module_installed = false
rename.event_registered = false

-- script_manager integration
local script_data = {}

script_data.metadata = {
  name = _("rename images"),
  purpose = _("rename an image file or files"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/rename_images"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them


-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "rename_images"
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"
local USER = os.getenv("USERNAME")
local HOME = os.getenv(dt.configuration.running_os == "windows" and "HOMEPATH" or "HOME")
local PICTURES = HOME .. PS .. dt.configuration.running_os == "windows" and _("My Pictures") or _("Pictures")
local DESKTOP = HOME .. PS .. "Desktop"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -

local function stop_job(job)
  job.valid = false
end

-- make sure filename ends with the given extension (without leading dot);
-- does nothing if extension is empty
local function ensure_extension(filename, extension)
  if extension ~= "" then
    local suffix = "." .. extension
    if string.lower(string.sub(filename, -string.len(suffix))) ~= string.lower(suffix) then
      filename = filename .. suffix
    end
  end
  return filename
end

local function install_module()
  if not rename.module_installed then
    dt.register_lib(
      MODULE_NAME,
      _("rename images"),
      true,
      true,
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER",700}},
      dt.new_widget("box"){
        orientation = "vertical",
        rename.widgets.pattern,
        rename.widgets.allow_moving_files,
        rename.widgets.use_existing_extension,
        rename.widgets.extension_pattern,
        rename.widgets.preview_button,
        rename.widgets.preview_label,
        rename.widgets.button,
      },
      nil,
      nil
    )
    rename.module_installed = true
  end
end

local function destroy()
  dt.gui.libs[MODULE_NAME].visible = false
end

local function restart()
  dt.gui.libs[MODULE_NAME].visible = true
end  

-- - - - - - - - - - - - - - - - - - - - - - - -
-- M A I N
-- - - - - - - - - - - - - - - - - - - - - - - -

-- characters that are forbidden (or at least highly problematic) in
-- filenames across common operating systems; always replaced, regardless
-- of the "allow moving files" setting
local function sanitize_forbidden_characters(name)
  return (name:gsub('[<>:"|?*%c]', "-"))
end

-- replace path separators with "-" unless the user explicitly opted in to
-- allow the rename pattern to move files into different folders; the
-- underlying split_filepath() (used by df.get_path/df.get_filename) treats
-- both "/" and "\" as separators regardless of the current OS, so both are
-- always allowed together here too, rather than just the OS's native one
local function sanitize_path_separators(name)
  if rename.widgets.allow_moving_files.value then
    return name
  end
  return (name:gsub("[/\\]", "-"))
end

-- runs variable substitution for one image and returns the result,
-- or -1 if the substitution failed (see ds.substitute_list)
local function substitute_pattern(image, sequence, pattern)
  ds.build_substitute_list(image, sequence, pattern, USER, PICTURES, HOME, DESKTOP)
  local new_name = ds.substitute_list(pattern)
  ds.clear_substitute_list()
  if new_name == -1 then
    return -1
  end
  new_name = sanitize_path_separators(new_name)
  new_name = sanitize_forbidden_characters(new_name)
  return new_name
end

-- work out which extension to use for a given image, based on the
-- "use existing extension" checkbox and (if unchecked) the extension pattern
local function determine_extension(image, sequence)
  if rename.widgets.use_existing_extension.value then
    return df.get_filetype(image.filename)
  end

  local extension_pattern = rename.widgets.extension_pattern.text
  local extension = ""
  if string.len(extension_pattern) > 0 then
    local substituted = substitute_pattern(image, sequence, extension_pattern)
    if substituted ~= -1 then
      extension = substituted
    end
  end

  -- collapse runs of consecutive dots into a single dot, so that e.g.
  -- "......." is treated the same as a single "." (falls through to the
  -- empty-extension check below, which falls back to the original extension)
  extension = string.gsub(extension, "%.+", ".")

  if string.sub(extension, 1, 1) == "." then
    extension = string.sub(extension, 2)
  end

  if extension == "" then
    return df.get_filetype(image.filename)
  end

  return extension
end

-- returns the pattern's folder component with any leading separators
-- stripped, so a leading "/" or "\" can never point to the filesystem
-- root (or, for an AppImage, the process's working directory) - the
-- folder is always resolved relative to the image's current location
local function resolve_relative_path(new_name)
  local path = string.sub(df.get_path(new_name), 1, -2)
  return (string.gsub(path, "^[/\\]+", ""))
end

-- work out the destination folder for a renamed image, always relative
-- to the image's current folder (see resolve_relative_path)
local function resolve_path(new_name, image)
  local relative_path = resolve_relative_path(new_name)
  if string.len(relative_path) == 0 then
    return image.path
  end
  return image.path .. PS .. relative_path
end

-- save the pattern and extension-pattern fields so they survive a restart;
-- the checkbox persists itself immediately on click (see its clicked_callback)
local function persist_pattern_prefs()
  dt.preferences.write(MODULE_NAME, "pattern", "string", rename.widgets.pattern.text)
  dt.preferences.write(MODULE_NAME, "extension_pattern", "string", rename.widgets.extension_pattern.text)
end

local function do_rename(images)
  if #images > 0 then
    local first_image = images[1]
    local pattern = rename.widgets.pattern.text
    persist_pattern_prefs()
    dt.print_log("pattern is " .. pattern)
    if string.len(pattern) > 0 then
      local datetime = os.date("*t")

      local job = dt.gui.create_job(_("renaming images"), true, stop_job)
      for i, image in ipairs(images) do
        if job.valid then
          job.percent = i / #images
          local new_name = substitute_pattern(image, i, pattern)
          if new_name == -1 then
            dt.print(_("unable to do variable substitution, exiting..."))
            stop_job(job)
            return
          end
          local args = {}
          local path = resolve_path(new_name, image)
          local filename = ensure_extension(df.get_filename(new_name), determine_extension(image, i))
          local filmname = image.path
          if path ~= image.path then
            if not df.check_if_file_exists(df.sanitize_filename(path)) then
              df.mkdir(df.sanitize_filename(path))
            end
            filmname = path
          end
          args[1] = dt.films.new(filmname)
          args[2] = image
          if filename ~= image.filename then
            args[3] = filename
          end
          dt.database.move_image(table.unpack(args))
        end
      end
      stop_job(job)
      local collect_rules = dt.gui.libs.collect.filter()
      dt.gui.libs.collect.filter(collect_rules)
      dt.gui.views.lighttable.set_image_visible(first_image)
      dt.print(string.format(_("renamed %d images"), #images))
    else -- pattern length
      dt.print_error("no pattern supplied, returning...")
      dt.print(_("please enter the new name or pattern"))
    end
  else -- image count
    dt.print_error("no images selected, returning...")
    dt.print(_("please select some images and try again"))
  end
end

local function do_preview(images)
  if #images > 0 then
    local image = images[1]
    local pattern = rename.widgets.pattern.text
    persist_pattern_prefs()
    if string.len(pattern) > 0 then
      local new_name = substitute_pattern(image, 1, pattern)
      if new_name == -1 then
        rename.widgets.preview_label.label = _("unable to do variable substitution")
      else
        local relative_path = resolve_relative_path(new_name)
        local filename = ensure_extension(df.get_filename(new_name), determine_extension(image, 1))
        if string.len(relative_path) > 0 then
          rename.widgets.preview_label.label = relative_path .. PS .. filename
        else
          rename.widgets.preview_label.label = filename
        end
      end
    else -- pattern length
      rename.widgets.preview_label.label = _("please enter the new name or pattern")
    end
  else -- image count
    rename.widgets.preview_label.label = _("please select an image first")
  end
end


-- - - - - - - - - - - - - - - - - - - - - - - -
-- W I D G E T S
-- - - - - - - - - - - - - - - - - - - - - - - -

rename.widgets.pattern = dt.new_widget("entry"){
  tooltip = ds.get_substitution_tooltip(),
  placeholder = _("enter pattern") .. "$(FILE_FOLDER)/$(FILE_NAME)",
  text = "",
  reset_callback = function(self)
    self.text = ""
    dt.preferences.write(MODULE_NAME, "pattern", "string", self.text)
  end
}

local pattern_pref = dt.preferences.read(MODULE_NAME, "pattern", "string")
if pattern_pref then
  rename.widgets.pattern.text = pattern_pref
end

rename.widgets.allow_moving_files = dt.new_widget("check_button"){
  label = _("allow moving files"),
  value = false,
  tooltip = _("allows for moving files during renaming by using slash/backslash to construct a filepath") .. "\n" ..
            _("useful for e.g. sorting files by their date") .. "\n" ..
            _("caution: use with extra care"),
  clicked_callback = function(self)
    dt.preferences.write(MODULE_NAME, "allow_moving_files", "bool", self.value)
    dt.preferences.write(MODULE_NAME, "allow_moving_files_saved", "bool", true)
  end
}

if dt.preferences.read(MODULE_NAME, "allow_moving_files_saved", "bool") then
  rename.widgets.allow_moving_files.value = dt.preferences.read(MODULE_NAME, "allow_moving_files", "bool")
end

rename.widgets.extension_pattern = dt.new_widget("entry"){
  tooltip = _("pattern or literal text for the new extension") .. "\n" ..
            _("leave empty to keep the existing extension"),
  text = "$(FILE.EXTENSION)",
  visible = false,
  reset_callback = function(self)
    self.text = "$(FILE.EXTENSION)"
    self.visible = false
    dt.preferences.write(MODULE_NAME, "extension_pattern", "string", self.text)
  end
}

-- defined AFTER extension_pattern: setting "value" below fires
-- clicked_callback immediately during construction, which references
-- rename.widgets.extension_pattern
rename.widgets.use_existing_extension = dt.new_widget("check_button"){
  label = _("use existing extension"),
  value = true,
  clicked_callback = function(self)
    rename.widgets.extension_pattern.visible = not self.value
    dt.preferences.write(MODULE_NAME, "use_existing_extension", "bool", self.value)
    dt.preferences.write(MODULE_NAME, "use_existing_extension_saved", "bool", true)
  end
}

-- only override the widget defaults if the checkbox was explicitly
-- saved before; dt.preferences.read(..., "bool") returns false rather
-- than nil for a preference that was never set, so a sentinel flag is
-- needed to tell "never saved" apart from "saved as false"
if dt.preferences.read(MODULE_NAME, "use_existing_extension_saved", "bool") then
  rename.widgets.use_existing_extension.value = dt.preferences.read(MODULE_NAME, "use_existing_extension", "bool")
  rename.widgets.extension_pattern.visible = not rename.widgets.use_existing_extension.value
end

local extension_pattern_pref = dt.preferences.read(MODULE_NAME, "extension_pattern", "string")
if extension_pattern_pref and extension_pattern_pref ~= "" then
  rename.widgets.extension_pattern.text = extension_pattern_pref
end

rename.widgets.preview_button = dt.new_widget("button"){
  label = _("preview filename"),
  clicked_callback = function(this)
    do_preview(dt.gui.action_images)
  end
}

rename.widgets.preview_label = dt.new_widget("label"){
  label = "",
  selectable = true,
}

rename.widgets.button = dt.new_widget("button"){
  label = _("rename"),
  clicked_callback = function(this)
    do_rename(dt.gui.action_images)
  end
}

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not rename.event_registered then
    dt.register_event(
      "rename_images", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    rename.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
