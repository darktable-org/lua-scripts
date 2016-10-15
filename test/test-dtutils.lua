--[[

    test-dtutils.lua - the start of a testing framework idea....

    copyright (c) 2016 Bill Ferguson

    TODO: Think this out a little better
]]

local dt = require "darktable"
local du = require "lib/dtutils"

print(dtutils)
print(du)

dt.print_error("Testing lib/dtutils")


-- groupIfNotMember
  -- need the darktable database to test this....  It might be possible
  dt.print_error("can't test groupIfNotMember. Yet")

-- show_status
  -- need the exporter running to test this
  dt.print_error("can't test show_status. Yet")

  -- make some data

  local action_images = {}

  for i 1,9 do 
    local i = {}
    i.filename = string.format("img_000%d.cdr", i)
    i.path = "/home/user/pictures"
    du.push(action_images, i)
  end

  local image_table = libPlugin.build_image_table(action_images, "JPEG")
  local img_list = ""

  for i=1,9 do
    img_list = img_list .. dt.configuration.tmp_dir .. string.format("/img_000%d.jpg")
  end
  
  -- extract_image_list

  if img_list == du.extract_image_list(image_table) then
    dt.print_error("extract_image_list: OK")
  else
    dt.print_error("extract_image_list: Failed")
  end

  -- extract_collection_path

  if "/home/user/pictures" == du.extract_collection_path(image_table) then
    dt.print_error("extract_collection_path: OK")
  else
    dt.print_error("extract_collection_path: Failed")
  end

  -- split

  sjstring = "a string to split into pieces"

  parts = split(sjstring, " ")

  if #parts == 6 and parts[1] == "a" and parts[6] == "pieces" then
    dt.print_error("split: OK")
  else
    dt.print_error("split: Failed")
  end

  -- join

  if sjstring == du.join(parts, " ") then
    dt.print_error("join: OK")
  else
    dt.print_error("join: Failed")
  end

  -- makeOutputFileName

  if "img_0001.jpg" == du.makeOutputFileName("img_0001.jpg") and
     "img_0001-img_0002.jpg" == du.makeOutputFileName("img_0001.jpg img_0002.jpg") and
     "img_0001-img_0002-img_0003.jpg" == du.makeOutputFileName("img_0001.jpg img_0002.jpg img_0003.jpg") and
     "img_0001-img_0005.jpg" == du.makeOutputFileName("img_0001.jpg img_0002.jpg img_0003.jpg img_0004.jpg img_0005.jpg") then
     dt.print_error("makeOutputFileName: OK")
   else
    dt.print_error("makeOutputFileName: Failed")
  end

  -- prequire

  -- push

  -- pop

  -- updateComboboxChoices
