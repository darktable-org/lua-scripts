--[[
  This file is part of darktable,
  copyright (c) 2018 Bill Ferguson <wpferguson@gmail.com>
  
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
    script_manager.lua - a tool for managing the darktable lua scripts

    script_manager is designed to run as a standalone script so that it
    may be used as a drop in luarc file in the user's $HOME/.config/darktable
    ($HOME/AppData/Local/darktable on windows)  directory.  It may also be 
    required from a luarc file.

    On startup script_manager checks to see if there is an  existing scripts directory.  
    If there is an existing lua scripts directory then it is read to see what scripts are present.  
    Scripts are sorted by "category" based on what subdirectory they are found in, thus with a lua 
    scripts directory that matched the current repository the categories would be contrib, examples, 
    offical, and tools.  Each script has an Enable/Disable button to enable or disable the script.

    A link is created to the user's Downloads directory on linux, unix and MacOS.  Windows users must create the 
    link manually using mklink.exe.  Additional "un-official" scripts may be downloaded 
    from other sources and placed in the users Downloads directory.  These scripts all fall in a downloads category.  
    They also each have an Enable/Disable button.

]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"

local gettext = dt.gettext


-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("script_manager",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("script_manager", msgid)
end

collectgarbage("stop")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 
-- path separator
local PS = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS = dt.configuration.running_os == "windows" and "&" or ";"

local LUA_DIR = dt.configuration.config_dir .. PS .. "lua"
local LUA_SCRIPT_REPO = "https://github.com/darktable-org/lua-scripts.git"

dt.print_log("LUA_DIR is " .. LUA_DIR)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local script_manager = {}
local sm = script_manager

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function prequire(script)
  dt.print_log("Loading " .. script)
  local status, lib = pcall(require, script)
  if status then
    dt.print_log("Loaded " .. script)
  else
    dt.print_error("Error loading " .. script)
    dt.print_error(lib)
  end
  return status, lib
end

local function update_combobox_choices(combobox, choice_table, selected)
  local items = #combobox
  local choices = #choice_table
  for i, name in ipairs(choice_table) do 
    combobox[i] = name
  end
  if choices < items then
    for j = items, choices + 1, -1 do
      combobox[j] = nil
    end
  end
  combobox.value = selected
end

local function install_scripts()
  local result = false

  if df.check_if_file_exists(LUA_DIR) then
    if df.check_if_file_exists(LUA_DIR .. ".orig") then
      if dt.configuration.running_os == "windows" then
        os.execute("rmdir /s " .. LUA_DIR .. ".orig")
      else
        os.execute("rm -rf " .. LUA_DIR .. ".orig")
      end
    end
    os.rename(LUA_DIR, LUA_DIR .. ".orig")
  end

  local git = df.check_if_bin_exists("git")

  if not git then
    dt.print("ERROR: git not found.  Install or specify the location of the git executable.")
    return
  end

  local git_command = git .. " clone " .. sm.lua_repository .. " " .. LUA_DIR
  dt.print_log("install git command is " .. git_command)

  result = os.execute(git_command)

  if not df.check_if_file_exists(LUA_DIR .. PS .. "downloads") then
    os.execute("mkdir " .. LUA_DIR .. PS .. "downloads")
  end

  return result
end

local function update_scripts()
  local result = false

  local git = df.check_if_bin_exists("git")

  if not git then
    dt.print("ERROR: git not found.  Install or specify the location of the git executable.")
    return
  end

  local git_command = "cd " .. LUA_DIR .. " " .. CS .. " " .. git .. " pull"
  dt.print_log("update git command is " .. git_command)

  if dt.configuration.running_os == "windows" then
    result = dtsys.windows_command(git_command)
  else
    result = os.execute(git_command)
  end

  if dt.preferences.read("script_manager", "use_lua_scripts_version", "bool") and 
     dt.configuration.running_os == "windows" then
    use_lua_scripts_version()
  end

  return result
end

local function add_script_data(script_file)

  local pattern = "(.-)/(.-)(([^\\/]-)%.?([^%.\\/]*))$"
  if dt.configuration.running_os == "windows" then
    pattern = "(.-)\\(.-)(([^\\]-)%.?([^%.\\]*))$"
  end

  dt.print_log("processing " .. script_file)

  -- add the script data
  local category,path,name,filename,filetype = string.match(script_file, pattern)

  if #sm.script_categories == 0 or not string.match(du.join(sm.script_categories, " "), category) then
    sm.script_categories[#sm.script_categories + 1] = category
    sm.script_names[category] = {}
  end
  if name then
    if not string.match(du.join(sm.script_names[category], " "), name) then
      sm.script_names[category][#sm.script_names[category] + 1] = name
      sm.script_paths[category .. PS .. name] = category .. PS .. path .. name
      if category == "downloads" then
        sm.have_downloads = true
      end
    end
  end
end

local function scan_scripts()
  local find_cmd = "find -L " .. LUA_DIR .. " -name \\*.lua -print | sort"
  if dt.configuration.running_os == "windows" then
    find_cmd = "dir /b/s " .. LUA_DIR .. "\\*.lua | sort"
  end
  -- scan the scripts
  local output = io.popen(find_cmd)
  for line in output:lines() do
    local l = string.gsub(line, LUA_DIR .. PS, "") -- strip the lua dir off
    local script_file = l:sub(1,-5)
    if not string.match(script_file, "script_manager") then  -- let's not include ourself
      if not string.match(script_file, "plugins") then -- skip plugins
        if not string.match(script_file, "lib" .. PS) then -- let's not try and run libraries
          if not string.match(script_file, "include_all") then -- skip include_all.lua
            if not string.match(script_file, "yield") then -- special case, because everything needs this
              add_script_data(script_file)
            else
              prequire(script_file) -- load yield.lua
            end
          end
        end
      end
    end
  end
  -- work around because we can't dynamically add a new stack child.  We create an empty child that will be
  -- populated with downloads as they occur.  If there are already downloads then this is just ignored

  add_script_data("downloads" .. PS)
end

-- get the script documentation, with some assumptions
local function get_script_doc(script)
  local description = nil
  local ps = dt.configuration.running_os == windows and "\\" or "/"
  f = io.open(LUA_DIR .. ps .. script .. ".lua")
  if f then
    -- slurp the file
    local content = f:read("*all")
    f:close()
    -- assume that the second block comment is the documentation
    description = string.match(content, "%-%-%[%[.-%]%].-%-%-%[%[(.-)%]%]")
  else
    dt.print_error("Cant read from " .. script)
  end
  if description then
    return description
  else
    return "No documentation available"
  end
end

local function activate(script, scriptname)
  dt.print_log("activating " .. scriptname)
  local status, err = prequire(sm.script_paths[script])
  -- do it
  if status then
    dt.preferences.write("script_manager", script, "bool", true)
    dt.print("Loaded " .. scriptname)
  else
    dt.print(scriptname .. " failed to load")
    dt.print_error("Error loading " .. scriptname)
    dt.print_error("Error message: " .. err)
  end
  return status
end

local function deactivate(script, scriptname)
  -- presently the lua api doesn't support unloading gui elements therefore
  -- we just mark then inactive for the next time darktable starts

  -- deactivate it....

  dt.preferences.write("script_manager", script, "bool", false)
  dt.print_log("setting " .. scriptname .. " to not start")
  dt.print(scriptname .. " will not be active when darktable is restarted")
end

local function create_enable_disable_button(btext, sname, req)
  return dt.new_widget("button")
  {
    label = btext .. sname,
    tooltip = get_script_doc(req),
    clicked_callback = function (self)
      -- split the label into action and target
      local action, target = string.match(self.label, "(.+) (.+)")
      -- load the script if it's not loaded
      local scat = ""
      for _,scatn in ipairs(sm.script_categories) do
        if string.match(table.concat(sm.script_names[scatn]), target) then
          scat = scatn 
        end
      end
      local starget = du.join({scat, target}, PS)
      if action == "Enable" then
        local status = activate(starget, target)
        if status then
          self.label = "Disable " .. target
        end
      else
        deactivate(starget, target)
        self.label = "Enable " .. target
      end
    end
  }
end

local function load_script_stack()
  -- load the scripts
  table.sort(sm.script_categories)
  for _,cat in ipairs(sm.script_categories) do
    local tmp = {}
    table.sort(sm.script_names[cat])
    if not sm.script_widgets[cat] then
      for _,sname in ipairs(sm.script_names[cat]) do
        local req = du.join({cat, sname}, "/")
        local btext = "Enable "
        if dt.preferences.read("script_manager", req, "bool") then
          status, lib = prequire(sm.script_paths[req])
          if status then 
            btext = "Disable "
          else
            dt.print_error("Error loading " .. sname)
  --          dt.print_error("Error message: " .. lib)
          end
        else
          dt.preferences.write("script_manager", req, "bool", false)
        end
        tmp[#tmp + 1] = create_enable_disable_button(btext, sname, req)
      end

      sm.script_widgets[cat] = dt.new_widget("box")
      {
        orientation = "vertical",
        table.unpack(tmp),
      }
    elseif #sm.script_widgets[cat] ~= #sm.script_names[cat] then
      for index,sname in ipairs(sm.script_names[cat]) do
        local req = du.join({cat, sname}, "/")
        dt.print_error("script is " .. sname .. " and index is " .. index)
        if sm.script_widgets[cat][index] then
          sm.script_widgets[cat][index] = nil
        end
        sm.script_widgets[cat][index] = create_enable_disable_button("Enable ", sname, req)
      end
    end
  end
  if not sm.script_stack then
    sm.script_stack = dt.new_widget("stack"){}
    for i,cat in ipairs(sm.script_categories) do
      sm.script_stack[i] = sm.script_widgets[cat]
    end
    sm.script_stack.active = 1
  end
end

local function update_stack_choices(combobox, choice_table)
  sm.have_downloads = true
  local items = #combobox
  local choices = #choice_table
  if #sm.script_widgets["downloads"] == 0 then
    choices = choices - 1
    sm.have_downloads = false
  end
  cnt = 1
  for i, name in ipairs(choice_table) do 
    if (name == "downloads" and sm.have_downloads) or name ~= "downloads" then
      combobox[cnt] = name
      cnt = cnt + 1
    end
  end
  if choices < items then
    for j = items, choices + 1, -1 do
      combobox[j] = nil
    end
  end
  combobox.value = 1
end

local function build_scripts_block()
  -- build the whole script block
  scan_scripts()

    -- set up the stack for the choices
  load_script_stack()

  if not sm.category_selector then
    -- set up the combobox for the categories

    sm.category_selector = dt.new_widget("combobox"){
      label = "Category",
      tooltip = "Select the script category",
      value = 1, "placeholder",
      changed_callback = function(self)
        local cnt = 1
        for i,cat in ipairs(sm.script_categories) do
          if cat == self.value then
            sm.script_stack.active = i
          end
        end
      end
    }
  end

  update_stack_choices(sm.category_selector, sm.script_categories)

  if not sm.scripts then
    sm.scripts = dt.new_widget("box"){
      orientation = "vertical",
      dt.new_widget("label"){ label = "Scripts" },
      sm.category_selector,
      sm.script_stack,
    }
  end
end

local function insert_scripts_block()
  table.insert(sm.main_menu_choices, "Enable/Disable Scripts")
  update_combobox_choices(sm.main_menu, sm.main_menu_choices, 1)
  sm.main_stack[#sm.main_stack + 1] = sm.scripts
end

local function use_lua_scripts_version()
  if dt.configuration.running_os == "windows" then
    -- copy tools\script_manger.lua to luarc
    df.file_copy(LUA_DIR .. PS .. "tools\\script_manager.lua", dt.configuration.config_dir .. PS .. "luarc")
  else
    -- create a symbolic link from luarc to  tools/script_manager.lua
    if df.check_if_file_exists(dt.configuration.config_dir .. "/luarc") then
      os.remove(dt.configuration.config_dir .. "/luarc")
    end
    os.execute("ln -s " .. LUA_DIR .. "/tools/script_manager.lua " .. dt.configuration.config_dir .. "/luarc")
  end
end

local function link_downloads_directory()
  if not df.check_if_file_exists("$HOME/Downloads") then
    os.execute("mkdir $HOME/Downloads")
  end
  if df.check_if_file_exists(LUA_DIR .. "/downloads") then
    os.remove(LUA_DIR .. "/downloads")
  end
  os.execute("ln -s " .. "$HOME/Downloads " .. LUA_DIR .. "/downloads")
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- api check

dt.configuration.check_version(...,{5,0,0})

-- set up tables to contain all the widgets and choices

sm.script_widgets = {}
sm.script_categories = {}
sm.script_names = {}
sm.script_paths = {}
sm.main_menu_choices = {}
sm.main_stack_items = {}

-- figure out the path separator

local ps = dt.configuration.running_os == "windows" and "\\" or "/"

-- see if we've run this before

sm.initialized = dt.preferences.read("script_manager", "initialized", "bool")

if not sm.initialized then
  -- write out preferences
  dt.preferences.write("script_manager", "lua_repository", "string", LUA_SCRIPT_REPO)
  dt.preferences.write("script_manager", "use_distro_version", "bool", false)
  dt.preferences.write("script_manager", "link_downloads_directory", "bool", false)
  dt.preferences.write("script_manager", "initialized", "bool", true)
end

sm.have_scripts = df.check_if_file_exists(LUA_DIR)

sm.git_managed = df.check_if_file_exists(LUA_DIR .. ps .. ".git")

if sm.have_scripts then
  dt.print_log("found lua scripts directory")
else
  dt.print_log("lua scripts directory not found")
end

if sm.git_managed then
  dt.print_log("scripts managed by git")
else
  dt.print_log("scripts not managed")
end

local git = df.check_if_bin_exists("git")

if git then
  dt.print_log("git found at " .. git)
  sm.need_git = false
else
  dt.print_log("git not found")
  sm.need_git = true
end

sm.repository = dt.new_widget("entry")
{
  text = dt.preferences.read("script_manager", "lua_repository", "string"),
  editable = true,
}

sm.need_install = false

local install_update_text = _("install")
if sm.have_scripts and sm.git_managed then
  install_update_text = _("update")
else
  sm.need_install = true
end

sm.install_update_button = dt.new_widget("button"){
  label = install_update_text .. _(" scripts"),
  clicked_callback = function(self)
    sm.lua_repository = sm.repository.text
    dt.preferences.write("script_manager", "lua_repository", "string", sm.repository.text)
    if sm.need_install then
      local result = install_scripts()
      if result then
        build_scripts_block()
        insert_scripts_block()
        sm.have_scripts = true
        sm.git_managed = true
        sm.need_install = false
        self.label = _("update scripts")
        dt.print(_("installed scripts from " .. sm.repository.text))
      else
        dt.print(_("Error installing scripts from " .. sm.repository.text))
      end
    else
      local result = update_scripts()
      if result then
        --build_scripts_block()
        dt.print(_("updated scripts from " .. sm.repository.text))
      else
        dt.print(_("Error updating scripts from " .. sm.repository.text))
      end
    end
  end
}

if not sm.need_install then
  sm.reinstall_button = dt.new_widget("button"){
    label = "reinstall scripts",
    clicked_callback = function(self)
      sm.lua_repository = sm.repository.text
      dt.preferences.write("script_manager", "lua_repository", "string", sm.repository.text)
      local result = install_scripts()
      if result then
        build_scripts_block()
        insert_scripts_block()
        sm.have_scripts = true
        sm.git_managed = true
        sm.need_install = false
        sm.install_update_button.label = "update scripts"
        dt.print(_("reinstalled scripts from " .. sm.repository.text))
        dt.print_log(_("scripts reinstalled"))
      else
        dt.print(_("ERROR: script reinstallation failed"))
        dt.print_error(_("script reinstall failed"))
      end
    end
  }

  sm.install_update_widgets = {
    sm.install_update_button,
    sm.reinstall_button,
  }
else
  sm.install_update_widgets = {
    sm.install_update_button,
  }
end

sm.install_update_box = dt.new_widget("box"){
  orientation = "vertical",
  dt.new_widget("label"){ label = "Install/Update scripts" },
  table.unpack(sm.install_update_widgets),
}

table.insert(sm.main_menu_choices, "Install/Update Scripts")
table.insert(sm.main_stack_items, sm.install_update_box)

-- configuration items

sm.repository_update = dt.new_widget("button"){
  label = "update",
  clicked_callback = function()
    dt.preferences.write("script_manager", "lua_repository", "string", sm.repository.text)
    sm.install_update_button.label = "install"
    sm.install_update_button.sensitive = true
    sm.reinstall_button.sensitive = false
    sm.need_install = true
  end
}

sm.repository_reset = dt.new_widget("button"){
  label = "reset",
  clicked_callback = function()
    sm.repository.text = LUA_SCRIPT_REPO
    dt.preferences.write("script_manager", "lua_repository", "string", LUA_SCRIPT_REPO)
    sm.install_update_button.label = "install"
    sm.install_update_button.sensitive = true
    sm.reinstall_button.sensitive = false
    sm.need_install = true
  end
}

sm.update_reset = dt.new_widget("box"){
  orientation = "horizontal",
  sm.repository_update,
  sm.repository_reset,
}

-- replace standalone version of script_manager with distributed version, i.e. tools/script_manager.lua
  -- link on linux/MacOS, copy on windows
  -- this option won't be active until the repository version of this script is accepted

sm.use_lua_scripts_version = dt.new_widget("check_button"){
  label = "Use lua scripts distributed version",
  tooltip = "Use the standalone version (false) or the distributed version (true)",
  value = dt.preferences.read("script_manger", "use_distro_version", "bool"),
  clicked_callback = function(self)
    if dt.preferences.read("script_manger", "use_distro_version", "bool") == self.value then
      -- do nothing
    else
      sm.apply_configuration.sensitive = true
    end
  end
}

-- link downloads to $HOME/downloads on linux and MacOS

sm.link_downloads_directory = dt.new_widget("check_button"){
  label = "Link lua/downloads to $HOME/Downloads",
  tooltip = "Linking the directories enables dropping a script in $HOME/downloads\nand having it recognized the next time darktable starts",
  value = dt.preferences.read("script_manager", "link_downloads_directory", "bool"),
  clicked_callback = function(self)
    if dt.preferences.read("script_manager", "link_downloads_directory", "bool") == self.value then
      -- do nothing
    else
      sm.apply_configuration.sensitive = true
    end
  end
}

sm.apply_configuration = dt.new_widget("button"){
  label = "Apply",
  sensitive = false,
  clicked_callback = function(self)
    dt.preferences.write("script_manager", "use_distro_version", "bool", sm.use_lua_scripts_version.value)
    if sm.use_lua_scripts_version.value then
      use_lua_scripts_version()
    end
    if dt.configuration.running_os ~= "windows" then
      dt.preferences.write("script_manager", "link_downloads_directory", "bool", sm.link_downloads_directory.value)
      if sm.link_downloads_directory.value then
        link_downloads_directory()
      end
    end
  end
}

-- get git location on windows

sm.git_location = df.executable_path_widget({"git"})

sm.configuration_widgets = {
  sm.repository,
  sm.update_reset,
  dt.new_widget("separator"){},
  dt.new_widget("separator"){},
}

if dt.configuration.running_os == "windows" or sm.need_git then
  sm.configuration_widgets[#sm.configuration_widgets + 1] = sm.git_location
end

if dt.configuration.running_os ~= "windows" then
  --sm.configuration_widgets[#sm.configuration_widgets + 1] = sm.use_lua_scripts_version
  sm.configuration_widgets[#sm.configuration_widgets + 1] = sm.link_downloads_directory
end
sm.configuration_widgets[#sm.configuration_widgets + 1] = sm.apply_configuration

sm.config_box = dt.new_widget("box"){
  orientation = "vertical",
  dt.new_widget("label") { label = "Configuration" },
  table.unpack(sm.configuration_widgets),
}


table.insert(sm.main_menu_choices, "Configure")
table.insert(sm.main_stack_items, sm.config_box)

-- set up the outside stack for config, install/update, and download

  -- make a stack for the choices

sm.main_stack = dt.new_widget("stack"){
  table.unpack(sm.main_stack_items),
}

  -- make a combobox for the selector

sm.main_menu = dt.new_widget("combobox"){
  label = "Action",
  tooltip = "Select the action you want to perform",
  value = 1, "No actions available",
  changed_callback = function(self)
    for pos,str in ipairs(sm.main_menu_choices) do
      if self.value == str then
        sm.main_stack.active = pos
        dt.preferences.write("script_manager", "sm_main_menu_value", "integer", pos)
      end
    end
  end
}

if #sm.main_menu_choices > 0 then
  update_combobox_choices(sm.main_menu, sm.main_menu_choices, 1)
end

sm.main_box = dt.new_widget("box"){
  orientation = "vertical",
  sm.main_menu,
  sm.main_stack,
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- register the module
dt.register_lib(
  "script_manager",     -- Module name
  "script manager",     -- Visible name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_BOTTOM", 100}},   -- containers
  dt.new_widget("box") -- widget
  {
    orientation = "vertical",
    sm.main_box,
  },
  nil,-- view_enter
  nil -- view_leave
)

-- set up the scripts block if we have them otherwise we'll wait until we download them

if sm.have_scripts then

  -- scan for scripts and populate the categories
  build_scripts_block()

  -- add the widgets to the lib
  insert_scripts_block()

  sm.main_menu.selected = 3

end

collectgarbage("restart")
