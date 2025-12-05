--[[Export module to create a web gallery from selected images

  copyright (c) 2025 Tino Mettler

  darktable is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  darktable is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this software.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
   TODO:
   - Lua: remove images dir if already existent
   - Lua: translations
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"

local temp = dt.preferences.read('web_gallery', 'title', 'string')
if temp == nil then temp = 'Darktable gallery' end

local title_widget = dt.new_widget("entry")
{
   text = temp
}

local temp = dt.preferences.read('web_gallery', 'destination_dir', 'string')
if temp == nil then temp = '' end

local dest_dir_widget = dt.new_widget("file_chooser_button")
{
   title = "select output folder",
   tooltip = "select output folder",
   value = temp,
   is_directory = true,
   changed_callback = function(this) dt.preferences.write('web_gallery', 'destination_dir', 'string', this.value) end
}

local gallery_widget = dt.new_widget("box")
{
    orientation=vertical,
    dt.new_widget("label"){label = "gallery title"},
    title_widget,
    dt.new_widget("label"){label = "destination directory"},
    dest_dir_widget
}

local function get_file_name(file)
    return file:match("[^/]*.$")
end

function escape_js_string(str)
  local replacements = {
    ['\\'] = '\\\\',
    ['"']  = '\\"',
    ["'"]  = "\\'",
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\v'] = '\\v'
  }
  return (str:gsub('[\\\"\n\r\t\b\f\v\']', replacements))
end

local function export_thumbnail(image, filename)
    dt.print("export thumbnail image "..filename)
    exporter = dt.new_format("jpeg")
    exporter.quality = 90
    exporter.max_height = 512
    exporter.max_width = 512
    exporter:write_image(image, filename, true)
end

local function write_image(image, dest_dir, filename)
    df.file_move(filename, dest_dir.."/"..get_file_name(filename))
    export_thumbnail(image, dest_dir.."/thumb_"..get_file_name(filename))
end

function exiftool_get_image_dimensions(filename)
    local handle = io.popen("exiftool " .. filename)
    local result = handle:read("*a")
    handle:close()
    for line in result:gmatch("[^\r\n]+") do
        local w = line:match("^Image Width%s*:%s*(%d+)")
        if w then
            width = tonumber(w)
        end
        local h = line:match("^Image Height%s*:%s*(%d+)")
        if h then
            height = tonumber(h)
        end
    end
    if width and height then
        return width, height
    else
        return nil, nil
    end
end

local function fill_gallery_table(images_ordered, images_table, title, dest_dir, sizes, exiftool)
    dest_dir = dest_dir.."/images"
    local gallery_data = { name = escape_js_string(title) }

    local images = {}
    local index = 1
    for i, image in pairs(images_ordered) do
        local filename = images_table[image]
        write_image(image, dest_dir, filename)

        if exiftool then
            width, height = exiftool_get_image_dimensions(dest_dir.."/"..get_file_name(filename))
        else
            width = sizes[index].width
            height = sizes[index].height
        end

        local entry = { filename = "images/"..get_file_name(escape_js_string(filename)),
                        width = width, height = height }

        images[index] = entry
        index = index + 1
    end

    gallery_data.images = images
    return gallery_data
end

local function generate_javascript_gallery_object(gallery)
    local js = 'const gallery_data = {\n'
    js = js .. '  name: "' .. gallery.name .. '",\n'
    js = js .. '  images: [\n'

    for i, img in ipairs(gallery.images) do
        js = js .. string.format('    { filename: "%s",\n      height: %d,\n      width: %d }', img.filename, img.height, img.width)
        if i < #gallery.images then
            js = js .. ',\n'
        else
            js = js .. '\n'
        end
    end

    js = js .. '  ]\n};\n'

    return(js)
end

local function write_javascript_file(gallery_table, dest_dir)
    dt.print("write JavaScript file")
    javascript_object = generate_javascript_gallery_object(gallery_table)

    local fileOut, errr = io.open(dest_dir.."/images.js", 'w+')
    if fileOut then
        fileOut:write(javascript_object)
    else
        log.msg(log.error, errr)
    end
    fileOut:close()
end

local function copy_static_files(dest_dir)
    dt.print("copy static gallery files")
    gfsrc = dt.configuration.config_dir.."/lua/data/website_gallery"
    gfiles = {
        "index.html",
        "gallery.css",
        "modal.css",
	"modal.js",
        "gallery.js",
        "fullscreen.js"
    }

    for _, file in ipairs(gfiles) do
        df.file_copy(gfsrc.."/"..file, dest_dir.."/"..file)
    end
end

local function build_gallery(storage, images_table, extra_data)
    local dest_dir = dest_dir_widget.value
    df.mkdir(dest_dir)
    df.mkdir(dest_dir.."/images")

    local images_ordered = extra_data["images"] -- process images in the correct order
    local sizes = extra_data["sizes"]
    local title = "Darktable export"
    if title_widget.text ~= "" then
        title = title_widget.text
    end
    local exiftool = df.check_if_bin_exists("exiftool");
    gallerydata = fill_gallery_table(images_ordered, images_table, title, dest_dir, sizes, exiftool)
    write_javascript_file(gallerydata, dest_dir)
    copy_static_files(dest_dir)
end

local script_data = {}

script_data.metadata = {
    name = "website gallery (new)",
    purpose = "create a web gallery from exported images",
    author = "Tino Mettler <tino+darktable@tikei.de>",
    help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/TODO"
}

script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function destroy()
    dt.preferences.write('web_gallery', 'title', 'string', title_widget.text)
    dt.destroy_storage("module_webgallery")
end
script_data.destroy = destroy

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format("export image %i/%i", number, total))
    aspect = image.aspect_ratio
    -- calculate the size of the exported image and store it in extra_data
    -- to make it available in the finalize function
    if image.final_height == 0 then
        if aspect < 1 then
            dimensions = { width = image.height, height = image.width }
        else
            dimensions = { width = image.width, height = image.height }
        end
    else
        dimensions = { width = image.final_width, height = image.final_height }
    end
    if format.max_height > 0 and dimensions.height > format.max_height then
        scale = format.max_height / dimensions.height
        dimensions.height = math.floor(dimensions.height * scale + 0.5)
        dimensions.width = math.floor(dimensions.width * scale + 0.5)
    end
    if format.max_width > 0 and dimensions.width > format.max_width then
        scale = format.max_width / dimensions.width
        dimensions.height = math.floor(dimensions.height * scale + 0.5)
        dimensions.width = math.floor(dimensions.width * scale + 0.5)
    end
    extra_data["sizes"][number] = dimensions
end

local function initialize(storage, img_format, images, high_quality, extra_data)
    dt.preferences.write('web_gallery', 'title', 'string', title_widget.text)
    extra_data["images"] = images -- needed, to preserve images order
    extra_data["sizes"] = {};
end

local supported_formats = { "jpg", "tif", "png", "webp" }

local formats_lut = {}
for key,format in pairs(supported_formats) do
   formats_lut[format] = true
end

function check_supported(storage, format)
   extension = format.extension
   if formats_lut[extension] == true then
      return true
   else
      return false
   end
end

dt.register_storage("module_webgallery", "website gallery (new)", show_status, build_gallery, check_supported, initialize, gallery_widget)

return script_data
