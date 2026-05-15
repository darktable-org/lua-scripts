--[[
    This file is part of darktable,
    copyright (c) 2026 darktable developers.

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
    ai_denoise - example script demonstrating the darktable.ai Lua
    API by denoising the selected images with tile-based inference.

    Adds an "AI denoise" panel to the lighttable right column with a
    "denoise selected" button. Each selected image is loaded through
    the develop pipeline (so denoise sees the output of all enabled
    IOPs, not the original raw), run tile-by-tile through the active
    denoise model, and saved as a 16-bit TIFF grouped with the source.

    Demonstrates:
      * model lookup via dt.ai.model_for_task
      * tensor crop/paste for tile-based inference
      * linear <-> sRGB conversion (NR models train on gamma input)
      * edge-replicated padding to suppress border artifacts
      * background job with progress bar and cancellation

    LIMITATIONS
      * Image must be at least TILE_SIZE x TILE_SIZE (768 x 768 for
        denoise-nind / denoise-nafnet); smaller inputs return an error.
      * If a save fails mid-batch the Lua error propagates and aborts
        the whole job. Wrap denoise_one in pcall if you need
        batch-robust behaviour.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
      * a denoise model enabled in preferences -> AI (denoise-nind,
        denoise-nafnet, ...)

    USAGE
      * require this script from your luarc
      * select one or more images in lighttable
      * click the "denoise selected" button in the AI denoise panel

    BUGS, COMMENTS, SUGGESTIONS
      * file an issue on https://github.com/darktable-org/darktable

    CHANGES
]]

local dt = require "darktable"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "ai_denoise"

-- darktable's NR models use static-shape ONNX: each model has a fixed
-- input dimension baked in at training time. The Lua API doesn't
-- expose this, so keep TILE_SIZE in sync with the model's
-- `attributes.input_sizes` in its config.json.
local TILE_SIZE = 768   -- denoise-nind, denoise-nafnet

-- overlap between adjacent tiles. larger values produce smoother
-- seams at the cost of more compute per pixel
local OVERLAP = 64

-- - - - - - - - - - - - - - - - - - - - - - - -
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -

-- Surround the input with `pad` pixels on every side, replicating the
-- outermost rows/columns ("edge clamp" padding). Boundary tiles then
-- see plausible context instead of a literal image edge, so the
-- network's internal zero-padding no longer leaks into the visible
-- output as colour artifacts along the image rim.
local function pad_replicate(input, pad)
  local C = input:shape()[2]
  local H = input:shape()[3]
  local W = input:shape()[4]
  local padded = dt.ai.create_tensor({1, C, H + 2 * pad, W + 2 * pad})

  -- center: original image
  padded:paste(input, pad, pad)

  -- left and right strips: replicate first / last column of input
  local left_col  = input:crop(0, 0,     H, 1)
  local right_col = input:crop(0, W - 1, H, 1)
  for i = 0, pad - 1 do
    padded:paste(left_col,  pad, i)
    padded:paste(right_col, pad, pad + W + i)
  end

  -- top and bottom strips: replicate first / last row of the already
  -- horizontally-padded buffer so the four corners get filled correctly
  local top_row    = padded:crop(pad,         0, 1, W + 2 * pad)
  local bottom_row = padded:crop(pad + H - 1, 0, 1, W + 2 * pad)
  for i = 0, pad - 1 do
    padded:paste(top_row,    i,           0)
    padded:paste(bottom_row, pad + H + i, 0)
  end

  return padded
end

