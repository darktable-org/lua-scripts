--[[
   LABELS TO TAGS
   Allows the mass-application of tags using color labels and ratings
   as a guide.

   AUTHOR
   August Schwerdfeger (august@schwerdfeger.name)

   INSTALLATION
   * Copy this file into $CONFIGDIR/lua/, where CONFIGDIR
   is your darktable configuration directory
   * Add the following line in the file $CONFIGDIR/luarc:
   require "LabelsToTags"

   ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
   None.

   USAGE
   In your 'luarc' file or elsewhere, use the function
   'register_tag_mapping', defined in this module, to specify
   one or more tag mappings for use by the module.
   Any mappings so registered will be selectable, according
   to their given names, in the module's "mapping" combo box.

   A mapping takes the form of a table mapping patterns to
   lists of tags. A pattern consists of 6 characters, of which
   the first five represent color labels and the last the rating.
   Each color label character may be '+', '-', or '*',
   indicating that for this pattern to match, the corresponding
   color label, respectively, must be on, must be off, or can be
   either. Similarly, the rating character may be a numeral
   between 0 and 5, "R" for rejected, or "*" for "any value."

   An example call to 'register_tag_mapping' is provided in a
   comment at the end of this file.

   When the "Start" button is pressed, the module will
   iterate over each selected image and check the state of
   that image's color labels and rating against each pattern
   defined in the selected mapping. For each pattern that
   matches, the corresponding tags will be added to the
   image. Any such tag not already existing in the database
   will be created.

   LICENSE
   LGPLv2+

]]

local darktable = require("darktable")
local du = require "lib/dtutils"

du.check_min_api_version("7.0.0", "LabelsToTags") 

local gettext = darktable.gettext.gettext

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("labels to tags"),
  purpose = _("allows the mass-application of tags using color labels and ratings as a guide"),
  author = "August Schwerdfeger (august@schwerdfeger.name)",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/LabelsToTags"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- Lua 5.3 no longer has "unpack" but "table.unpack"
unpack = unpack or table.unpack

local ltt = {}
ltt.module_installed = false
ltt.event_registered = false

local LIB_ID = _("LabelsToTags")

-- Helper functions: BEGIN

local function keySet(t)
   local rv = {}
   for k,_ in pairs(t) do
      table.insert(rv,k)
   end
   table.sort(rv)
   return(rv)
end

local function generateLabelHash(img)
   local hash = ""
   hash = hash .. (img.red and "+" or "-")
   hash = hash .. (img.yellow and "+" or "-")
   hash = hash .. (img.green and "+" or "-")
   hash = hash .. (img.blue and "+" or "-")
   hash = hash .. (img.purple and "+" or "-")
   hash = hash .. (img.rating == -1 and "R" or tostring(img.rating))
   return(hash)
end

local function hashMatch(hash,pattern)
   if #(hash) ~= #(pattern) then return(false) end
   for i = 0,#hash do
      if string.sub(hash,i,i) ~= string.sub(pattern,i,i) and
      string.sub(pattern,i,i) ~= "*" then
	 return(false)
      end
   end
   return(true)
end

-- Helper functions: END




local initialAvailableMappings = {
   [_("colors")] = { ["+*****"] = { _("red") },
      ["*+****"] = { _("yellow") },
      ["**+***"] = { _("green") },
      ["***+**"] = { _("blue") },
      ["****+*"] = { _("purple") } },
   [_("single colors")] = { ["+----*"] = { _("red"), _("only red") },
      ["-+---*"] = { _("yellow"), _("only yellow") },
      ["--+--*"] = { _("green"), _("only green") },
      ["---+-*"] = { _("blue"), _("only blue") },
      ["----+*"] = { _("purple"), _("only purple") } },
   [_("ratings")] = { ["*****0"] = { _("no stars"), _("not rejected") },
      ["*****1"] = { _("one star"), _("not rejected") },
      ["*****2"] = { _("two stars"), _("not rejected") },
      ["*****3"] = { _("three stars"), _("not rejected") },
      ["*****4"] = { _("four stars"), _("not rejected") },
      ["*****5"] = { _("five stars"), _("not rejected") },
      ["*****R"] = { _("rejected") } }
}

local availableMappings = {}

