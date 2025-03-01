--[[

    dbmaint.lua - perform database maintenance

    Copyright (C) 2024 Bill Ferguson <wpferguson@gamil.com>.

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
    dbmaint - perform database maintenance

    Perform database maintenance to clean up missing images and filmstrips.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    None

    USAGE
    * start dbmaint from script_manager
    * scan for missing film rolls or missing images
    * look at the results and choose to delete or not

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gamil.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "dbmaint"
local DEFAULT_LOG_LEVEL <const> = log.error
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("7.0.0", MODULE)   -- choose the minimum version that contains the features you need


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- I 1 8 N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T  M A N A G E R  I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local script_data = {}

script_data.destroy = nil           -- function to destory the script
script_data.destroy_method = nil    -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil           -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil              -- only required for libs since the destroy_method only hides them

script_data.metadata = {
  name = _("db maintenance"),
  purpose = _("perform database maintenance"),
  author = "Bill Ferguson <wpferguson@gamil.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/dbmaint/"
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local dbmaint = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dbmaint.main_widget = nil

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = dbmaint

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-------------------
-- helper functions
-------------------

local function set_log_level(level)
  local old_log_level = log.log_level()
  log.log_level(level)
  return old_log_level
end

local function restore_log_level(level)
  log.log_level(level)
end

local function scan_film_rolls()
  local missing_films = {}

  for _, filmroll in ipairs(dt.films) do
    if not df.check_if_file_exists(filmroll.path) then
      table.insert(missing_films, filmroll)
    end
  end

  return missing_films
end

local function scan_images(film)
  local old_log_level = set_log_level(DEFAULT_LOG_LEVEL)
  local missing_images = {}

  if film then
    for i = 1, #film  do
      local image = film[i]
      log.msg(log.debug, "checking " .. image.filename)
      if not df.check_if_file_exists(image.path .. PS .. image.filename) then
        log.msg(log.info, image.filename .. " not found")
        table.insert(missing_images, image)
      end
    end
  end

  restore_log_level(old_log_level)
  return missing_images
end

local function remove_missing_film_rolls(list)
  for _, filmroll in ipairs(list) do 
    filmroll:delete(true)
  end
end

-- force the lighttable to reload

local function refresh_lighttable(film)
  local rules = dt.gui.libs.collect.filter()
  dt.gui.libs.collect.filter(rules)
end

local function remove_missing_images(list)
  local film = list[1].film
  for _, image in ipairs(list) do
    image:delete()
  end
  refresh_lighttable(film)
end

local function install_module()
  if not namespace.module_installed then
    dt.register_lib(
      MODULE,     -- Module name
      _("DB maintenance"),     -- Visible name
      true,                -- expandable
      true,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER", 0}},   -- containers
      namespace.main_widget,
      nil,-- view_enter
      nil -- view_leave
    )
    namespace.module_installed = true
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

dbmaint.list_widget = dt.new_widget("text_view"){
  editable = false,
  reset_callback = function(this)
    this.text = ""
  end
}

dbmaint.chooser = dt.new_widget("combobox"){
  label = _("scan for"),
  selected = 1,
  _("film rolls"), _("images"),
  reset_callback = function(this)
    this.selected = 1
  end
}

dbmaint.scan_button = dt.new_widget("button"){
  label = _("scan"),
  tooltip = _("click to scan for missing film rolls/files"),
  clicked_callback = function(this)
    local found = nil
    local found_text = ""
    local old_log_level = set_log_level(DEFAULT_LOG_LEVEL)
    log.msg(log.debug, "Button clicked")
    if dbmaint.chooser.selected == 1 then -- film rolls
      found = scan_film_rolls()
      if #found > 0 then
        for _, film in ipairs(found) do
          local dir_name = du.split(film.path, PS)
          found_text = found_text .. dir_name[#dir_name] .. "\n"
        end
      end
    else
      log.msg(log.debug, "checking path " .. dt.collection[1].path .. " for missing files")
      found = scan_images(dt.collection[1].film)
      if #found > 0 then
        for _, image in ipairs(found) do
          found_text = found_text .. image.filename .. "\n"
        end
      end
    end
    if #found > 0 then
      log.msg(log.debug, "found " .. #found .. " missing items")
      dbmaint.list_widget.text = found_text
      dbmaint.found = found
      dbmaint.remove_button.sensitive = true
    else
      log.msg(log.debug, "no missing items found")
    end
    restore_log_level(old_log_level)
  end,
  reset_callback = function(this)
    dbmaint.found = nil
  end
}

dbmaint.remove_button = dt.new_widget("button"){
  label = _("remove"),
  tooltip = _("remove missing film rolls/images"),
  sensitive = false,
  clicked_callback = function(this)
    if dbmaint.chooser.selected == 1 then -- film rolls
      remove_missing_film_rolls(dbmaint.found)
    else
      remove_missing_images(dbmaint.found)
    end
    dbmaint.found = nil
    dbmaint.list_widget.text = ""
    this.sensitive = false
  end,
  reset_callback = function(this)
    this.sensitive = false
  end
}

dbmaint.main_widget = dt.new_widget("box"){
  orientation = "vertical",
  dt.new_widget("section_label"){label = _("missing items")},
  dbmaint.list_widget,
  dt.new_widget("label"){label = ""},
  dbmaint.chooser,
  dt.new_widget("label"){label = ""},
  dbmaint.scan_button,
  dbmaint.remove_button
}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.gui.libs[MODULE].visible = false

  if namespace.event_registered then
    dt.destroy_event(MODULE, "view-changed")
  end

  return
end

local function restart()
  dt.gui.libs[MODULE].visible = true

  return
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not namespace.event_registered then
    dt.register_event(MODULE, "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    namespace.event_registered = true
  end
end

return script_data