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
    ai_raw_denoise - example script demonstrating the darktable.ai Lua
    API by denoising the selected raw images with tile-based inference
    on the raw CFA.

    Adds an "AI raw denoise" panel to the lighttable right column with
    a "denoise selected" button. Each selected image's raw CFA is
    loaded, Bayer-packed to 4 channels, run tile-by-tile through the
    currently enabled rawdenoise model (which denoises AND demosaicks
    in one pass), and saved as a LinearRaw DNG grouped with the
    source image.

    Demonstrates:
      * model lookup via dt.ai.model_for_task
      * loading model variant files via dt.ai.load_model file arg
      * raw CFA loading via dt.ai.load_raw
      * tensor bayer_pack for 4-channel CFA tiling
      * tile loop with non-trivial input->output scale (here 1 -> 2)
      * edge-replicated padding to suppress border artifacts
      * LinearRaw DNG output via dt.ai.save_dng_linear
      * background job with progress bar and cancellation

    LIMITATIONS
      * Bayer sensors only. The script loads model_bayer.onnx and uses
        bayer_pack, which assumes a 2x2 Bayer layout. X-Trans and
        Foveon sensors need model_linear.onnx with a different
        preprocessing pipeline (no bayer_pack, demosaicked input).
      * Image must be at least TILE_SIZE x TILE_SIZE in packed pixels
        (1024 x 1024 of CFA for the default 512 packed tile size).
      * If a save fails mid-batch the Lua error propagates and aborts
        the whole job. Wrap denoise_one in pcall if you need
        batch-robust behaviour.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
      * a rawdenoise model enabled in preferences -> AI
        (e.g. rawdenoise-nind)

    USAGE
      * require this script from your luarc
      * select one or more raw images in lighttable
      * click the "denoise selected" button in the AI raw denoise panel

    BUGS, COMMENTS, SUGGESTIONS
      * file an issue on https://github.com/darktable-org/darktable

    CHANGES
]]

local dt = require "darktable"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "ai_raw_denoise"

-- The rawdenoise-nind bayer model is a denoise+demosaic combo:
--   input  : [1, 4, 512,  512]  packed CFA (4 phase planes)
--   output : [1, 3, 1024, 1024] linear RGB at 2x the input resolution
-- So each tile-size pixel of the input covers a 2x2 CFA block, and the
-- model emits two output pixels per input pixel in each axis.
-- TILE_SIZE is in packed pixels (model input); SCALE turns those into
-- output pixels. Keep in sync with `attributes.input_sizes` in the
-- model's config.json.
local TILE_SIZE = 512        -- rawdenoise-nind
local SCALE     = 2          -- model output dim / input dim
local OUT_CH    = 3          -- model emits linear RGB

-- overlap between adjacent tiles, in packed pixels (input space).
-- larger values produce smoother seams at the cost of more compute
local OVERLAP = 32

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

-- Tile a [1,C_in,H,W] tensor through a model that emits [1,C_out,H*scale,
-- W*scale]. Each tile is tile_size x tile_size in input space; successive
-- tiles step by (tile_size - 2*overlap); only the central (non-overlap)
-- region of each tile's output is pasted into the result, with all
-- offsets multiplied by `scale`. Image-boundary edges keep their full
-- extent; only image-interior seams drop the overlap margin.
--
-- The trailing tile in each axis is pinned to the image boundary so
-- the residual right/bottom strip is never smaller than 2*overlap --
-- otherwise it would have to be skipped (the model has a fixed input
-- size) and those pixels would never be written.
local function run_tiled(ctx, input, tile_size, overlap, scale, c_out,
                         job, base_pct, span_pct)
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

  -- output is scale-times larger spatially and may have a different
  -- channel count than the input
  local output = dt.ai.create_tensor({1, c_out, H * scale, W * scale})
  local done = 0

  for _, ty in ipairs(ys) do
    for _, tx in ipairs(xs) do
      if job and not job.valid then return nil, "cancelled" end

      local tile_in = input:crop(ty, tx, tile_size, tile_size)
      local tile_out = ctx:run(tile_in)

      -- central region to keep: drop overlap on every inner edge;
      -- full extent at image-boundary edges. all dimensions in OUTPUT
      -- (post-scale) space, since that's where we paste
      local at_top    = (ty == 0)
      local at_left   = (tx == 0)
      local at_bottom = (ty + tile_size >= H)
      local at_right  = (tx + tile_size >= W)

      local ov  = overlap * scale
      local tos = tile_size * scale
      local cy = at_top   and 0 or ov
      local cx = at_left  and 0 or ov
      local ch = tos - cy - (at_bottom and 0 or ov)
      local cw = tos - cx - (at_right  and 0 or ov)

      output:paste(tile_out:crop(cy, cx, ch, cw),
                   ty * scale + cy, tx * scale + cx)

      done = done + 1
      if job then
        job.percent = base_pct + span_pct * (done / total)
      end
    end
  end

  return output
