--[[
    This file is part of darktable,
    copyright (c) 2019 Bill Ferguson <wpferguson@gmail.com>

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
    lighttable_demo - an example script demonstrating how to control lighttable display modes

    lighttable_demo is an example script showing how to control lighttable layout, sorting, and
    filtering from a lua script.  If the selected directory has different ratings, color labels, etc,
    then the sorting and filtering display is a little clearer.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * none

    USAGE
    * require this script from your main lua file

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- V E R S I O N  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - -

du.check_min_api_version("5.0.2", "lighttable_demo")  -- darktable 3.0

-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "lighttable"
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
    -- nothing to destroy
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- T R A N S L A T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -
local gettext = dt.gettext.gettext

dt.gettext.bindtextdomain("lighttable_demo", dt.configuration.config_dir .."/lua/locale/")

local function _(msgid)
  return gettext(msgid)
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -

-- - - - - - - - - - - - - - - - - - - - - - - -
-- M A I N
-- - - - - - - - - - - - - - - - - - - - - - - -

-- alias dt.control.sleep to sleep
local sleep = dt.control.sleep

local layouts = {
  "DT_LIGHTTABLE_LAYOUT_ZOOMABLE",
  "DT_LIGHTTABLE_LAYOUT_FILEMANAGER",
  "DT_LIGHTTABLE_LAYOUT_CULLING",
  "DT_LIGHTTABLE_LAYOUT_CULLING_DYNAMIC",
}

local sorts = {
  "DT_COLLECTION_SORT_NONE",
  "DT_COLLECTION_SORT_FILENAME",
  "DT_COLLECTION_SORT_DATETIME",
  "DT_COLLECTION_SORT_RATING",
  "DT_COLLECTION_SORT_ID",
  "DT_COLLECTION_SORT_COLOR",
  "DT_COLLECTION_SORT_GROUP",
  "DT_COLLECTION_SORT_PATH",
  "DT_COLLECTION_SORT_CUSTOM_ORDER",
  "DT_COLLECTION_SORT_TITLE",
  "DT_COLLECTION_SORT_DESCRIPTION",
  "DT_COLLECTION_SORT_ASPECT_RATIO",
  "DT_COLLECTION_SORT_SHUFFLE"
}

local sort_orders = {
  "DT_COLLECTION_SORT_ORDER_ASCENDING",
  "DT_COLLECTION_SORT_ORDER_DESCENDING"
}

local ratings = {
  "DT_COLLECTION_FILTER_ALL",
  "DT_COLLECTION_FILTER_STAR_NO",
  "DT_COLLECTION_FILTER_STAR_1",
  "DT_COLLECTION_FILTER_STAR_2",
  "DT_COLLECTION_FILTER_STAR_3",
  "DT_COLLECTION_FILTER_STAR_4",
  "DT_COLLECTION_FILTER_STAR_5",
  "DT_COLLECTION_FILTER_REJECT",
  "DT_COLLECTION_FILTER_NOT_REJECT"
}

local rating_comparators = {
  "DT_COLLECTION_RATING_COMP_LT",
  "DT_COLLECTION_RATING_COMP_LEQ",
  "DT_COLLECTION_RATING_COMP_EQ",
  "DT_COLLECTION_RATING_COMP_GEQ",
  "DT_COLLECTION_RATING_COMP_GT",
  "DT_COLLECTION_RATING_COMP_NE"
}

local zoom_levels = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}


-- save filter, view, and collection parameters

local current_layout = dt.gui.libs.lighttable_mode.layout()
local current_zoom_level = dt.gui.libs.lighttable_mode.zoom_level()
local current_rating = dt.gui.libs.filter.rating()
local current_rating_comparator = dt.gui.libs.filter.rating_comparator()
local current_sort = dt.gui.libs.filter.sort()
local current_sort_order = dt.gui.libs.filter.sort_order()

-- cycle through layouts and zooms

dt.print(_("lighttable layout and zoom level demonstration"))
sleep(2000)

for n, layout in ipairs(layouts) do
  dt.gui.libs.lighttable_mode.layout(layout)
  dt.print(string.format(_("set lighttable layout to %s"), layout))
  dt.print_log("set lighttable layout to " .. layout)
  sleep(1500)
  for i = 1, 10 do
    dt.gui.libs.lighttable_mode.zoom_level(i)
    dt.print(string.format(_("set zoom level to %d"), i))
    sleep(1500)
  end
  for i = 9, 1, -1 do
    dt.gui.libs.lighttable_mode.zoom_level(i)
    dt.print(string.format(_("set zoom level to %d"), i))
    sleep(1500)
  end
end

dt.print_log("finished layout and zoom level testing")
dt.print_log("starting sort demonstration")
-- cycle through sorts

dt.print(_("lighttable sorting demonstration"))
dt.print_log("setting lighttable to filemanager mode")
dt.gui.libs.lighttable_mode.layout("DT_LIGHTTABLE_LAYOUT_FILEMANAGER")
sleep(500)
dt.print_log("setting lighttable to zoom level 5")
dt.gui.libs.lighttable_mode.zoom_level(5)
dt.print_log("starting sorts")

for n, sort in ipairs(sorts) do
  dt.gui.libs.filter.sort(sort)
  dt.print(string.format(_("set lighttable sort to %s"), sort))
  sleep(1500)

  for m, sort_order in ipairs(sort_orders) do
    dt.gui.libs.filter.sort_order(sort_order)
    dt.print(string.format(_("sort order set to %s"), sort_order))
    sleep(1500)
  end
end

-- cycle through filters

dt.print(_("lighttable filtering demonstration"))

for n, rating in ipairs(ratings) do
  dt.gui.libs.filter.rating(rating)
  dt.print(string.format(_("set filter to %s"), rating))
  sleep(1500)

  for m, rating_comparator in ipairs(rating_comparators) do
    dt.gui.libs.filter.rating_comparator(rating_comparator)
    dt.print(string.format(_("set rating comparator to %s"), rating_comparator))
    sleep(1500)
  end
end

-- restore settings

dt.print(_("restoring settings"))

current_layout = dt.gui.libs.lighttable_mode.layout(current_layout)
current_zoom_level = dt.gui.libs.lighttable_mode.zoom_level(current_zoom_level)
current_rating = dt.gui.libs.filter.rating(current_rating)
current_rating_comparator = dt.gui.libs.filter.rating_comparator(current_rating_comparator)
current_sort =dt.gui.libs.filter.sort(current_sort)
current_sort_order = dt.gui.libs.filter.sort_order(current_sort_order)

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
local script_data = {}

script_data.metadata = {
  name = _("lighttable demo"),
  purpose = _("example demonstrating how to control lighttable display modes"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/lighttable_demo"
}

script_data.destroy = destroy

return script_data
