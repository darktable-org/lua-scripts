local dt = require "darktable"

local choices = {"Option 1", "Option 2", "Option 3"}

-- hard code with no callback - works

local hcnc = dt.new_widget("combobox"){
  label = "Hard Code No Callback",
  tooltip = "Works",
  value = 1, "Option 1", "Option 2", "Option 3",
}

-- unpack table with no callback - works

local utnc = dt.new_widget("combobox"){
  label = "Unpack Table No Callback",
  tooltip = "Works",
  value = 1, unpack(choices),
}

-- hard code with callback - works
local hcwc = dt.new_widget("combobox"){
  label = "Hard Code With Callback",
  tooltip = "Works",
  value = 1, "Option 1", "Option 2", "Option 3",
  changed_callback = function(self)
    dt.print(self.value)
  end
}

-- unpack table with callback - broke
local utwc = dt.new_widget("combobox"){
  label = "Unpack Table With Callback",
  tooltip = "Broke",
  value = 1, unpack(choices),
  changed_callback = function(self)
    dt.print(self.value)
  end
}

-- register the lib so we can see it all in action

dt.register_lib(
  "comboxbox_error",     -- Module name
  "Combobox Error",     -- name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_BOTTOM", 100}},   -- containers
  dt.new_widget("box") -- widget
  {
    orientation = "vertical",
    hcnc,
    utnc,
    hcwc,
    utwc,
  },
  nil,-- view_enter
  nil -- view_leave
)
