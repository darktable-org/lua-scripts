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
previous = nil
all_active = false

-- FUNCTION --
local function CheckSingleImage(selection)
	if #selection ~= 1 then
		dt.print("Please select a single image")
		return 1
	end
	return 0
end
local function PreviousCollection()
	if previous ~= nil then
		previous = dt.gui.libs.collect.filter(previous)
	end
end
local function CollectOnFolder()
	local images = dt.gui.selection()
	if CheckSingleImage(images) == 1 then
		return
	end
	rules = {}
	all_rules = {}
	rule = dt.gui.libs.collect.new_rule()
	rule.mode = "DT_LIB_COLLECT_MODE_AND"
	rule.data = images[1].path
	rule.item = "DT_COLLECTION_PROP_FOLDERS"
	table.insert(rules, rule)
	if all_active then
		for _,active_rule in pairs(rules) do
			table.insert(all_rules, active_rule)
		end
	else
		previous = dt.gui.libs.collect.filter(rules)
	end
end
local function CollectOnColors()
	local images = dt.gui.selection()
	if CheckSingleImage(images) == 1 then
		return
	end
	for _,image in pairs(images) do
		rules = {}
		if image.red then
			red_rule = dt.gui.libs.collect.new_rule()
			red_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			red_rule.data = "red"
			red_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, red_rule)
		end
		if image.blue then
			blue_rule = dt.gui.libs.collect.new_rule()
			blue_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			blue_rule.data = "blue"
			blue_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, blue_rule)
		end
		if image.green then
			green_rule = dt.gui.libs.collect.new_rule()
			green_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			green_rule.data = "green"
			green_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, green_rule)
		end
		if image.yellow then
			yellow_rule = dt.gui.libs.collect.new_rule()
			yellow_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			yellow_rule.data = "yellow"
			yellow_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, yellow_rule)
		end
		if image.purple then
			purple_rule = dt.gui.libs.collect.new_rule()
			purple_rule.mode = "DT_LIB_COLLECT_MODE_AND"
			purple_rule.data = "purple"
			purple_rule.item = "DT_COLLECTION_PROP_COLORLABEL"
			table.insert(rules, purple_rule)
		end
		if all_active then
			for _,active_rule in pairs(rules) do
				table.insert(all_rules, active_rule)
			end
		else
			previous = dt.gui.libs.collect.filter(rules)
		end
	end
end
local function CollectOnAll_AND()
	local images = dt.gui.selection()
	if CheckSingleImage(images) == 1 then
		return
	end
	all_rules = {}
	all_active = true
	if dt.preferences.read('module_CollectHelper','folder','bool') then
		CollectOnFolder()
	end
	if dt.preferences.read('module_CollectHelper','colors','bool') then
		CollectOnColors()
	end
	all_active = false
	previous = dt.gui.libs.collect.filter(all_rules)
end

-- GUI --
dt.gui.libs.image.register_action(
	"Return to Previous Collection",
	function() PreviousCollection() end,
	"Sets the Collect parameters to be the previously active parameters"
)
if dt.preferences.read('module_CollectHelper','folder','bool') then
	dt.gui.libs.image.register_action(
		"Collect on image's Folder",
		function() CollectOnFolder() end,
		"Sets the Collect parameters to be the selected images's folder"
	)
end
if dt.preferences.read('module_CollectHelper','colors','bool') then
	dt.gui.libs.image.register_action(
		"Collect on image's Color Label(s)",
		function() CollectOnColors() end,
		"Sets the Collect parameters to be the selected images's color label(s)"
	)
end
if dt.preferences.read('module_CollectHelper','all_and','bool') then
	dt.gui.libs.image.register_action(
		"Collect on All (AND)",
		function() CollectOnAll_AND() end,
		"Sets the Collect parameters based on all activated CollectHelper options"
	)
end

-- PREFERENCES --
dt.preferences.register("module_CollectHelper", "all_and",	-- name
	"bool",	-- type
	'CollectHelper: All',	-- label
	'Will create a collect parameter set that utelizes all enabled CollectHelper types (AND)',	-- tooltip
	true	-- default
)
dt.preferences.register("module_CollectHelper", "colors",	-- name
	"bool",	-- type
	'CollectHelper: Color Label(s)',	-- label
	'Enable the button that allows you to swap to a collection based on selected image\'s COLOR LABEL(S)',	-- tooltip
	true	-- default
)
dt.preferences.register("module_CollectHelper", "folder",	-- name
	"bool",	-- type
	'CollectHelper: Folder',	-- label
	'Enable the button that allows you to swap to a collection based on selected image\'s FOLDER location',	-- tooltip
	true	-- default
)