-- Tile a [1,C,H,W] tensor through the model with overlap-blended seams.
-- Each tile is tile_size x tile_size, successive tiles step by
-- (tile_size - 2*overlap), and only the central (non-overlap) region
-- of each tile is pasted into the output. Image-boundary edges keep
-- their full extent; only image-interior seams drop the overlap margin.
--
-- The trailing tile in each axis is pinned to the image boundary so
-- the residual right/bottom strip is never smaller than 2*overlap --
-- otherwise it would have to be skipped (the model has a fixed input
-- size) and those pixels would never be written.
local function run_tiled(ctx, input, tile_size, overlap,
                         job, base_pct, span_pct)
  local C = input:shape()[2]
  local H = input:shape()[3]
  local W = input:shape()[4]
  if H < tile_size or W < tile_size then
    return nil, string.format("image too small (%dx%d) for tile %d",
                              W, H, tile_size)
  end

  local step = tile_size - 2 * overlap

  -- enumerate tile origins along one axis, ending exactly at the boundary
  local function origins(extent)
    local out, p = {}, 0
    while p + tile_size < extent do
      out[#out + 1] = p
      p = p + step
    end
    out[#out + 1] = math.max(0, extent - tile_size)
    return out
  end
  local ys, xs = origins(H), origins(W)
  local total = #xs * #ys

  local output = dt.ai.create_tensor({1, C, H, W})
  local done = 0

  for _, ty in ipairs(ys) do
    for _, tx in ipairs(xs) do
      if job and not job.valid then return nil, "cancelled" end

      local tile_in = input:crop(ty, tx, tile_size, tile_size)
      local tile_out = ctx:run(tile_in)

      -- central region to keep: drop overlap on every inner edge;
      -- full extent at image-boundary edges
      local at_top    = (ty == 0)
      local at_left   = (tx == 0)
      local at_bottom = (ty + tile_size >= H)
      local at_right  = (tx + tile_size >= W)

      local cy = at_top   and 0 or overlap
      local cx = at_left  and 0 or overlap
      local ch = tile_size - cy - (at_bottom and 0 or overlap)
      local cw = tile_size - cx - (at_right  and 0 or overlap)

      output:paste(tile_out:crop(cy, cx, ch, cw), ty + cy, tx + cx)

      done = done + 1
      if job then
        job.percent = base_pct + span_pct * (done / total)
      end
    end
  end

  return output
end

-- Denoise one image: load through the develop pipeline, run tiled
-- inference, save as 16-bit TIFF, group with the source.
local function denoise_one(ctx, img, tile_size, job, base_pct, span_pct)
  -- darktable returns the develop-pipeline output as scene-linear RGB;
  -- the NR models were trained on sRGB-gamma input, so we re-encode
  -- before inference and decode back to linear before saving
  local input = dt.ai.load_image(img)
  if not input then return false, "load_image failed" end
  input:linear_to_srgb()

  -- pad so the image's outer rim is no longer at a tile boundary;
  -- the padded strip absorbs the network's edge artifacts and gets
  -- cropped away after inference
  local H = input:shape()[3]
  local W = input:shape()[4]
  local padded_in = pad_replicate(input, OVERLAP)

  local padded_out, err = run_tiled(ctx, padded_in, tile_size, OVERLAP,
                                    job, base_pct, span_pct)
  if not padded_out then return false, err end

  local output = padded_out:crop(OVERLAP, OVERLAP, H, W)
  output:srgb_to_linear()

  local base = img.filename:match("(.+)%..+$") or img.filename
  local out_path = img.path .. "/" .. base .. "_denoised.tif"
  output:save_tiff(out_path, 16, img)

  -- import the result and group with the source so they live together
  -- in the lighttable
  local imported = dt.database.import(out_path)
  if imported then imported:group_with(img) end
  return true
end

-- Button handler: looks up the active denoise model, fans out the
-- selected images, and reports progress via a cancellable job.
local function process_denoise()
  local model_id = dt.ai.model_for_task("denoise")
  if not model_id then
    dt.print("no denoise model enabled -- pick one in preferences -> AI")
    return
  end

  local images = dt.gui.selection()
  if #images == 0 then
    dt.print("select at least one image")
    return
  end

  -- progress + cancel job. the cancel callback flips job.valid; the
  -- main loop polls it between tiles to stop cleanly
  local job = dt.gui.create_job(
    string.format("AI denoise (%d image%s)",
                  #images, #images == 1 and "" or "s"),
    true,
    function(j) j.valid = false end)

  dt.print_log(string.format(
    "[ai_denoise] starting: %d image%s with model %s",
    #images, #images == 1 and "" or "s", model_id))
  local t_start = os.time()

  local ctx = dt.ai.load_model(model_id)
  if not ctx then
    dt.print("failed to load model: " .. model_id)
    job.valid = false
    return
  end

  local span = 1.0 / #images
  local done = 0
  for i, img in ipairs(images) do
    if not job.valid then break end
    dt.print_log(string.format("[ai_denoise] [%d/%d] %s",
                               i, #images, img.filename))
    local ok, err = denoise_one(ctx, img, TILE_SIZE, job,
                                (i - 1) * span, span)
    if not ok then
      dt.print(string.format("[%d/%d] %s: %s",
                             i, #images, img.filename, tostring(err)))
      dt.print_log(string.format("[ai_denoise] [%d/%d] %s FAILED: %s",
                                 i, #images, img.filename, tostring(err)))
    else
      done = done + 1
    end
  end

  ctx:close()
  job.valid = false
  local elapsed = os.time() - t_start
  dt.print(string.format("denoise complete: %d image%s",
                         #images, #images == 1 and "" or "s"))
  dt.print_log(string.format(
    "[ai_denoise] finished: %d/%d in %ds",
    done, #images, elapsed))
end

-- script_manager integration: called when the user disables the script.
-- darktable can't remove a registered lib from the UI at runtime, so we
-- only stop any in-flight work; the panel itself remains until restart.
local function destroy()
  -- nothing persistent to clean up: each click runs its own job and
  -- closes its own model context
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- M A I N
-- - - - - - - - - - - - - - - - - - - - - - - -

dt.register_lib(
  MODULE_NAME,                                        -- plugin id
  "AI denoise",                                       -- displayed name
  true,                                               -- expandable
  false,                                              -- no reset button
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},
  dt.new_widget("box") {
    orientation = "vertical",
    dt.new_widget("button") {
      label = "denoise selected",
      clicked_callback = process_denoise,
    }
  },
  nil, nil
)

-- - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T   M A N A G E R   I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - -

local script_data = {}

script_data.metadata = {
  name = "ai_denoise",
  purpose = "tile-based AI denoise using the darktable.ai Lua API",
  author = "Andrii Ryzhkov <andrii.ryzhkov@pm.me>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/ai_denoise"
}

script_data.destroy = destroy

return script_data
