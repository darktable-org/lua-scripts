require "lib/dtutils"
local dt = require "darktable"

libenfuse = {}

-- assemble a list of the files to send to enfuse.  If desired, align the files first
function libenfuse.build_response_file(image_table, will_align)

  -- create a temp response file
  local response_file = os.tmpname()
  local f = io.open(response_file, "w")
  if not f then
     os.remove(response_file)
    return nil
  end

  local cnt = 0

  -- do the alignment first, if requested
  if will_align then
    local align_img_list = ""
    for img, exp_img in pairs(image_table) do
      cnt = cnt + 1
      align_img_list = align_img_list .. " " .. dtutils.sanitize_filename(exp_img)
    end
    -- need at least 2 images to align
    if cnt > 1 then
      local align_command = "align_image_stack -m -a /tmp/OUT " .. align_img_list
      dt.print(_("Aligning images..."))
      if dt.control.execute(align_command) then
        dt.print(_("Image alignment failed"))
        os.remove(response_file)
        return nil
      else
        -- alignment succeeded, so we'll use the /tmp/OUTxxxx.tif files
        for _,exp_img in pairs(image_table) do
          os.remove(exp_img)
        end
        -- get a list of the /tmp/OUTxxxx.tif files and put it in the response file
        a = io.popen("ls /tmp/OUT*")
        if a then
          local aligned_file = a:read()
          while aligned_file do
            f:write(aligned_file .. "\n")
            aligned_file = a:read()
          end
          a:close()
          f:close()
        else
          dt.print(_("No aligned images found"))
          os.remove(response_file)
          return nil
        end
      end
    else
      libenfuse.cleanup(response_file)
      dt.print(_("not enough suitable images selected, nothing to do for enfuse"))
      return nil
    end
  else
    -- add all filenames to the response file
    for img, exp_img in pairs(image_table) do
      cnt = cnt + 1
      f:write(exp_img .. "\n")
    end
    f:close()
  end

  -- export will happily export 0 images if none are selected and the export button is pressed
  -- and it doesn't make any sense to try and do an hdr or focus stack on only 1 image

  if cnt < 2 then
    libenfuse.cleanup(response_file)
    dt.print(_("not enough suitable images selected, nothing to do for enfuse"))
    return nil
  else
    return response_file
  end
end

-- clean up after we've run or crashed
function libenfuse.cleanup(res_file)
  -- remove exported images
  local f = io.open(res_file)
  fname = f:read()
  while fname do
    os.remove(fname)
    fname = f:read()
  end
  f:close()
  
  -- remove the response file
  os.remove(res_file)
end
