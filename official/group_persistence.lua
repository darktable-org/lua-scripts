--[[

    group_persistence.lua - preserve groups between darktable instances

    Copyright (C) 2024-2026 Bill Ferguson <wpferguson@gmail.com>.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
    group_persistence - preserve groups between darktable instances

    group_persistence uses "functional" tagging to maintain image groups
    across database instances, allowing image grouping to be restored when
    the database is rebuilt from the XMP sidecar files.

    Once the script is started it "listens" for changes in image grouping and
    applies or removes the necessary tags automatically.

    A shortcut can be assigned to read a collection and apply the necessary 
    grouping tags so that existing collections can be maintained.

    If the database is lost and needs to be rebuilt then start the script before
    importing any images.  As images are imported the tags will be read and the
    grouping applied in the database.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    
    None

    USAGE
    
    * Enable the script using script manager
    * Optionally, create a keystroke combination for the shortcut

    LIMITATIONS

    In normal use you wont notice that the script is running.

    However if you do something like import 4000+ images, then
    run the autogrouper script to create groups whenever there is
    a 5 second difference between 2 images, your system will be busy
    for awhile.  If for some reason you need to do something like this
    turn off group_persistence, run the autogrouper, turn on group_persistence
    and use the shortcut to read all the grouping information and apply
    the necessary tags.  It will still be an impact, but less than trying
    to do both at once.  Learned from experience :-)

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gmail.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
-- local df = require "lib/dtutils.file"
-- local ds = require "lib/dtutils.string"
-- local dtsys = require "lib/dtutils.system"
local log = require "lib/dtutils.log"
-- local debug = require "darktable.debug"


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "group_persistence"
local DEFAULT_LOG_LEVEL <const> = log.error
local TMP_DIR <const> = dt.configuration.tmp_dir

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("9.4.0", MODULE)   -- choose the minimum version that contains the features you need


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- I 1 8 N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local gettext = dt.gettext.gettext

dt.gettext.bindtextdomain(MODULE , dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
    return gettext(msgid)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T  M A N A G E R  I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local script_data = {}

script_data.destroy = nil           -- function to destory the script
script_data.destroy_method = nil    -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil           -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil              -- only required for libs since the destroy_method only hides them

script_data.metadata = {
  name = _("group persistence"),            -- name of script
  purpose = _("preserve groups between darktable instances"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",          -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/group_persistence"  -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local group_persistence = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = group_persistence

local gp = group_persistence

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- table of imported images that need grouping rebuilt
gp.imported_images = {}

-- uuid to group leader mapping
gp.uuids = {}

-- group leader to uuid mapping
gp.leaders = {}

-- uuid to group tag mapping
gp.group_tags = {}

-- uuid to group leader tag mapping
gp.leader_tags = {}

-- when the groups are rebuilt after import they
-- cause the group change events to fire but the
-- events are queued until after rebuilding completes
-- so we need to build a table of images to ignore when
-- the queued events catch up.  As the event fires for an
-- image, the image is removed.
gp.rebuilt_images = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- utilities for building/debugging

local function dump_image_tags(image)
  log.msg(log.debug, "")

  for _, tag in ipairs(image:get_tags()) do
    log.msg(log.debug, "tag for image " .. image.id .. " is " .. tag.name)
  end

  log.msg(log.debug, "group_leader is " .. image.group_leader.id .. " and group has " .. #image:get_group_members() .. " members")

  log.msg(log.debug, "")
end

local function dump_group_tags(image)
  local leader = image.group_leader

  for _, tag in ipairs(image:get_tags()) do
    if string.match(tag.name, "darktable|group") then
      log.msg(log.debug, "group leader image " .. image.id .. " has tag " .. tag.name)
    end
  end

  for _, img in ipairs(image:get_group_members()) do
    for _, tag in ipairs(img:get_tags()) do
      if string.match(tag.name, "darktable|group") then
        log.msg(log.debug, "group member image " .. img.id .. " has tag " .. tag.name)
      end
    end
  end
end

-- rebuild grouping on import

local function save_group_leader(image, uuid)

  log.log_level(DEFAULT_LOG_LEVEL)

  log.msg(log.debug, "input image is " .. image.id .. " and uuid is " .. uuid)
  
  gp.uuids[image] = uuid
  gp.leaders[uuid] = image

  log.msg(log.debug, "after saving group leader uuid is " .. gp.leaders[uuid].id .. " and image is " .. gp.uuids[image])
end

local function get_group_and_uuid(tags)

  log.log_level(DEFAULT_LOG_LEVEL)

  local group_type = nil
  local uuid = nil

  for _, tag in ipairs(tags) do

    if string.match(tag.name, "darktable|group") then

      log.msg(log.debug, "found tag darktable|group")

      local parts = du.split(tag.name, "|")

      group_type = parts[2]
      uuid = parts[3]

      log.msg(log.info, "found type " .. group_type .. " with uuid " .. uuid)
    end
  end

  return group_type, uuid
end

local function get_uuid_from_tag(tag)
  local parts = du.split(tag.name, "|")
  return parts[#parts]
end

local function find_group_leader(uuid)

  local group_leader = nil

  local tag_name = "darktable|group_leader|" .. uuid

  local found_tag = dt.tags.find(tag_name)

  if found_tag then

    group_leader = dt.tags.get_tagged_images(found_tag)[1]

  end

  return group_leader
end

local function rebuild_groups()

  log.log_level(DEFAULT_LOG_LEVEL)

  for _, image in ipairs(gp.imported_images) do

    log.msg(log.info, "processing image " .. image.id)

    local tags = image:get_tags()

    local group_type, uuid = get_group_and_uuid(tags)

    if group_type =="group_leader" then

      table.insert(gp.rebuilt_images, image)

      log.msg(log.debug, "took group_leader branch")

      save_group_leader(image, uuid)

    elseif group_type == "group" then

      table.insert(gp.rebuilt_images, image)

      log.msg(log.debug, "took group branch")

      local leader = gp.uuids[uuid]

      if leader then

        image:group_with(leader)

      else

        local group_leader = find_group_leader(uuid)

        if group_leader then

          save_group_leader(group_leader, uuid)
          image:group_with(group_leader)

        end
      end
    end
  end
  gp.imported_images = {}
end

-- rebuild grouping on command (shortcut)

local function is_group_leader(image)
  result = false

  if image.group_leader == image and #image:get_group_members() > 1 then
    result = true
  end

  return result
end

local function has_group_tag(image)
  local result = false

  for _, tag in ipairs(image:get_tags()) do
    if string.match(tag.name, "darktable|group|") then
      result = tag
    end
  end

  return result
end

local function has_group_leader_tag(image)
  local result = false

  for _, tag in ipairs(image:get_tags()) do
    if string.match(tag.name, "darktable|group_leader") then
      result = tag
    end
  end

  return result
end

-- handle grouping changes in the UI

local function group_exists(group_leader)
  local exists = false

  local tags = group_leader:get_tags()

  for _, tag in ipairs(tags) do
    if string.match(tag.name, "group_leader") then
      exists = true
      break
    end
  end
  return exists
end

local function add_group_leader(image, group)
  -- tag image as group leader
  -- create the uuid and leader/group tags if necessary

  log.log_level(DEFAULT_LOG_LEVEL)
  
  local uuid = du.gen_uuid()

  if uuid then
    log.msg(log.debug, "in add_group_leader and uuid is " .. uuid)
  else
    log.msg(log.debug, "uuid not created")
  end

  local tag = dt.tags.create("darktable|group_leader|" .. uuid)

  local group_tag = dt.tags.create("darktable|group|" .. uuid)

  log.msg(log.info, "created group leader tag " .. tag.name)
  log.msg(log.info, "created group tag " .. group_tag.name)

  gp.group_tags[uuid] = group_tag
  gp.leader_tags[uuid] = tag

  gp.uuids[uuid] = image
  gp.leaders[image] = uuid

  image:attach_tag(tag)
  log.msg(log.info, "attached tag " .. tag.name .. " to image " .. image.id)
end

local function add_to_group(image, group_leader)
  -- add an image to a group
  -- create the group if necessary

  log.log_level(DEFAULT_LOG_LEVEL)

  if image == group_leader then

    add_group_leader(image, group_leader)

  else

    if not group_exists(group_leader) then
      add_group_leader(group_leader, group_leader)
    end

    local group_tag = nil

    log.msg(log.debug, "image is " .. image.id .. " and group_leader is " .. image.group_leader.id)

    local group, uuid = get_group_and_uuid(image.group_leader:get_tags())

    group_tag =  gp.group_tags[uuid]

    if not group_tag then
      log.msg(log.info, "creating group tag darktable|group|" .. uuid)
      group_tag = dt.tags.create("darktable|group|" .. uuid)
      gp.group_tags[uuid] = group_tag
    end

    image:attach_tag(group_tag)
    log.msg(log.info, "group tag attached to image " .. image.id)
  end
end

local function build_group(leader)

  if not has_group_leader_tag(leader) then
    add_group_leader(leader)
  end

  for _, image in ipairs(leader:get_group_members()) do
    if not has_group_tag(image) then
      add_to_group(image, leader)
    end
  end
end

local function process(image_set)
  local images

  if image_set == "collection" then
    images = dt.collection
  else
    images = dt.gui.selection()
    if #images == 0 then
      images = dt.gui.action_images
    end
  end

  for _, image in ipairs(images) do
    if is_group_leader(image) then
      build_group(image)
    end
  end
end

local function check_and_remove_empty_group_data(group_tag)
  if not group_tag then
    return -- handle duplicate getting deleted
  end

  local group_leader_tag = nil

  group_leader_tag = dt.tags.find(string.gsub(group_tag.name, "|group|", "|group_leader|"))

  local group_leader_count = 0
  local group_count = #dt.tags.get_tagged_images(group_tag)

  if group_leader_tag then
    group_leader_count = #dt.tags.get_tagged_images(group_leader_tag)
  end

  if group_leader_count + group_count < 2 then  -- there's either 1 or 0, so no group
    local uuid = get_uuid_from_tag(group_tag)

    if gp.group_tags[uuid] then
      gp.group_tags[uuid] = nil
    end

    if gp.uuids[image] then
      gp.uuids[image] = nil
    end

    if gp.leaders[uuid] then
      gp.leaders[uuid] = nil
    end

    group_tag:delete()
    if group_leader_tag then
      group_leader_tag:delete()
    end
  end
end

local function remove_group_leader(image, new_group_leader)
  -- remove image group leader tag
  -- if it's the last image, then remove the leader/group tags

  log.log_level(DEFAULT_LOG_LEVEL)

  dump_image_tags(image)
  
  local group, uuid = get_group_and_uuid(image:get_tags())

  local leader_tag = dt.tags.find("darktable|group_leader|" .. uuid)
  local group_tag = dt.tags.find("darktable|group|" .. uuid)

  image:detach_tag(leader_tag)
  gp.leaders[image] = nil

  log.msg(log.info, "removed image " .. image.id .. " as group leader for uuid " .. uuid)

  new_group_leader:detach_tag(group_tag)
  new_group_leader:attach_tag(leader_tag)

  log.msg(log.info, "added image " .. new_group_leader.id .. " as group leader for uuid " .. uuid)

  gp.leaders[new_group_leader] = uuid
  gp.uuids[uuid] = new_group_leader

  check_and_remove_empty_group_data(group_tag)
end

local function remove_from_group(image, group_leader)
  -- remove an image from a group
  -- if it's the last image then remove the tags

  -- image.id > group_leder.id - simple remove
  -- image.id < group_leader.id - deleting old group_leader (image) with new group_leader (group_leader)

  log.log_level(DEFAULT_LOG_LEVEL)

  if image.id < group_leader.id then

    remove_group_leader(image, group_leader)

  else

    local group_tag = has_group_tag(image)

    if group_tag then

      image:detach_tag(group_tag)

      log.msg(log.info, "image " .. image.filename .. " with id " .. image.id .. " removed from group " .. group_tag.name)
    end

    check_and_remove_empty_group_data(group_tag)
  end
end


local function change_group_leader(image)
  -- remove the group leader tag from the old leader
  -- replace the old group leader tag with a group tag
  -- add the group leader tag to the new image

  log.log_level(DEFAULT_LOG_LEVEL)

  dump_image_tags(image)
  
  local group, uuid = get_group_and_uuid(image:get_tags())

  local leader_tag = dt.tags.find("darktable|group_leader|" .. uuid)
  local group_tag = dt.tags.find("darktable|group|" .. uuid)

  old_leader = dt.tags.get_tagged_images(leader_tag)[1]

  old_leader:detach_tag(leader_tag)
  log.msg(log.info, "remove leader tag from image " .. old_leader.id)
  old_leader:attach_tag(group_tag)
  log.msg(log.info, "attached group tag to image " .. old_leader.id)
  image:detach_tag(group_tag)
  log.msg(log.info, "removed group tag from new leader image " .. image.id)
  image:attach_tag(leader_tag)
  log.msg(log.info, "attached leader tag to new leader image " .. image.id)
  gp.leaders[uuid] = image
  gp.uuids[image] = uuid
end

-- event handling

local function add_group_event()
  dt.register_event(MODULE, "image-group-information-changed",
    function(event, reason, image, other_image)
      log.msg(log.debug, "")
      log.msg(log.debug, "caught event with reason " .. reason .. " and image " .. image.id .. " and other image " .. other_image.id)
      log.msg(log.debug, "")
      for pos, rimage in ipairs(gp.rebuilt_images) do
        if rimage == image then
          table.remove(gp.rebuilt_images, pos)
          return
        end
      end
      if reason == "add" then
        log.msg(log.debug, "in add, image is " .. image.id .. " and group is " .. other_image.id)
        if image == other_image then
          add_group_leader(image, other_image)
        else
          add_to_group(image, other_image)
        end
      elseif reason == "remove" then
        log.msg(log.debug, "in remove with image " .. image.id .. " and group_id " .. other_image.id)
        remove_from_group(image, other_image)
      elseif reason == "remove-leader" then
        remove_group_leader(image, other_image)
        log.msg(log.debug, "in remove-leader with image " .. image.id .. " and new group id " .. other_image.id)
      else
        if image ~= other_image then
          log.msg(log.debug, "in change-leader with image " .. image.id .. " and other_id " .. other_image.id)
          change_group_leader(image)
          log.msg(log.debug, "in change-leader with image " .. image.id .. " and other_id " .. other_image.id)
        else
          log.msg(log.debug, "in change-leader with image " .. image.id .. " and other_id " .. other_image.id)
          log.msg(log.debug, "calling add_group_leader")
          add_group_leader(image, other_image)
        end
      end
    end
  )
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.util.message(MODULE, "autogrouper", "running")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.destroy_event(MODULE, "post-import-image")
  dt.destroy_event(MODULE, "post-import-film")
  dt.destroy_event(MODULE, "image-group-information-changed")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "post-import-image", 
  function(event, image)
    table.insert(gp.imported_images, image)
  end
)

dt.register_event(MODULE, "post-import-film",
  function(event, filmroll)
    rebuild_groups()
  end
)

add_group_event()

dt.register_event(MODULE, "shortcut",
  function(event, string)
    dump_image_tags(dt.gui.action_images[1])
  end, "dump image tags"
)

dt.register_event(MODULE, "shortcut",
  function(event, string)
    dump_group_tags(dt.gui.action_images[1])
  end, "dump group_tags"
)

dt.register_event(MODULE, "shortcut",
  function(event, string)
    process("collection")
  end, "group collection"
)


return script_data
