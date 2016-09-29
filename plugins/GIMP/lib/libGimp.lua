local dt = require "darktable"
require "lib/dtutils"
require "lib/libPlugin"

local gettext = dt.gettext
-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("gimp",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("gimp", msgid)
end

libGimp = {}

function libGimp.gimp_edit(image_table, plugin_data) --finalize

  local collection_path = dtutils.extract_collection_path(image_table)

  local data_dir = collection_path .. "/" .. plugin_data.DtPluginDataDir

  libPlugin.create_data_dir(data_dir)

  -- list of exported images 
  local img_list = dtutils.extract_image_list(image_table)

  dt.print(_("Launching GIMP..."))

  local gimpStartCommand
  gimpStartCommand = "gimp "..img_list
  
  dt.print_error(gimpStartCommand)

  dt.control.execute( gimpStartCommand)

  -- for each of the image, exported image pairs
  --   move the exported image into the directory with the original  
  --   then import the image into the database which will group it with the original
  --   and then copy over any tags other than darktable tags

  for image,exported_image in pairs(image_table) do

    local myimage_name = image.path .. "/" .. dtutils.get_filename(exported_image)

    while dtutils.checkIfFileExists(myimage_name) do
      myimage_name = dtutils.filename_increment(myimage_name)
      -- limit to 99 more exports of the original export
      if string.match(dtutils.get_basename(myimage_name), "_(d-)$") == "99" then 
        break 
      end
    end

    dt.print_error("moving " .. exported_image .. " to " .. myimage_name)
    result = dtutils.fileMove(exported_image, myimage_name)

    -- save the xcf file if it was created

    local xcf_file = dtutils.chop_filetype(exported_image) .. ".xcf"
    if dtutils.checkIfFileExists(xcf_file) then
      dtutils.fileMove(xcf_file, data_dir .. "/" .. dtutils.get_filename(xcf_file))
    end

    dt.print_error("importing file")
    local myimage = dt.database.import(myimage_name)

    dtutils.groupIfNotMember(image, myimage)

    for _,tag in pairs(dt.tags.get_tags(image)) do 
      if not (string.sub(tag.name,1,9) == "darktable") then
        dt.print_error("attaching tag")
        dt.tags.attach(tag,myimage)
      end
    end
  end
end

return libGimp