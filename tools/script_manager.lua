--[[
  This file is part of darktable,
  copyright (c) 2016 Bill Ferguson
  copyright (c) 2016 Tobias Jakobs
  copyright (c) 2014 Jérémy Rosen
  
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
    directory.  It may also be required from a luarc file.

    On startup script_manager checks to see what methods are available for downloading
    and/or updating the darktable lua scripts.  It also checks to see if there is an 
    existing scripts directory.  If there is an existing lua scripts directory then it is 
    read to see what scripts are present.  Scripts are sorted by "category" based on what 
    subdirectory they are found in, thus with a lua scripts directory that matched the current
    repository the categories would be contrib, examples, offical, and tools.  Each script has
    and Enable/Disable button to enable or disable the script.

    Additional "un-official" scripts may be downloaded from other sources and placed in a separate
    download directory.  These scripts all fall in a download category.  They also each have an 
    Enable/Disable button.

    Available download methods and directory locations can be configured.
]]

local dt = require "darktable"
local dd = require "lib/dtutils.debug"

collectgarbage("stop")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local LUA_DIR = dt.configuration.config_dir .. "/lua"
local LUA_GIT_DIR = LUA_DIR .. "/.git"
local LUA_SCRIPT_REPO = "https://github.com/darktable-org/lua-scripts.git"
local LUA_SCRIPT_ZIP_REPO = "https://github.com/darktable-org/lua-scripts/archive/master.zip"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

  -- - - - - - - - - - - - - - - - - - - - - - - - 
  -- L I F T E D  F R O M  D T U T I L S  L I B S
  -- - - - - - - - - - - - - - - - - - - - - - - - 


-- Thanks Tobias Jakobs
local function check_if_bin_exists(bin)
  local result = os.execute("which " .. bin)
  if not result then
    result = false
  end
  return result
end

-- Thanks Tobias Jakobs for the idea and the correction
local function check_if_file_exists(filepath)
  local result = os.execute("test -e " .. filepath)
  if not result then
    result = false
  end
  return result
end

local function split(str, pat)
   local t = {}  
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
        table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

-- Thanks to http://lua-users.org/wiki/SplitJoin
local function join(tabl, pat)
  returnstr = ""
  for i,str in pairs(tabl) do
    returnstr = returnstr .. str .. pat
  end
  return string.sub(returnstr, 1, -(pat:len() + 1))
end

local function prequire(req_name)
  dt.print_error("Loading " .. req_name)
  local status, lib = pcall(require, req_name)
  if status then
    dt.print_error("Loaded " .. req_name)
  else
    dt.print_error("Error loading " .. req_name)
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

  -- - - - - - - - - - - - - - - - - - - - - - - - 
  -- P R O G R A M  S P E C I F I C
  -- - - - - - - - - - - - - - - - - - - - - - - - 

local function setup_download_methods(have_method, name)
  if have_method then
    table.insert(sm.download_methods.available, name)
    if sm.not_initialized then
      dt.preferences.write("script_manager", "use_" .. name, "bool", true)
      if name == "git" then
        table.insert(sm.download_methods.single, name)
        if sm.can_use_git then
          table.insert(sm.download_methods.repo, name)
        else
          dt.preferences.write("script_manager", "use_" .. name, "bool", false)
        end
      else
        table.insert(sm.download_methods.repo, name)
        table.insert(sm.download_methods.single, name)
      end
    else
      if dt.preferences.read("script_manager", "use_" .. name, "bool") then
        if name == "git" then 
          table.insert(sm.download_methods.single, name)
          if sm.can_use_git then
            table.insert(sm.download_methods.repo, name)
          end
        else
          table.insert(sm.download_methods.repo, name)
          table.insert(sm.download_methods.single, name)
        end
      end
    end
  end
end

local function get_script_repo()
  local repo = dt.preferences.read("script_manager", "repository", "string")
  if not repo then
    if dt.preferences.read("script_manager", "use_git", "bool") then
      repo = LUA_SCRIPT_REPO
    else
      repo = LUA_SCRIPT_ZIP_REPO
    end
  end
  return repo
end

local function install_scripts(method, location)
  local result = true
  if not check_if_file_exists(sm.lua_scripts_dir) then
    os.execute("mkdir -p " .. sm.lua_scripts_dir)
  end
  if not (LUA_DIR == sm.lua_scripts_dir) then
    os.execute("ln -s " .. sm.lua_scripts_dir .. " " .. LUA_DIR)
  end

  if method == "git" then
    result = os.execute("cd " .. sm.lua_scripts_dir ..";git clone " .. location .. " .")
  else
    result = download_script_repository(method, location)
  end
  return result
