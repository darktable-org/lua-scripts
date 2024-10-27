--[[ photils Auto Tagging plugin
    copyright (c) 2020 Tobias Scheck

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
--]]

--[[
   A darktable plugin that tries to predict keywords based on the selected image.
   This plugin uses photils-cli to handle this task. Photils-cli is an application
   that passes the image through a neural network, classifies it, and extracts the
   suggested tags. Everything happens offline without the need that your data are
   sent over the internet.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * photils-cli - https://github.com/scheckmedia/photils-cli at the moment only
      available for Linux and MacOS

    USAGE
    * require this script from your main lua file
      To do this add this line to the file .config/darktable/luarc:
      require "contrib/photils"
    * Select an image
    * Press "get tags"
    * Select the tags you want from a list of suggestions
    * Press "Attach .. Tags" to add the selected tags to your image
--]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"

local MODULE_NAME = "photils"
du.check_min_api_version("7.0.0", MODULE_NAME) 

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("photils"),
  purpose = _("suggest tags based on image classification"),
  author = "Tobias Scheck",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/photils"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them


local PS = dt.configuration.running_os == "windows" and "\\" or "/"

local exporter = dt.new_format("jpeg")
exporter.quality = 80
exporter.max_height = 224
exporter.max_width = 224

-- helper functions

local function num_keys(tbl)
    local num = 0
    for _ in pairs(tbl) do num = num + 1 end
    return num
end

local function has_key(tbl, value)
    for k, _ in pairs(tbl) do
        if k == value then
            return true
        end
    end

    return false
end

local photils_installed = df.check_if_bin_exists("photils-cli")

--[[
    local state object

    maybe per_page is a preference variable but I think 10
    is a good value for the ui
]]
local PHOTILS = {
    tags = {},
    confidences = {},
    page = 1,
    per_page = 10,
    selected_tags = {},
    in_pagination = false,
    tagged_image = "",
    module_installed = false,
    event_registered = false,
    plugin_display_views = {
      [dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100},
      [dt.gui.views.darkroom] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER", 100}
    },
}

local GUI = {
    container = dt.new_widget("box") {
        orientation = "vertical",
        sensitive = true,
        dt.new_widget("button") {
            label = _("get tags"),
            sensitive = photils_installed,
            clicked_callback = function() PHOTILS.on_tags_clicked() end
        },
        reset_callback = function() PHOTILS.on_reset(true) end
    },
    stack = dt.new_widget("stack"),
    prev_button = dt.new_widget("button") {
        label = "<",
        sensitive = false,
        clicked_callback = function()
            PHOTILS.page = PHOTILS.page - 1
            PHOTILS.paginate()
        end
    },
    next_button = dt.new_widget("button") {
        label = ">",
        sensitive = false,
        clicked_callback = function()
            PHOTILS.page = PHOTILS.page + 1
            PHOTILS.paginate()
        end
    },
    tag_box = dt.new_widget("box") {orientation = "vertical"},
    tag_view = dt.new_widget("box") {orientation = "vertical"},
    page_label = dt.new_widget("label") {label = ""},
    error_view = dt.new_widget("box") {orientation = "vertical"},
    warning_label = dt.new_widget("label") {
        label = ""
    },
    restart_required_label = dt.new_widget("label") {
        label = _("requires a restart to be applied")
    },
    attach_button = dt.new_widget("button") {
        label = "",
        sensitive = false,
        clicked_callback = function(self) PHOTILS.attach_tags() end
    },
    confidence_slider = dt.new_widget("slider") {
        step = 1,
        digits = 0,
        value = 90,
        hard_max = 100,
        hard_min = 0,
        soft_max = 100,
        soft_min = 0,
        label = _("min confidence value")
    },
    warning = dt.new_widget("label")
}

function PHOTILS.image_changed()
    local current_image = tostring(dt.gui.selection()[1])
    if current_image ~= PHOTILS.tagged_image then
        if PHOTILS.tagged_image ~= "" then
            PHOTILS.tagged_image_has_changed()
        end

        PHOTILS.tagged_image = tostring(current_image)
    end
end

function PHOTILS.tagged_image_has_changed()
    GUI.warning.label = _("the suggested tags were not generated\n for the currently selected image!")
end

function PHOTILS.paginate()
    PHOTILS.in_pagination = true
    local num_pages = math.ceil(#PHOTILS.tags / PHOTILS.per_page)
    GUI.page_label.label = string.format(_("  page %s of %s  "), PHOTILS.page,
                                         num_pages)

    if PHOTILS.page <= 1 then
        PHOTILS.page = 1
        GUI.prev_button.sensitive = false
    else
        GUI.prev_button.sensitive = true
    end

    if PHOTILS.page > num_pages - 1 then
        PHOTILS.page = num_pages
        GUI.next_button.sensitive = false
    else
        GUI.next_button.sensitive = true
    end

    --[[
        calculates the start positon in the tag array based on the current page
        and takes N tags from that array to show these in darktable
        e.g. page 1 goes from 1 to 10, page 2 from 11 to 20 a.s.o.
        the paginaton approach is related to a problem with the dynamic addition
        of mutliple widgets https://github.com/darktable-org/darktable/issues/4934#event-3318100463
    ]]--
    local offset = ((PHOTILS.page - 1) * PHOTILS.per_page) + 1
    local tag_index = 1
    for i = offset, offset + PHOTILS.per_page - 1, 1 do
        local tag = PHOTILS.tags[i]
        local conf = PHOTILS.confidences[i]

        GUI.tag_box[tag_index].value = has_key(PHOTILS.selected_tags, tag)

        if tag then
            if dt.preferences.read(MODULE_NAME, "show_confidence", "bool") then
                tag = tag .. string.format(" (%.3f)", conf)
            end

            GUI.tag_box[tag_index].label = tag
            GUI.tag_box[tag_index].sensitive = true
        else
            GUI.tag_box[tag_index].label = ""
            GUI.tag_box[tag_index].sensitive = false
        end
        tag_index = tag_index + 1
    end

    PHOTILS.in_pagination = false
end

function PHOTILS.attach_tags()
    local num_selected = #dt.gui.selection()
    local job = dt.gui.create_job(_("apply tag to image"), true)

    for i = 1, num_selected, 1 do
        local image = dt.gui.selection()[i]
        for tag, _ in pairs(PHOTILS.selected_tags) do
            local dt_tag = dt.tags.create(tag)
            dt.tags.attach(dt_tag, image)
        end

        job.percent = i / num_selected
    end

    dt.print(_("tags successfully attached to image"))
    job.valid = false
end

function PHOTILS.get_tags(image, with_export)

    local tmp_file = df.create_tmp_file()
    local in_arg = df.sanitize_filename(tostring(image))
    local out_arg = df.sanitize_filename(tmp_file)
    local executable = photils_installed

    if dt.configuration.running_os == "macos" then
        executable =  executable .. "/Contents/MacOS/photils-cli"
    end

    if with_export then
        dt.print_log("use export to for prediction")
        local export_file = df.create_tmp_file()
        exporter:write_image(image, export_file)
        in_arg = df.sanitize_filename(tostring(export_file))
    end

    local command = executable .. " -c " .. " -i " .. in_arg .. " -o " .. out_arg

    local ret = dtsys.external_command(command)
    if ret > 0 then
        dt.print_error(string.format("command %s returned error code %d", command, ret))
        os.remove(tmp_file)

        -- try to export the image and run tagging
        if not with_export then
            return PHOTILS.get_tags(image, true)
        end

        return false
    end

    for i = #PHOTILS.tags, 1, -1 do
        PHOTILS.tags[i] = nil
        PHOTILS.confidences[i] = nil
    end

    for tag in io.lines(tmp_file) do
        local splitted = du.split(tag, ":")
        if 100 * tonumber(splitted[2]) >= GUI.confidence_slider.value then
            PHOTILS.tags[#PHOTILS.tags + 1] = splitted[1]
            PHOTILS.confidences[#PHOTILS.confidences+1] = splitted[2]
        end
    end

    dt.print(string.format(_("%s found %d tags for your image"), MODULE_NAME,
                           #PHOTILS.tags))
    os.remove(tmp_file)

    return true
end

function PHOTILS.on_tags_clicked()
    PHOTILS.page = 1
    GUI.warning.label = ""

    PHOTILS.on_reset(false)

    local images = dt.gui.selection()

    if #images == 0 then
        dt.print(_("no image selected."))
        dt.control.sleep(2000)
    else
        if #images > 1 then
            dt.print(_("this plugin can only handle a single image."))
            dt.gui.selection({images[1]})
            dt.control.sleep(2000)
        end

        with_export = dt.preferences.read(MODULE_NAME, "export_image_before_for_tags", "bool")
        if not PHOTILS.get_tags(images[1], with_export) then
            local msg = string.format(_("%s failed, see terminal output for details"), MODULE_NAME)
            GUI.warning_label.label = msg
            GUI.stack.active = GUI.error_view
            dt.print(msg)
            return
        end

        if #PHOTILS.tags == 0 then
            local msg = string.format(_("no tags were found"), MODULE_NAME)
            GUI.warning_label.label = msg
            GUI.stack.active = GUI.error_view
            return
        end

        GUI.stack.active = GUI.tag_view
        PHOTILS.paginate()
    end
end

function PHOTILS.tag_selected(tag_button)
    if PHOTILS.in_pagination then return end

    if tag_button.value then
        local tag = tag_button.label
        if dt.preferences.read(MODULE_NAME, "show_confidence", "bool") then
            local idx = string.find(tag, "%(") - 2
            tag = string.sub(tag, 0, idx)
        end

        PHOTILS.selected_tags[tag] = tag
    else
        PHOTILS.selected_tags[tag_button.label] = nil
    end

    local num_selected = num_keys(PHOTILS.selected_tags)
    if num_selected == 0 then
        GUI.attach_button.label = ""
        GUI.attach_button.sensitive = false
    else
        GUI.attach_button.label = string.format(_("attach %d tags"),
                                                num_selected)
        GUI.attach_button.sensitive = true
    end
end

function PHOTILS.on_reset(with_view)
    if with_view then GUI.stack.active = 1 end

    for k, _ in pairs(PHOTILS.selected_tags) do
        PHOTILS.selected_tags[k] = nil
    end

    for _, v in ipairs(GUI.tag_box) do
        v.value = false
    end

    GUI.attach_button.label = ""
    GUI.attach_button.sensitive = false
end

local function install_module()
  if not PHOTILS.module_installed then
    dt.register_lib(MODULE_NAME,
        _("photils auto-tagger"),
        true,
        true,
        PHOTILS.plugin_display_views,
        GUI.container,
        nil,
        nil
    )
    PHOTILS.module_installed = true
  end
end

local function destroy()
    dt.gui.libs[MODULE_NAME].visible = false
    dt.destroy_event("photils", "mouse-over-image-changed")
end

local function restart()
    dt.gui.libs[MODULE_NAME].visible = true
    dt.register_event("photils", "mouse-over-image-changed",
        PHOTILS.image_changed)
end

local function show()
    dt.gui.libs[MODULE_NAME].visible = true
end


-- add a fix number of buttons
for _ = 1, PHOTILS.per_page, 1 do
    local btn_tag = dt.new_widget("check_button") {
        label = "",
        sensitive = false,
        clicked_callback = PHOTILS.tag_selected
    }

    table.insert(GUI.tag_box, btn_tag)
end

if not photils_installed then
    GUI.warning_label.label = _("photils-cli not found")
    dt.print_log("photils-cli not found")
else
    GUI.warning_label.label = _("select an image, click \"get tags\" and get \nsuggestions for tags.")
end

GUI.pagination = dt.new_widget("box") {
    orientation = "horizontal",
    GUI.prev_button,
    GUI.page_label,
    GUI.next_button
}


table.insert(GUI.error_view, GUI.warning_label)
if not photils_installed then
    table.insert(GUI.error_view, df.executable_path_widget({"photils-cli"}))
    table.insert(GUI.error_view, GUI.restart_required_label)
end
table.insert(GUI.stack, GUI.error_view)
table.insert(GUI.stack, GUI.tag_view)

table.insert(GUI.tag_view, GUI.pagination)
table.insert(GUI.tag_view, GUI.tag_box)
table.insert(GUI.tag_view, GUI.attach_button)
table.insert(GUI.tag_view, GUI.warning)

table.insert(GUI.container, GUI.confidence_slider)
table.insert(GUI.container, GUI.stack)

GUI.stack.active = 1



-- uses photils: prefix because script settings are all together and not seperated by script
dt.preferences.register(MODULE_NAME,
                        "show_confidence",
                        "bool",
                        _("photils: show confidence value"),
                        _("if enabled, the confidence value for each tag is displayed"),
                        true)

dt.preferences.register(MODULE_NAME,
                        "export_image_before_for_tags",
                        "bool",
                        _("photils: use exported image for tag request"),
                        _("if enabled, the image passed to photils for tag suggestion is based on the exported, already edited image. " ..
                          "otherwise, the embedded thumbnail of the RAW file will be used for tag suggestion." ..
                          "the embedded thumbnail could speedup the tag suggestion but can fail if the RAW file is not supported."),
                        true)

dt.register_event("photils", "mouse-over-image-changed",
    PHOTILS.image_changed)

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not PHOTILS.event_registered then
    dt.register_event(
      "photils", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    PHOTILS.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = show

return script_data
