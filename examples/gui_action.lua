local dt = require "darktable"

local NaN = 0/0

local wg = {}

local gettext = dt.gettext.gettext 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("gui action"),
  purpose = _("example of how to use darktable.gui.action() calls"),
  author = "Diederik ter Rahe",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/gui_action"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

wg.action = dt.new_widget("entry"){
    text = "lib/filter/view",
    placeholder = _("action path"),
    tooltip = _("enter the full path of an action, for example 'lib/filter/view'")
  }

wg.instance = dt.new_widget("combobox"){
  label = _("instance"),
  tooltip = _("the instance of an image processing module to execute action on"),
  "0", "+1", "-1", "+2", "-2", "+3", "-3", "+4", "-4", "+5", "-5", "+6", "-6", "+7", "-7", "+8", "-8", "+9", "-9"
}

wg.element = dt.new_widget("entry"){
  text = "",
  placeholder = _("action element"),
  tooltip = _("enter the element of an action, for example 'selection', or leave empty for default")
}

wg.effect = dt.new_widget("entry"){
  text = "next",
  placeholder = _("action effect"),
  tooltip = _("enter the effect of an action, for example 'next', or leave empty for default")
}

wg.speed = dt.new_widget("entry"){
  text = "1",
  placeholder = _("action speed"),
  tooltip = _("enter the speed to use in action execution, or leave empty to only read state")
}

wg.check = dt.new_widget("check_button"){
  label = _('perform action'),
  tooltip = _('perform action or only read return'),
  clicked_callback = function()
    wg.speed.sensitive = wg.check.value
  end,
  value = true
}

wg.return_value = dt.new_widget("entry"){
  text = "",
  sensitive = false
}

dt.register_lib(
    "execute_action",        -- Module name
    _("execute gui actions"),   -- name
    true,                    -- expandable
    false,                   -- resetable
    {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER", 100},
     [dt.gui.views.darkroom] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER", 100}},
    dt.new_widget("box")
    {
      orientation = "vertical",

      dt.new_widget("box")
      {
        orientation = "horizontal",
        dt.new_widget("label"){label = _("action path"), halign = "start"},
        wg.action
      },
      wg.instance,
      dt.new_widget("box")
      {
        orientation = "horizontal",
        dt.new_widget("label"){label = _("element"), halign = "start"},
        wg.element
      },
      dt.new_widget("box")
      {
        orientation = "horizontal",
        dt.new_widget("label"){label = _("effect"), halign = "start"},
        wg.effect
      },
      wg.check,
      dt.new_widget("box")
      {
        orientation = "horizontal",
        dt.new_widget("label"){label = _("speed"), halign = "start"},
        wg.speed
      },
      dt.new_widget("button")
      {
        label = _("execute action"),
        tooltip = _("execute the action specified in the fields above"),
        clicked_callback = function(_)
          local sp = NaN
          if wg.check.value then sp = wg.speed.text end
          wg.return_value.text = dt.gui.action(wg.action.text, tonumber(wg.instance.value), wg.element.text, wg.effect.text, tonumber(sp))
        end
      },
      dt.new_widget("box")
      {
        orientation = "horizontal",
        dt.new_widget("label"){label = "return value:", halign = "start"},
        wg.return_value
      },
    }
  )

local function restart()
  dt.gui.libs["execute_action"].visible = true
end

local function destroy()
  dt.gui.libs["execute_action"].visible = false
end

script_data.destroy = destroy
script_data.destroy_method = "hide"
script_data.restart = restart
script_data.show = restart

return script_data