end

local function update_scripts(method, location)
  if method == "git" then
    if check_if_file_exists(LUA_DIR .. "/.git") then
      os.execute("cd " .. LUA_DIR .. ";git pull")
    end
  else
    result = download_script_repository(method, location)
  end
  return result
end

local function add_script_data(req_name)
  -- add the script data
  local category,path,name,f,ft = string.match(req_name, "(.-)/(.-)(([^\\/]-)%.?([^%.\\/]*))$")

  if #sm.script_categories == 0 or not string.match(join(sm.script_categories, " "), category) then
    sm.script_categories[#sm.script_categories + 1] = category
    sm.script_names[category] = {}
  end
  if name then
    if not string.match(join(sm.script_names[category], " "), name) then
      sm.script_names[category][#sm.script_names[category] + 1] = name
      sm.script_paths[category .. "/" .. name] = category .. "/" .. path .. name
      if category == "download" then
        sm.have_downloads = true
      end
    end
  end
end

local function scan_scripts()
  -- scan the scripts
  local output = io.popen("cd " .. LUA_DIR .. " ;find -L . -name \\*.lua -print | sort")
  for line in output:lines() do
    local req_name = line:sub(3,-5)
    if not string.match(req_name, "script_manager") then  -- let's not include ourself
      if not string.match(req_name, "plugins") then -- skip plugins
        if not string.match(req_name, "lib/") then -- let's not try and run libraries
          if not string.match(req_name, "include_all") then -- skip include_all.lua
            if not string.match(req_name, "yield") then -- special case, because everything needs this
              add_script_data(req_name)
            else
              prequire(req_name) -- load yield.lua
            end
          end
        end
      end
    end
  end
  -- work around because we can't dynamically add a new stack child.  We create an empty child that will be
  -- populated with downloads as they occur.  If there are already downloads then this is just ignored

  add_script_data("download/")
end

-- get the script documentation, with some assumptions
local function get_script_doc(script)
  local description = nil
  f = io.open(LUA_DIR .. "/" .. script .. ".lua")
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

local function deactivate(script)
  -- deactivate it....

  -- turn any gui elements invisible (currently only lib)

  -- unload from package.loaded
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
      local starget = join({scat, target}, "/")
      if action == "Enable" then
        dt.preferences.write("script_manager", starget, "bool", true)
        dt.print_error("Loading " .. target)
        local status, lib = prequire(sm.script_paths[starget])
        if status then
          dt.print("Loaded " .. target)
        else
          dt.print_error("Error loading " .. target)
          dt.print_error("Error message: " .. lib)
        end
        self.label = "Disable " .. target
      else
        dt.preferences.write("script_manager", starget, "bool", false)
        deactivate(starget)
        dt.print(target .. " will not be active when darktable is restarted")
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
        local req = join({cat, sname}, "/")
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
        local req = join({cat, sname}, "/")
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
  if #sm.script_widgets["download"] == 0 then
    choices = choices - 1
    sm.have_downloads = false
  end
  cnt = 1
  for i, name in ipairs(choice_table) do 
    if (name == "download" and sm.have_downloads) or name ~= "download" then
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

local function download_script(method, location)
  local result = true
  if not check_if_file_exists(sm.download_scripts_dir) then
    os.execute("mkdir -p " .. sm.download_scripts_dir)
  end
  if not check_if_file_exists(LUA_DIR) then
    os.execute("mkdir -p " .. LUA_DIR)
  end
  if not check_if_file_exists(LUA_DIR .. "/download") then
    os.execute("ln -s " .. sm.download_scripts_dir .. " " .. LUA_DIR .. "/download")
  end
  local cmd = ""
  if method == "git" then
    cmd = "git clone "
  elseif method == "curl" then
    cmd = "curl -L -O -s "
  else
    cmd = "wget --quiet "
  end
  if method == "curl" or method == "wget" then
    location = string.gsub(location, "github.com", "raw.githubusercontent.com")
  end
  if not os.execute("cd " .. sm.download_scripts_dir .. ";" .. cmd .. location) then 
    result = false
  end
  if result then
    sm.have_downloads = true
  end
  return result
end

local function update_usable_download_methods()
  -- clear the usable download methods
  sm.download_methods.repo = {}
  sm.download_methods.single = {}

  -- reload it

  for _,widget in ipairs(sm.config_checkboxes) do
    if widget.value then
      local method = string.match(widget.label, ".- (.-)?$")
      if method == "git" then
        table.insert(sm.download_methods.single, method)
        if sm.can_use_git then
          table.insert(sm.download_methods.repo, method)
        end
      else
        table.insert(sm.download_methods.repo, method)
        table.insert(sm.download_methods.single, method)
      end
    end
  end
end

local function create_download_checkbox(var, val)
  return dt.new_widget("check_button"){
    label = "Use " .. var .."?",
    tooltip = "Will " .. var .. " show in the download options menu?",
    value = val,
  }
end

local function create_dir_widget(var, value, ttip)
  sm[var] = dt.preferences.read("script_manager", var, "string")
  if sm[var] == "" and sm.not_initialized then
    dt.preferences.write("script_manager", var, "string", value)
    sm[var] = value
  end

  return dt.new_widget("entry"){
    tooltip = ttip,
    text = sm[var],
  }
end


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N   P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- check api compatibility

dt.configuration.check_version(...,{3,0,0},{4,0,0})

-- set up a namespace to protect our stuff

script_manager = {}
sm = script_manager

sm.script_widgets = {}
sm.script_categories = {}
sm.script_names = {}
sm.script_paths = {}
sm.download_methods = {
  available = {},
  repo = {},
  single = {},
}
sm.main_menu_choices = {}
sm.main_stack_items = {}
sm.lua_scripts_dir = os.getenv("HOME") .. "/test/lua-scripts"
sm.download_scripts_dir = os.getenv("HOME") .. "/test/downloads"

-- see what we have to download with

local have_git = check_if_bin_exists("git")
local have_curl = check_if_bin_exists("curl")
local have_wget = check_if_bin_exists("wget")
local have_unzip = check_if_bin_exists("unzip")

-- if the lua scripts directory was cloned from a repository then we can use 
-- git to update it.  If not then git would fail to update.  We assume false
-- then check

sm.can_use_git = false

-- assume we have at least one method to download the scripts repository

sm.can_download_repository = true

-- do we have a script directory?

local have_scripts = check_if_file_exists(LUA_DIR)

-- did we create it with git?  If not, then we can't use git to update
-- if we don't have scripts then we can use git as one of the download methods

if have_scripts then
  sm.can_use_git = check_if_file_exists(LUA_GIT_DIR)
else
  sm.can_use_git = true
end

-- work around for dt.preferences.read returning false if they don't exist instead of nil
-- if you have a bool, is it false because it's false or false because it doesn't exist?

sm.not_initialized = not dt.preferences.read("script_manager", "initialized", "bool")

-- load up the tables with available download methods and repository download methods

setup_download_methods(have_git, "git")
setup_download_methods(have_curl, "curl")
setup_download_methods(have_wget, "wget")

if #sm.download_methods.available == 0 then
  dt.print("No way to download scripts.  Please install git, curl, or wget, and unzip.")
  sm.can_download_repository = false
end

  -- set up the install/update block
if sm.can_download_repository then

  sm.repository = dt.new_widget("entry")
  {
    text = get_script_repo(),
  }

  sm.download_method_selector = dt.new_widget("combobox"){
    label = "Repository Download Method",
    tooltip = "Select download method",
    value = 1, "placeholder",
    changed_callback = function(self)
      if self.value == "git" then
        sm.repository.text = LUA_SCRIPT_REPO
      else
        sm.repository.text = LUA_SCRIPT_ZIP_REPO
      end
    end
  }

  update_combobox_choices(sm.download_method_selector, sm.download_methods.repo, 1)

  local install_upgrade_text = "Install "
  if have_scripts then
    install_upgrade_text = "Update "
  end

  sm.install_upgrade_button = dt.new_widget("button"){
    label = install_upgrade_text .. "scripts",
    clicked_callback = function(self)
      if string.match(self.label, "^Install") then
        local result = install_scripts(sm.download_method_selector.value, sm.repository.text)
        if result then
          build_scripts_block()
          insert_scripts_block()
          have_scripts = 1
          self.label = "Upgrade scripts"
          dt.print("Installed scripts from " .. sm.repository.text)
        else
          dt.print("Error installing scripts from " .. sm.repository.text)
        end
      else
        local result = update_scripts(sm.download_method_selector.value, sm.repository.text)
        if result then
          build_scripts_block()
          dt.print("Updated scripts from " .. sm.repository.text)
        else
          dt.print("Error updating scripts from " .. sm.repository.text)
        end
      end
    end
  }

  sm.install_upgrade_box = dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("label"){ label = "Install/Update scripts" },
    sm.download_method_selector,
    sm.repository,
    sm.install_upgrade_button,
  }

  table.insert(sm.main_menu_choices, "Install/Update Scripts")
  table.insert(sm.main_stack_items, sm.install_upgrade_box)
end

  -- single script download block
if #sm.download_methods.available > 0 then

  sm.script_download_method_selector = dt.new_widget("combobox"){
    label = "Script Download Method",
    tooltip = "Select download method",
    value = 1, "placeholder",
  }

  update_combobox_choices(sm.script_download_method_selector, sm.download_methods.single, 1)

  sm.script_location = dt.new_widget("entry")
  {
    text = "",
    placeholder = "Location of script to download",
  }

  sm.download_button = dt.new_widget("button"){
    label = "Download Script",
    clicked_callback = function(_)
      local result = download_script(sm.script_download_method_selector.value, sm.script_location.text)
      if result then
        if have_scripts then
          build_scripts_block()
        else
          build_scripts_block()
          insert_scripts_block()
        end
      else
        dt.print("Failed to download " .. sm.script_location.value)
      end
    end
  }

  sm.download_script_box = dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("label"){ label = "Download a script" },
    sm.script_download_method_selector,
    sm.script_location,
    sm.download_button,
  }

  table.insert(sm.main_menu_choices, "Download a Single Script")
  table.insert(sm.main_stack_items, sm.download_script_box)