end

-- Denoise one raw image. The bayer rawdenoise model denoises AND
-- demosaicks in one pass, so its output is linear RGB at the
-- original CFA resolution (not a CFA mosaic). Saved as a LinearRaw
-- DNG, which darktable can re-import as an already-debayered raw.
--
-- Pipeline:
--   load CFA [1,1,H,W] + image metadata
--     -> bayer_pack [1,4,H/2,W/2]
--     -> normalize to [0, 1] using black/white levels (the model is
--        trained on (val - black) / (white - black), not raw ADC)
--     -> pad to [1,4,H/2+2P,W/2+2P]
--     -> tile through model (scale=2, c_out=3) -> [1,3,(H+4P),(W+4P)]
--     -> crop padding back off -> [1,3,H,W]
--     -> save linear DNG -> import + group with source
local function denoise_one(ctx, img, tile_size, job, base_pct, span_pct)
  -- load_raw returns (tensor, meta). tensor is [1,1,H,W] in raw ADC
  -- units; meta carries black/white/wb/CFA info we need to normalise
  -- the input into the [0, 1] range the model was trained on
  local cfa, meta = dt.ai.load_raw(img)
  if not cfa then return false, "load_raw failed" end

  -- crop off optical-black / masked pixels (Canon and others ship
  -- the full sensor buffer including non-light-sensing strips on
  -- the top/left). visible_* and crop_* come from the image
  -- metadata; we snap crop offsets down to an even pixel so the
  -- 2x2 CFA phase at the visible-region origin matches the buffer
  -- (otherwise bayer_pack would group the wrong colours)
  if meta.crop_x and meta.crop_y
     and (meta.crop_x > 0 or meta.crop_y > 0)
  then
    local cx = meta.crop_x - (meta.crop_x % 2)
    local cy = meta.crop_y - (meta.crop_y % 2)
    local cw = meta.visible_width  + (meta.crop_x - cx)
    local ch = meta.visible_height + (meta.crop_y - cy)
    -- ensure even dims for bayer_pack
    cw = cw - (cw % 2)
    ch = ch - (ch % 2)
    cfa = cfa:crop(cy, cx, ch, cw)
  end

  -- uniform-black approximation: most sensors report identical black
  -- levels across the 4 CFA sites, in which case a single scalar
  -- (val - black) / (white - black) normalisation is exact. cameras
  -- with non-uniform per-site black levels (e.g. some PDAF sensors)
  -- would need per-plane scaling -- left as an exercise
  local black = meta.black_level
  local range = meta.white_level - black
  if range <= 0 then range = 65535 end

  -- pack the 1-channel CFA into 4 phase planes so each channel holds
  -- one Bayer site type; the model expects [1,4,H/2,W/2] input
  local packed = cfa:bayer_pack()
  packed:scale_add(1.0 / range, -black / range)
  local pH = packed:shape()[3]
  local pW = packed:shape()[4]

  -- save the post-normalisation input mean for gain-matching the
  -- model output: the bayer rawdenoise model emits values on its own
  -- internal scale, not [0, 1], so we rescale so output mean matches
  -- input mean (the per-tile equivalent of dt's C reference path)
  local in_mean = packed:mean()

  -- pad so the image rim is no longer at a tile boundary; the padded
  -- strip absorbs the network's edge artifacts and is cropped away
  -- after inference (in output space, where the pad covers 2*OVERLAP
  -- pixels per side)
  local padded_in = pad_replicate(packed, OVERLAP)

  local padded_out, err = run_tiled(ctx, padded_in, tile_size, OVERLAP,
                                    SCALE, OUT_CH,
                                    job, base_pct, span_pct)
  if not padded_out then return false, err end

  -- crop the padded region (in output coords: pad * scale per side)
  -- back to the original-CFA resolution
  local out_rgb = padded_out:crop(OVERLAP * SCALE, OVERLAP * SCALE,
                                  pH * SCALE, pW * SCALE)

  -- gain-match: rescale the output so its mean matches the input
  -- mean, bringing the model's internal-scale output back into the
  -- [0, 1] range save_dng_linear expects
  local out_mean = out_rgb:mean()
  if out_mean > 1e-8 then
    out_rgb:scale_add(in_mean / out_mean)
  end

  local base = img.filename:match("(.+)%..+$") or img.filename
  local out_path = img.path .. "/" .. base .. "_rawdenoised.dng"
  -- LinearRaw DNG: tensor values must be normalised to [0, 1] camRGB;
  -- the model handles black-subtract + scale internally, so we just
  -- pass the output through
  dt.ai.save_dng_linear(out_rgb, img, out_path)

  -- import the result and group with the source so they live together
  -- in the lighttable
  local imported = dt.database.import(out_path)
  if imported then imported:group_with(img) end
  return true
end

-- Button handler: looks up the active rawdenoise model, fans out the
-- selected images, and reports progress via a cancellable job.
local function process_raw_denoise()
  local model_id = dt.ai.model_for_task("rawdenoise")
  if not model_id then
    dt.print("no rawdenoise model enabled -- pick one in preferences -> AI")
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
    string.format("AI raw denoise (%d image%s)",
                  #images, #images == 1 and "" or "s"),
    true,
    function(j) j.valid = false end)

  dt.print_log(string.format(
    "[ai_raw_denoise] starting: %d image%s with model %s",
    #images, #images == 1 and "" or "s", model_id))
  local t_start = os.time()

  -- rawdenoise packages ship multiple files (one per CFA type); pick
  -- the Bayer variant. X-Trans / Foveon would use model_linear.onnx
  -- with a different preprocessing pipeline (no bayer_pack)
  local ctx = dt.ai.load_model(model_id, nil, "model_bayer.onnx")
  if not ctx then
    dt.print("failed to load model: " .. model_id)
    job.valid = false
    return
  end

  local span = 1.0 / #images
  local done = 0
  for i, img in ipairs(images) do
    if not job.valid then break end
    dt.print_log(string.format("[ai_raw_denoise] [%d/%d] %s",
                               i, #images, img.filename))
    local ok, err = denoise_one(ctx, img, TILE_SIZE, job,
                                (i - 1) * span, span)
    if not ok then
      dt.print(string.format("[%d/%d] %s: %s",
                             i, #images, img.filename, tostring(err)))
      dt.print_log(string.format("[ai_raw_denoise] [%d/%d] %s FAILED: %s",
                                 i, #images, img.filename, tostring(err)))
    else
      done = done + 1
    end
  end

  ctx:close()
  job.valid = false
  local elapsed = os.time() - t_start
  dt.print(string.format("raw denoise complete: %d image%s",
                         #images, #images == 1 and "" or "s"))
  dt.print_log(string.format(
    "[ai_raw_denoise] finished: %d/%d in %ds",
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
  "AI raw denoise",                                   -- displayed name
  true,                                               -- expandable
  false,                                              -- no reset button
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},
  dt.new_widget("box") {
    orientation = "vertical",
    dt.new_widget("button") {
      label = "denoise selected",
      clicked_callback = process_raw_denoise,
    }
  },
  nil, nil
)

-- - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T   M A N A G E R   I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - -

local script_data = {}

script_data.metadata = {
  name = "ai_raw_denoise",
  purpose = "tile-based AI raw denoise using the darktable.ai Lua API",
  author = "Andrii Ryzhkov <andrii.ryzhkov@pm.me>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/ai_raw_denoise"
}

script_data.destroy = destroy

return script_data