local function getAvailableMappings()
   if availableMappings == nil or next(availableMappings) == nil then
      return(initialAvailableMappings)
   else
      return(availableMappings)
   end
end

local function getComboboxTooltip()
   if availableMappings == nil or next(availableMappings) == nil then
      return(_("no registered mappings -- using defaults"))
   else
      return(_("select a label-to-tag mapping"))
   end
end

local mappingComboBox = darktable.new_widget("combobox"){
   label = _("mapping"),
   value = 1,
   tooltip = getComboboxTooltip(),
   reset_callback = function(selfC)
      if selfC == nil then
	     return
      end
      i = 1
      for _,m in pairs(keySet(getAvailableMappings())) do
   	 selfC[i] = m
   	 i = i+1
      end
      n = #selfC
      for j = i,n do
	     selfC[i] = nil
      end
      selfC.value = 1
      selfC.tooltip = getComboboxTooltip()
   end,
   unpack(keySet(getAvailableMappings()))
}

local function doTagging(selfC)
   local job = darktable.gui.create_job(string.format(_("labels to tags (%d image%s)"), #(darktable.gui.action_images), (#(darktable.gui.action_images) == 1 and "" or "s")), true)
   job.percent = 0.0
   local pctIncrement = 1.0 / #(darktable.gui.action_images)

   local availableMappings = getAvailableMappings()
   local memoizedTags = {}
   for _,img in ipairs(darktable.gui.action_images) do
      local tagsToApply = {}
      local hash = generateLabelHash(img)
      for k,v in pairs(availableMappings[mappingComboBox.value]) do
   	 if hashMatch(hash,k) then
   	    for _,tag in ipairs(v) do
   	       tagsToApply[tag] = true
   	    end
   	 end
      end
      for k,_ in pairs(tagsToApply) do
   	 if memoizedTags[k] == nil then
   	    memoizedTags[k] = darktable.tags.create(k)
   	 end
   	 darktable.tags.attach(memoizedTags[k],img)
      end
      job.percent = job.percent + pctIncrement
   end
   job.valid = false
end

ltt.my_widget = darktable.new_widget("box") {
   orientation = "vertical",
   mappingComboBox,
   darktable.new_widget("button") {
      label = _("start"),
      tooltip = _("tag all selected images"),
      clicked_callback = doTagging
   }
}

local PATTERN_PATTERN = "^[+*-][+*-][+*-][+*-][+*-][0-5R*]$"

darktable.register_tag_mapping = function(name, mapping)
   if availableMappings[name] ~= nil then
      darktable.print_error("Tag mapping '" .. name .. "' already registered")
      return
   end
   for pattern,tags in pairs(mapping) do
      if string.match(pattern,PATTERN_PATTERN) == nil then
   	 darktable.print_error("In tag mapping '" .. name .. "': Pattern '" .. pattern .. "' invalid")
   	 return
      end
      for _,tag in ipairs(tags) do
   	 if type(tag) ~= "string" then
   	    darktable.print_error("In tag mapping '" .. name .. "': All tag mappings must be lists of strings")
   	    return
   	 end
      end
   end
   availableMappings[name] = mapping
   mappingComboBox.reset_callback(mappingComboBox)
end

local function install_module()
  if not ltt.module_installed then
   darktable.register_lib(LIB_ID,_("labels to tags"),true,true,{
              [darktable.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER",20},
                            },ltt.my_widget,nil,nil)
    ltt.module_installed = true
  end
end

local function destroy()
   darktable.gui.libs[LIB_ID].visible = false
end

local function restart()
   darktable.gui.libs[LIB_ID].visible = true
end

--[[
darktable.register_tag_mapping("Example",
			       { ["+----*"] = { "Red", "Only red" },
				 ["-+---*"] = { "Yellow", "Only yellow" },
				 ["--+--*"] = { "Green", "Only green" },
				 ["---+-*"] = { "Blue", "Only blue" },
				 ["****+*"] = { "Purple" },
				 ["----+*"] = { "Only purple" },
				 ["*****1"] = { "One star" },
				 ["*****R"] = { "Rejected" } })
]]

if darktable.gui.current_view().id == "lighttable" then
  install_module()
else
  if not ltt.event_registered then
    darktable.register_event(
      LIB_ID, "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    ltt.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