end

  -- configuration block
sm.config_checkboxes = {}

for _,method in ipairs(sm.download_methods.available) do 
  table.insert(sm.config_checkboxes, create_download_checkbox(method, dt.preferences.read("script_manager", "use_" .. method, "bool")))
end


sm.lua_scripts_entry = create_dir_widget("lua_scripts_dir", LUA_DIR, "Directory to store official scripts in")
sm.download_scripts_entry = create_dir_widget("download_scripts_dir", LUA_DIR .. "/downloads", "Directory to store downloaded unofficial scripts in")
sm.temp_dir_entry = create_dir_widget("temp_dir", "/tmp", "Directory to use for temporary storage")

sm.config_save_button = dt.new_widget("button"){
  label = "Save",
  clicked_callback = function(_)
    for _,widget in ipairs(sm.config_checkboxes) do
      local use_string = string.lower(string.gsub(string.match(widget.label, "(.+)?$"), " ", "_"))
      dt.preferences.write("script_manager", use_string, "bool", widget.value)
    end
    update_usable_download_methods()
    update_combobox_choices(sm.script_download_method_selector, sm.download_methods.single, 1)
    update_combobox_choices(sm.download_method_selector, sm.download_methods.repo, 1)
    dt.preferences.write("script_manager", "lua_scripts_dir", "string", sm.lua_scripts_entry.text)
    sm.lua_scripts_dir = sm.lua_scripts_entry.text
    dt.preferences.write("script_manager", "download_scripts_dir", "string", sm.download_scripts_entry.text)
    sm.download_scripts_dir = sm.download_scripts_entry.text
    dt.preferences.write("script_manager", "temp_dir", "string", sm.temp_dir_entry.text)
    sm.temp_dir = sm.temp_dir_entry.text
    dt.print("Configuration saved")
  end
}

sm.config_box = dt.new_widget("box"){
  orientation = "vertical",
  dt.new_widget("label"){ label = "Configuration" },
  dt.new_widget("box"){
    orientation = "vertical",
    unpack(sm.config_checkboxes),
  },
  dt.new_widget("label"){ label = "Official Scripts Directory"},
  sm.lua_scripts_entry,
  dt.new_widget("label"){ label = "Unofficial Scripts Directory"},
  sm.download_scripts_entry,
  dt.new_widget("label"){ label = "Temporary Directory"},
  sm.temp_dir_entry,
  sm.config_save_button,
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

-- register the module
dt.register_lib(
  "script_manager",     -- Module name
  "Script Manager",     -- Visible name
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

if have_scripts then

  -- scan for scripts and populate the categories
  build_scripts_block()

  -- add the widgets to the lib
  insert_scripts_block()

end

if sm.not_initialized then
  for i,name in ipairs(sm.main_menu_choices) do
    if name == "Configure" then
      sm.main_menu.value = i
    end
  end
end

dt.preferences.write("script_manager", "initialized", "bool", true)

collectgarbage("restart")
