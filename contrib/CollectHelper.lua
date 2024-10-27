--[[Collect Helper plugin for darktable

  copyright (c) 2019  Kevin Ertel
  
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

--[[About this plugin
This plugin adds the button(s) to the "Selected Images" module:
1) Return to Previous Collection
2) Collect on image's Folder
3) Collect on image's Color Label(s)
4) Collect on All (AND)

It also adds 3 preferences to the lua options dialog box which allow the user to activate/deactivate the 3 "Collect on" buttons.

Button Behavior:
1) Return to Previous Collection - Will reset the collect parameters to the previously active settings
2) Collect on image's Folder - Will change the collect parameters to be "Folder" with a value of the selected image's folder location
3) Collect on image's Color Label(s) - Will change the collect parameter to be "Color" with a value of the selected images color labels, will apply multiple parameters with AND logic if multiple exist
4) Collect on All (AND) - Will collect on all parameters activated by the preferences dialog, as such this button is redundant if you only have one of the two other options enabled

----REQUIRED SOFTWARE----
NA

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file in to your "lua/contrib" folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in

Select the photo you wish to change you collection based on.
In the "Selected Images" module click on "Collect on this Image"

----KNOWN ISSUES----
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local gettext = dt.gettext.gettext
local previous = nil
local all_active = false

du.check_min_api_version("7.0.0", "CollectHelper") 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("collection helper"),
  purpose = _("add collection helper buttons"),
  author = "Kevin Ertel",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/CollectHelper/"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- FUNCTION --
local function CheckSingleImage(selection)
	if #selection ~= 1 then
		dt.print(_("please select a single image"))
		return true
	end
	return false
end

local function CheckHasColorLabel(selection)
	local ret = false
	for _,image in pairs(selection) do
		if image.red then ret = true end
		if image.blue then ret = true end
		if image.green then ret = true end
		if image.yellow then ret = true end
		if image.purple then ret = true end
	end
	return ret
end
local function PreviousCollection()
	if previous ~= nil then
		previous = dt.gui.libs.collect.filter(previous)
	end
end

local function CollectOnFolder(all_rules, all_active)
	local images = dt.gui.selection()
	if CheckSingleImage(images) then
		return
	end
	local rules = {}
	local rule = dt.gui.libs.collect.new_rule()
	rule.mode = "DT_LIB_COLLECT_MODE_AND"
	rule.data = images[1].path
	rule.item = "DT_COLLECTION_PROP_FOLDERS"
	table.insert(rules, rule)
	if all_active then
		for _,active_rule in pairs(rules) do
			table.insert(all_rules, active_rule)
		end
		return all_rules
	else
		previous = dt.gui.libs.collect.filter(rules)
	end
end

local function CollectOnColors(all_rules, all_active)
	local images = dt.gui.selection()
	if CheckSingleImage(images) then
		return
	end
	if not CheckHasColorLabel(images) then
		dt.print(_('select an image with an active color label'))
		return
	end
	for _,image in pairs(images) do
		local rules = {}
		if image.red then
			local red_rule = dt.gui.libs.collect.new_rule()
			red_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			red_rule.data = "red"
			red_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, red_rule)
		end
		if image.blue then
			local blue_rule = dt.gui.libs.collect.new_rule()
			blue_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			blue_rule.data = "blue"
			blue_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, blue_rule)
		end
		if image.green then
			local green_rule = dt.gui.libs.collect.new_rule()
			green_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			green_rule.data = "green"
			green_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, green_rule)
		end
		if image.yellow then
			local yellow_rule = dt.gui.libs.collect.new_rule()
			yellow_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			yellow_rule.data = "yellow"
			yellow_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, yellow_rule)
		end
		if image.purple then
			local purple_rule = dt.gui.libs.collect.new_rule()
			purple_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			purple_rule.data = "purple"
			purple_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, purple_rule)
		end
		if all_active then
			for _,active_rule in pairs(rules) do
				table.insert(all_rules, active_rule)
			end
			return all_rules
		else
			previous = dt.gui.libs.collect.filter(rules)
		end
	end
end

local function CollectOnAll_AND()
	local images = dt.gui.selection()
	if CheckSingleImage(images) then
		return
	end
	local rules = {}
	if dt.preferences.read('module_CollectHelper','folder','bool') then
		rules = CollectOnFolder(rules, true)
	end
	if dt.preferences.read('module_CollectHelper','colors','bool') then
		rules = CollectOnColors(rules, true)
	end
	previous = dt.gui.libs.collect.filter(rules)
end

local function destroy()
	dt.gui.libs.image.destroy_action("CollectHelper_prev")
	if dt.preferences.read('module_CollectHelper','folder','bool') then
		dt.gui.libs.image.destroy_action("CollectHelper_folder")
	end
	if dt.preferences.read('module_CollectHelper','colors','bool') then
		dt.gui.libs.image.destroy_action("CollectHelper_labels")
	end
	if dt.preferences.read('module_CollectHelper','all_and','bool') then
		dt.gui.libs.image.destroy_action("CollectHelper_and")
	end
end

-- GUI --
dt.gui.libs.image.register_action(
	"CollectHelper_prev", _("collect: previous"),
	function() PreviousCollection() end,
	_("sets the collect parameters to be the previously active parameters")
)
if dt.preferences.read('module_CollectHelper','folder','bool') then
		dt.gui.libs.image.register_action(
		"CollectHelper_folder", _("collect: folder"),
		function() CollectOnFolder(_ , false) end,
		_("sets the collect parameters to be the selected images's folder")
	)
end
if dt.preferences.read('module_CollectHelper','colors','bool') then
		dt.gui.libs.image.register_action(
		"CollectHelper_labels", _("collect: color label(s)"),
		function() CollectOnColors(_ , false) end,
		_("sets the collect parameters to be the selected images's color label(s)")
	)
end
if dt.preferences.read('module_CollectHelper','all_and','bool') then
		dt.gui.libs.image.register_action(
		"CollectHelper_and", _("collect: all (AND)"),
		function() CollectOnAll_AND() end,
		_("sets the collect parameters based on all activated CollectHelper options")
	)
end

-- PREFERENCES --
dt.preferences.register("module_CollectHelper", "all_and",	-- name
	"bool",	-- type
	_('CollectHelper: all'),	-- label
	_('creates a collect parameter set that utilizes all enabled CollectHelper types (and)'),	-- tooltip
	true	-- default
)
dt.preferences.register("module_CollectHelper", "colors",	-- name
	"bool",	-- type
	_('CollectHelper: color label(s)'),	-- label
	_('enable the button that allows you to swap to a collection based on selected image\'s color label(s)'),	-- tooltip
	true	-- default
)
dt.preferences.register("module_CollectHelper", "folder",	-- name
	"bool",	-- type
	_('CollectHelper: folder'),	-- label
	_('enable the button that allows you to swap to a collection based on selected image\'s folder location'),	-- tooltip
	true	-- default
)

script_data.destroy = destroy 

return script_data
