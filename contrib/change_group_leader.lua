--[[
  change group leader

  copyright (c) 2020, 2022 Bill Ferguson <wpferguson@gmail.com>
  copyright (c) 2021 Angel Angelov

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
CHANGE GROUP LEADER
automatically change the leader of raw+jpg paired image groups

INSTALLATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "change_group_leader"

USAGE
* in lighttable mode, select the image groups you wish to process,
  select whether you want to set the leader to "jpg" or "raw",
  and click "Execute"
]]

local dt = require "darktable"
local du = require "lib/dtutils"

local gettext = dt.gettext.gettext 

local MODULE = "change_group_leader"

du.check_min_api_version("3.0.0", MODULE)

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("change group leader"),
  purpose = _("automatically change the leader of raw+jpg paired image groups"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/change_group_leader"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- create a namespace to contain persistent data and widgets
local chg_grp_ldr = {}

local cgl = chg_grp_ldr

cgl.widgets = {}

cgl.event_registered = false
cgl.module_installed = false

-- - - - - - - - - - - - - - - - - - - - - - - -
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -

local function install_module()
  if not cgl.module_installed then
    dt.register_lib(
      MODULE,     -- Module name
      _("change group leader"),     -- Visible name
      true,                -- expandable
      false,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 700}},   -- containers
      cgl.widgets.box,
      nil,-- view_enter
      nil -- view_leave
    )
    cgl.module_installed = true
  end
end

local function find_group_leader(images, mode)
  for _, img in ipairs(images) do
    dt.print_log("checking image " .. img.id .. " named "  .. img.filename)
    local found = false
    if mode == "jpg" then
      if string.match(string.lower(img.filename), "jpg$") then
        dt.print_log("jpg matched image " .. img.filename)
        found = true
      end
    elseif mode == "raw" then
      if img.is_raw and img.duplicate_index == 0 then
        dt.print_log("found raw " .. img.filename)
        found = true
      end
    elseif mode == "non-raw" then
      if img.is_ldr then
        dt.print_log("found ldr " .. img.filename)
        found = true
      end
    else
      dt.print_error(MODULE .. ": unrecognized mode " .. mode)
      return
    end
    if found then
      dt.print_log("making " .. img.filename .. " group leader")
      img:make_group_leader()
      return
    end
  end
end

local function process_image_groups(images)
  if #images < 1 then
    dt.print(_("no images selected"))
    dt.print_log(MODULE .. "no images seletected, returning...")
  else
    local mode = cgl.widgets.mode.value
    for _,img in ipairs(images) do
      dt.print_log("checking image " .. img.id)
      local group_images = img:get_group_members()
      if group_images == 1 then
        dt.print_log("only one image in group for image " .. image.id)
      else
        find_group_leader(group_images, mode)
      end
    end
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T  M A N A G E R  I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - -

local function destroy()
  dt.gui.libs[MODULE].visible = false
end

local function restart()
  dt.gui.libs[MODULE].visible = true
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- W I D G E T S
-- - - - - - - - - - - - - - - - - - - - - - - -

cgl.widgets.mode = dt.new_widget("combobox"){
  label = _("select new group leader"),
  tooltip = _("select type of image to be group leader"),
  selected = 1,
  "jpg", "raw", "non-raw",
}

cgl.widgets.execute = dt.new_widget("button"){
  label = _("execute"),
  clicked_callback = function()
    process_image_groups(dt.gui.action_images)
  end
}

cgl.widgets.box = dt.new_widget("box"){
  orientation = "vertical",
  cgl.widgets.mode,
  cgl.widgets.execute,
}

-- - - - - - - - - - - - - - - - - - - - - - - -
-- D A R K T A B L E  I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - -

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not cgl.event_registered then
    dt.register_event(
      "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    cgl.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
