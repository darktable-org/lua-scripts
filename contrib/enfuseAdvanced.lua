--[[Enfuse Advanced plugin for darktable 2.2.X and 2.4.X

  copyright (c) 2017, 2018  Holger Klemm (Original Linux-only version)
  Modified by: Kevin Ertel
  
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

--[[About this plugin
This plugin will add the new export module "fusion to DRI or DFF image".
   
----REQUIRED SOFTWARE----
align_image_stack
enfuse ver. 4.2 or greater
exiftool

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file in to your "lua/contrib" folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in
On the initial startup go to darktable settings > lua options and set your executable paths and other preferences, then restart darktable

DRI = Dynamic Range Increase (Blend multiple bracket images into a single LDR file)
DFF = Depth From Focus ("Focus Stacking" - Blend multiple images with different focus into a single image)
Select multiple images that are either bracketed, or focus-shifted, set your desired operating parameters, and press the export button. A new image will be created. The image will
be auto imported into darktable if you have that option enabled. Additional tags or style can be applied on auto import as well, if you desire.

image align options:
See align_image_stack documentation for further explanation of how it specifically works and the options provided (http://hugin.sourceforge.net/docs/manual/Align_image_stack.html)

image fustion options:
See enfuse documentation for further explanation of how it specifically works and the options provided (https://wiki.panotools.org/Enfuse)
If you have a specific set of parameters you frequently like to use, you can save them to a preset. There are 3 presets available for DRI, and 3 for DFF.

target file:
Select your file destination path, or check the "save to source image location" option.
Unless "Create unique filename" is check, it will overwrite existing files
Set any tags or style you desire to be added to the new image (only available if the auto-import option is enabled). You can also change the defaults for this under settings > lua options

format options:
Same as other export modules

global options:
Same as other export modules

----KNOWN ISSUES----
Cannot handle spaces in image paths on windows machienes
Pops up multiple CMD windows on windows machienes
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local dsys = require "lib/dtutils.system"
local gettext = dt.gettext
local preferences_version = 1 --When releasing an update increment this number by one if changes have been made to the preferences structure that would require a re-initialization

-- works with LUA API version 5.0.0
dt.configuration.check_version(...,{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("enfuseAdvanced",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("enfuseAdvanced", msgid)
end

--Detect User Styles--
styles = dt.styles
styles_count = 1 -- "none" = 1
for _,i in pairs(dt.styles) do
	if type(i) == "userdata" then styles_count = styles_count + 1 end
end

-- INITS --
pref_style = dt.preferences.read("module_enfuseAdvanced", "style", "string")
pref_cpytags = dt.preferences.read("module_enfuseAdvanced", "copy_tags", "bool")
pref_addtags = dt.preferences.read("module_enfuseAdvanced", "add_tags", "string")
if dt.configuration.running_os == "windows" then
	os_path_seperator = "\\"
else
	os_path_seperator = "/"
end

--Ensure Required Software is Installed--
not_installed = 0
dt.print_log("enfuseAdvanced - Executable Path Preference: "..df.get_executable_path_preference("align_image_stack"))
local AIS_path = df.check_if_bin_exists("align_image_stack")
if not AIS_path then
	dt.print_error("align image stack not found")
	dt.print("ERROR - align image stack not found")
	not_installed = 1
end

dt.print_log("enfuseAdvanced - Executable Path Preference: "..df.get_executable_path_preference("enfuse"))
local enfuse_path = df.check_if_bin_exists("enfuse")
if not enfuse_path then
	dt.print_error("enfuse not found")
	dt.print("ERROR - enfuse not found")
	not_installed = 1
end

dt.print_log("enfuseAdvanced - Executable Path Preference: "..df.get_executable_path_preference("exiftool"))
local exiftool_path = df.check_if_bin_exists("exiftool")
if not exiftool_path then
	dt.print_error("exiftool not found")
	dt.print("ERROR - exiftool not found")
	not_installed = 1
end
 
	
--Ensure proper version of Enfuse installed--
--[[
local enfuseVersionStartCommand = enfuse_path .. " --version | " .. grep .. " \"enfuse 4.2\""
local enfuse_version = dsys.external_command(enfuseVersionStartCommand)
if enfuse_version ~= 0 then
  dt.print(_('ERROR: wrong enfuse version found. the plugin works only with enfuse 4.2! please install enfuse version 4.2'))
  not_installed = 1
end
]]

if dt.preferences.read("enfuseAdvanced",  "pref_version", "integer") ~= preferences_version then
	dt.print_log("enfuseAdvanced - (Re)Initializing preferences due to script load/changes detected")
	-- align defaults
   dt.preferences.write("enfuseAdvanced", "selected_fusion", "integer", 1)
   dt.preferences.write("align_image_stack", "def_radial_distortion", "bool", false)
   dt.preferences.write("align_image_stack", "def_optimize_field", "bool", false)
   dt.preferences.write("align_image_stack", "def_optimize_image_center", "bool", true) 
   dt.preferences.write("align_image_stack", "def_auto_crop", "bool", true) 
   dt.preferences.write("align_image_stack", "def_distortion", "bool", true) 
   dt.preferences.write("align_image_stack", "def_grid_size", "integer", 5)
   dt.preferences.write("align_image_stack", "def_control_points", "integer", 8)
   dt.preferences.write("align_image_stack", "def_control_points_remove", "integer", 3)
   dt.preferences.write("align_image_stack", "def_correlation", "integer", 9)
   
   -- enfuse defaults
   dt.preferences.write("enfuseAdvanced", "def_fusion_type", "integer", 1)
   dt.preferences.write("enfuseAdvanced", "def_image_variants", "bool", false)
   dt.preferences.write("enfuseAdvanced", "def_hard_masks", "bool", false) 
   dt.preferences.write("enfuseAdvanced", "def_save_masks", "bool", false) 
   dt.preferences.write("enfuseAdvanced", "def_contrast_window_size", "integer", 3)
   dt.preferences.write("enfuseAdvanced", "def_contrast_edge_scale", "integer", 1)
   dt.preferences.write("enfuseAdvanced", "def_contrast_min_curvature", "integer", 1) 
   dt.preferences.write("enfuseAdvanced", "def_exposure_weight", "float", 1.0)
   dt.preferences.write("enfuseAdvanced", "def_saturation_weight", "float", 0.2)
   dt.preferences.write("enfuseAdvanced", "def_contrast_weight", "float", 0.0)
   dt.preferences.write("enfuseAdvanced", "def_exposure_optimum_weight", "float", 0.5)
   dt.preferences.write("enfuseAdvanced", "def_exposure_width_weight", "float",0.2)
   dt.preferences.write("enfuseAdvanced", "selected_overwrite", "integer",1)
   dt.preferences.write("enfuseAdvanced", "sentitiv_overwrite", "bool",true)
   
   -- preset DRI 1
	temp_text = {"dri1_","dri2_","dri3_"}
	for i,preset in pairs(temp_text) do
		dt.preferences.write("enfuseAdvanced", preset.."hard_masks", "bool", false) 
		dt.preferences.write("enfuseAdvanced", preset.."save_masks", "bool", false) 
		dt.preferences.write("enfuseAdvanced", preset.."contrast_window_size", "integer", 3)
		dt.preferences.write("enfuseAdvanced", preset.."contrast_edge_scale", "integer", 1)
		dt.preferences.write("enfuseAdvanced", preset.."contrast_min_curvature", "integer", 1) 
		dt.preferences.write("enfuseAdvanced", preset.."exposure_weight", "float", 1.0)
		dt.preferences.write("enfuseAdvanced", preset.."saturation_weight", "float", 0.2)
		dt.preferences.write("enfuseAdvanced", preset.."contrast_weight", "float", 0.0)
		dt.preferences.write("enfuseAdvanced", preset.."exposure_optimum_weight", "float", 0.5)
		dt.preferences.write("enfuseAdvanced", preset.."exposure_width_weight", "float",0.2)
	end
   
   -- preset DFF 1
   	temp_text = {"dff1_","dff2_","dff3_"}
	for i,preset in pairs(temp_text) do
		dt.preferences.write("enfuseAdvanced", preset.."hard_masks", "bool", true) 
		dt.preferences.write("enfuseAdvanced", preset.."save_masks", "bool", false) 
		dt.preferences.write("enfuseAdvanced", preset.."contrast_window_size", "integer", 3)
		dt.preferences.write("enfuseAdvanced", preset.."contrast_edge_scale", "integer", 1)
		dt.preferences.write("enfuseAdvanced", preset.."contrast_min_curvature", "integer", 1)  
		dt.preferences.write("enfuseAdvanced", preset.."exposure_weight", "float", 0.0)
		dt.preferences.write("enfuseAdvanced", preset.."saturation_weight", "float", 0.0)
		dt.preferences.write("enfuseAdvanced", preset.."contrast_weight", "float", 1.0)
		dt.preferences.write("enfuseAdvanced", preset.."exposure_optimum_weight", "float", 0.5)
		dt.preferences.write("enfuseAdvanced", preset.."exposure_width_weight", "float",0.2)
	end
   
	-- preset FREE
	dt.preferences.write("enfuseAdvanced", "free_hard_masks", "bool", false) 
	dt.preferences.write("enfuseAdvanced", "free_save_masks", "bool", false) 
	dt.preferences.write("enfuseAdvanced", "free_contrast_window_size", "integer", 3)
	dt.preferences.write("enfuseAdvanced", "free_contrast_edge_scale", "integer", 1)
	dt.preferences.write("enfuseAdvanced", "free_contrast_min_curvature", "integer", 1)  
	dt.preferences.write("enfuseAdvanced", "free_exposure_weight", "float", 0.0)
	dt.preferences.write("enfuseAdvanced", "free_saturation_weight", "float", 0.0)
	dt.preferences.write("enfuseAdvanced", "free_contrast_weight", "float", 0.0)
	dt.preferences.write("enfuseAdvanced", "free_exposure_optimum_weight", "float", 0.0)
	dt.preferences.write("enfuseAdvanced", "free_exposure_width_weight", "float",0.0)
   
   -- output
   dt.preferences.write("enfuseAdvanced", "selected_output_format", "integer", 1)
   
   --tracking
   dt.preferences.write("enfuseAdvanced", "pref_version", "integer", preferences_version)
end

--GUI
j=0
enf_separator1 = dt.new_widget("separator"){}
enf_separator1b = dt.new_widget("separator"){}
enf_separator2 = dt.new_widget("separator"){}
enf_separator2b = dt.new_widget("separator"){}
enf_label_align_options= dt.new_widget("section_label"){
     label = _('image align options')
}
enf_label_enfuse_options= dt.new_widget("section_label"){
     label = _('image fusion options')
}
enf_label_output_format= dt.new_widget("section_label"){
     label = _('target file')
}
enf_label_path = dt.new_widget("label"){
     label = _('directory'),
     ellipsize = "start",
     halign = "start"
}
enf_chkbtn_radial_distortion = dt.new_widget("check_button"){
	label = _('optimize radial distortion for all images'),
	value = dt.preferences.read("align_image_stack", "def_radial_distortion", "bool"),
	tooltip = _('optimize radial distortion for all images, \nexcept for first'),
}
enf_chkbtn_optimize_field = dt.new_widget("check_button"){
    label = _('optimize field of view for all images'), 
    value = dt.preferences.read("align_image_stack", "def_optimize_field", "bool"),
    tooltip =_('optimize field of view for all images, except for first. \nUseful for aligning focus stacks (DFF) with slightly \ndifferent magnification.'), 
}
enf_chkbtn_optimize_image_center = dt.new_widget("check_button"){
    label = _('optimize image center shift for all images'), 
    value = dt.preferences.read("align_image_stack", "def_optimize_image_center", "bool"),
    tooltip =_('optimize image center shift for all images, \nexcept for first.'),   
}
enf_chkbtn_auto_crop = dt.new_widget("check_button"){
    label = _('auto crop the image'), 
    value = dt.preferences.read("align_image_stack", "def_auto_crop", "bool"),
    tooltip =_('auto crop the image to the area covered by all images.'),   
}
enf_chkbtn_distortion = dt.new_widget("check_button"){
    label = _('load distortion from lens database'), 
    value = dt.preferences.read("align_image_stack", "def_distortion", "bool"),
    tooltip =_('try to load distortion information from lens database'),   
}
enf_chkbtn_hard_masks = dt.new_widget("check_button"){
    label = _('hard mask'), 
    value = dt.preferences.read("enfuseAdvanced", "def_hard_masks", "bool"),
    tooltip =_('force hard blend masks on the finest scale. this avoids \naveraging of fine details (only), at the expense \nof increasing the noise. this improves the \nsharpness of focus stacks considerably.\ndefault (soft mask)'),   
    reset_callback = function(self) 
       self.value = dt.preferences.read("enfuseAdvanced", "def_hard_masks", "bool")
    end
}
enf_chkbtn_save_masks = dt.new_widget("check_button"){
    label = _('save masks'), 
    value = dt.preferences.read("enfuseAdvanced", "def_save_masks", "bool"),
    tooltip =_('Save the generated weight masks to your home directory,\nenblend saves masks as 8 bit grayscale, \ni.e. single channel images. \nfor accuracy we recommend to choose a lossless format.'),  
    reset_callback = function(self) 
       self.value = dt.preferences.read("enfuseAdvanced", "def_save_masks", "bool")
    end 
}
enf_chkbtn_cpytags = dt.new_widget("check_button"){
    label = '  Copy Tags', 
    value = pref_cpytags,
    tooltip ='Copy tags from first image.',  
}
enf_sldr_exposure_weight = dt.new_widget("slider"){
  label = _('exposure weight'),
  tooltip = _('set the relative weight of the well-exposedness criterion \nas defined by the chosen exposure weight function. \nincreasing this weight relative to the others will\n make well-exposed pixels contribute more to\n the final output. \ndefault: (1.0)'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuseAdvanced", "def_exposure_weight", "float") --1 def
}
enf_sldr_saturation_weight = dt.new_widget("slider"){
  label = _('saturation weight'),
  tooltip = _('set the relative weight of high-saturation pixels. \nincreasing this weight makes pixels with high \nsaturation contribute more to the final output. \ndefault: (0.2)'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuseAdvanced", "def_saturation_weight", "float"), --0.5
}
enf_sldr_contrast_weight = dt.new_widget("slider"){
  label = _('contrast weight'),
  tooltip = _('sets the relative weight of high local-contrast pixels. \ndefault: (0.0).'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuseAdvanced", "def_contrast_weight", "float")--0 default
}
enf_sldr_exposure_optimum_weight = dt.new_widget("slider"){
  label = _('exposure optimum'),
  tooltip = _('determine at what normalized exposure value\n the optimum exposure of the input images\n is. this is, set the position of the maximum\n of the exposure weight curve. use this \noption to fine-tune exposure weighting. \ndefault: (0.5)'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuseAdvanced", "def_exposure_optimum_weight", "float")--0.5 default0
}
enf_sldr_exposure_width_weight = dt.new_widget("slider"){
  label = _('exposure width'),
  tooltip = _('set the characteristic width (FWHM) of the exposure \nweight function. low numbers give less weight to \npixels that are far from the user-defined \noptimum and vice versa. use this option to \nfine-tune exposure weighting. \ndefault: (0.2)'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuseAdvanced", "def_exposure_width_weight", "float") --0.2 default
}
enf_file_chooser_button_path = dt.new_widget("file_chooser_button"){
    title = _('Select export path'),  -- The title of the window when choosing a file
    is_directory = true,             -- True if the file chooser button only allows directories to be selecte
    tooltip =_('select the target directory for the fused image. \nthe filename is created automatically.'),
}
enf_chkbtn_source_location = dt.new_widget("check_button"){
    label = _('save to source image location'), 
    value = true,
    tooltip =_('If checked ignores the location below and saves output image(s) to the same location as the source images.'),  
	reset_callback = function(self) 
       self.value = true
    end 
}
enf_cmbx_grid_size = dt.new_widget("combobox"){
    label = _('image grid size'), 
    tooltip =_('break image into a rectangular grid \nand attempt to find num control points in each section.\ndefault: (5x5)'),
    value = dt.preferences.read("align_image_stack", "def_grid_size", "integer"), --5
    "1", "2", "3","4","5","6","7","8","9",
    reset_callback = function(self)
       self.value = dt.preferences.read("align_image_stack", "def_grid_size", "integer")
    end
} 
enf_cmbx_control_points = dt.new_widget("combobox"){
    label = _('control points/grid'), 
    tooltip =_('number of control points (per grid, see option -g) \nto create between adjacent images \ndefault: (8).'),
    value = dt.preferences.read("align_image_stack", "def_control_points", "integer"),   --8, "1", "2", "3","4","5","6","7","8","9",
    "1", "2", "3","4","5","6","7","8","9",             
    reset_callback = function(self)
       self.value = dt.preferences.read("align_image_stack", "def_control_points", "integer")
    end
} 
enf_cmbx_control_points_remove = dt.new_widget("combobox"){
    label = _('remove control points with error'), 
    tooltip =_('remove all control points with an error higher \nthan num pixels \ndefault: (3)'),
    value = dt.preferences.read("align_image_stack", "def_control_points_remove", "integer"), --3, "1", "2", "3","4","5","6","7","8","9",
    "1", "2", "3","4","5","6","7","8","9",              
    reset_callback = function(self)
       self.value = dt.preferences.read("align_image_stack", "def_control_points_remove", "integer")
    end
} 
enf_cmbx_correlation  = dt.new_widget("combobox"){
    label = _('correlation threshold for control points'), 
    tooltip =_('correlation threshold for identifying \ncontrol points \ndefault: (0.9).'),
    value = dt.preferences.read("align_image_stack", "def_correlation", "integer"), --9, "0,1", "0,2", "0,3","0,4","0,5","0,6","0,7","0,8","0,9",
    "0.1", "0.2", "0.3","0.4","0.5","0.6","0.7","0.8","0.9","1.0",     
    reset_callback = function(self)
       self.value = dt.preferences.read("align_image_stack", "def_correlation", "integer")
    end
} 
enf_cmbx_contrast_window_size = dt.new_widget("combobox"){
    label = _('contrast window size'), 
    tooltip =_('set the window size for local contrast analysis. \nthe window will be a square of size × size pixels. \nif given an even size, Enfuse will \nautomatically use the next odd number.\nfor contrast analysis size values larger \nthan 5 pixels might result in a \nblurry composite image. values of 3 and \n5 pixels have given good results on \nfocus stacks. \ndefault: (5) pixels'),
    value = dt.preferences.read("enfuseAdvanced", "def_contrast_window_size", "integer"), --3, "3","4","5","6","7","8","9","10",
    "3", "4", "5","6","7","8","9","10",   
} 
enf_cmbx_contrast_edge_scale = dt.new_widget("combobox"){
    label = _('contrast edge scale'), 
    tooltip =_('a non-zero value for EDGE-SCALE switches on the \nLaplacian-of-Gaussian (LoG) edge detection algorithm.\n edage-scale is the radius of the Gaussian used \nin the search for edges. a positive LCE-SCALE \nturns on local contrast enhancement (LCE) \nbefore the LoG edge detection. \nDefault: (0.0) pixels.'),
    value = dt.preferences.read("enfuseAdvanced", "def_contrast_edge_scale", "integer"), --1, "0:0:0",
    "0.0","0.1","0.2","0.3","0.4","0.5",

}  
enf_cmbx_contrast_min_curvature = dt.new_widget("combobox"){
    label = _('contrast min curvature'),
    tooltip =_('define the minimum curvature for the LoG edge detection. Append a ‘%’ to specify the minimum curvature relative to maximum pixel value in the source image. Default: (0.0%)'),
    value = dt.preferences.read("enfuseAdvanced", "def_contrast_min_curvature", "integer"), --1, "0.0%","0.1%", "0.2%", "0.3%","0.4%","0.5%","0.6%","0.7%","0.8%","0.9%","1.0%", 
    "0.0%", "0.1%", "0.2%","0.3%","0.4%","0.5%","0.6%","0.7%","0.8%","0.9%","1.0%",   
}  
enf_cmbx_existing_file = dt.new_widget("combobox"){
    label = _('on conflict'), 
    value = dt.preferences.read("enfuseAdvanced", "selected_overwrite", "integer"), --1, 
    sensitive= dt.preferences.read("enfuseAdvanced", "sentitiv_overwrite", "bool"), --1, 
    _('create unique filename'),_('overwrite'),           
    reset_callback = function(self)
       self.value = dt.preferences.read("enfuseAdvanced", "selected_overwrite", "integer")
    end
}  
enf_cmbx_style = dt.new_widget("combobox"){
	label = "Apply Style on Import",
	tooltip = "Apply selected style on auto-import to newly created blended image",
	value = 1,
	"none",
	}
pref_style_enum = 1
for k=1, (styles_count-1) do
	enf_cmbx_style[k+1] = styles[k].name
	if styles[k].name == pref_style then pref_style_enum = k+1 end
end
enf_cmbx_style.value = pref_style_enum
enf_chkbtn_image_variations = dt.new_widget("check_button"){
    label = _('create image variants with saved presets'), 
    value = dt.preferences.read("enfuseAdvanced", "def_image_variants", "bool"),
    tooltip =_('creates image variants with the three \nsaved DRI or DFF presets'),   
    sensitive=true,
    clicked_callback = function(self) 
		if (self.value) then
			dt.preferences.write("enfuseAdvanced", "def_image_variants", "bool", true)
			dt.preferences.write("enfuseAdvanced", "sentitiv_overwrite", "bool",false)
			enf_cmbx_existing_file.value=1
			enf_cmbx_existing_file.sensitive=false
		else  
		   dt.preferences.write("enfuseAdvanced", "def_image_variants", "bool", false)
		   dt.preferences.write("enfuseAdvanced", "sentitiv_overwrite", "bool",true)
		   enf_cmbx_existing_file.sensitive=true 
		end    
    end,
    reset_callback = function(self) 
       dt.preferences.write("enfuseAdvanced", "def_image_variants", "bool", false)
       dt.preferences.write("enfuseAdvanced", "sentitiv_overwrite", "bool",true)
       self.value = false
       enf_cmbx_existing_file.sensitive=true
    end

}
enf_button_save_preset = dt.new_widget("button"){
	label = _('save fusion preset'),
	tooltip =_('save the selected fusion preset'),
	clicked_callback = function() 
		pref_text = ""
		if (enf_cmbx_fusion_type.value == "1 - DRI image") then
			pref_text = "dri1_"
		elseif (enf_cmbx_fusion_type.value == "2 - DRI image") then
			pref_text = "dri2_"
		elseif (enf_cmbx_fusion_type.value == "3 - DRI image") then
			pref_text = "dri3_"
		elseif (enf_cmbx_fusion_type.value == "1 - DFF image") then
			pref_text = "dff1_"
		elseif (enf_cmbx_fusion_type.value == "2 - DFF image") then
			pref_text = "dff2_"
		elseif (enf_cmbx_fusion_type.value == "3 - DFF image") then
			pref_text = "dff3_"
		elseif (enf_cmbx_fusion_type.value == "free preset") then
			pref_text = "free_"
		else
			dt.print(_('unkown error'))
		end
		-- Write Preset
		if pref_text ~= "" then
			dt.preferences.write("enfuseAdvanced", pref_text.."hard_masks", "bool", enf_chkbtn_hard_masks.value) 
			dt.preferences.write("enfuseAdvanced", pref_text.."save_masks", "bool", enf_chkbtn_save_masks.value) 
			dt.preferences.write("enfuseAdvanced", pref_text.."contrast_window_size", "integer", enf_cmbx_contrast_window_size.selected)
			dt.preferences.write("enfuseAdvanced", pref_text.."contrast_edge_scale", "integer", enf_cmbx_contrast_edge_scale.selected)
			dt.preferences.write("enfuseAdvanced", pref_text.."contrast_min_curvature", "integer", enf_cmbx_contrast_min_curvature.selected) 
			dt.preferences.write("enfuseAdvanced", pref_text.."exposure_weight", "float", enf_sldr_exposure_weight.value)
			dt.preferences.write("enfuseAdvanced", pref_text.."saturation_weight", "float", enf_sldr_saturation_weight.value)
			dt.preferences.write("enfuseAdvanced", pref_text.."contrast_weight", "float", enf_sldr_contrast_weight.value)
			dt.preferences.write("enfuseAdvanced", pref_text.."exposure_optimum_weight", "float", enf_sldr_exposure_optimum_weight.value)
			dt.preferences.write("enfuseAdvanced", pref_text.."exposure_width_weight", "float",enf_sldr_exposure_width_weight.value)
			dt.print(_('preset '..pref_text..' saved')) 
		end
	end
}
enf_button_load_preset = dt.new_widget("button"){
      label = _('load fusion defaults'),
      tooltip =_('load the default fusion settings'),
      clicked_callback = function() 
        enf_chkbtn_hard_masks.value=dt.preferences.read("enfuseAdvanced", "def_hard_masks", "bool") 
        enf_chkbtn_save_masks.value=dt.preferences.read("enfuseAdvanced", "def_save_masks", "bool") 
        enf_cmbx_contrast_window_size.value=dt.preferences.read("enfuseAdvanced", "def_contrast_window_size", "integer")
        enf_cmbx_contrast_edge_scale.value=dt.preferences.read("enfuseAdvanced", "def_contrast_edge_scale", "integer")
        enf_cmbx_contrast_min_curvature.value=dt.preferences.read("enfuseAdvanced", "def_contrast_min_curvature", "integer")
        enf_sldr_exposure_weight.value=dt.preferences.read("enfuseAdvanced", "def_exposure_weight", "float")
        enf_sldr_saturation_weight.value=dt.preferences.read("enfuseAdvanced", "def_saturation_weight", "float")
        enf_sldr_contrast_weight.value=dt.preferences.read("enfuseAdvanced", "def_contrast_weight", "float")
        enf_sldr_exposure_optimum_weight.value=dt.preferences.read("enfuseAdvanced", "def_exposure_optimum_weight", "float")
        enf_sldr_exposure_width_weight.value=dt.preferences.read("enfuseAdvanced", "def_exposure_width_weight", "float")
     end
      
}
enf_cmbx_output_format = dt.new_widget("combobox"){
    label = _('file format'), 
    value = dt.preferences.read("enfuseAdvanced", "selected_output_format", "integer"), --1, "TIFF", "JPEG", "PNG","PNM","PBM","PGM","PPM",
    changed_callback = function(self) 
      dt.preferences.write("enfuseAdvanced", "selected_output_format", "integer", self.selected)
    end,
    "TIFF", "JPEG", "PNG","PNM","PBM","PPM",            
    reset_callback = function(self)
       self.value = dt.preferences.read("enfuseAdvanced", "selected_output_format", "integer")
    end
}  
enf_cmbx_fusion_type = dt.new_widget("combobox"){
    label = _('fusion preset'), 
    tooltip =_('select the preset and save the preset\n if you want to reuse it or create an image\n variant'),
    value = 1, --dt.preferences.read("enfuseAdvanced", "def_fusion_type", "integer"), --1, "DRI image", "DFF image", "without preset",
    changed_callback = function(self) 
		dt.preferences.write("enfuseAdvanced", "def_fusion_type", "integer", self.selected)

		if (self.value == "1 - DRI image") then
			pref_text = "dri1_"
		elseif (self.value == "2 - DRI image") then
			pref_text = "dri2_"
		elseif (self.value == "3 - DRI image") then
			pref_text = "dri3_"
		elseif (self.value == "1 - DFF image") then
			pref_text = "dff1_"
		elseif (self.value == "2 - DFF image") then
			pref_text = "dff2_"
		elseif (self.value == "3 - DFF image") then
			pref_text = "dff3_"
		elseif (self.value == "free preset") then
			pref_text = "free_"
		end
		
		if string.match(pref_text,"^dri")~=nil then
			enf_chkbtn_hard_masks.sensitive=false
			enf_chkbtn_hard_masks.value=false
			enf_sldr_contrast_weight.sensitive=true
		elseif string.match(pref_text,"^dff")~=nil then
			enf_chkbtn_hard_masks.sensitive=false
			enf_chkbtn_hard_masks.value=true
			enf_sldr_contrast_weight.sensitive=false
		else
			enf_chkbtn_hard_masks.sensitive=true
			enf_chkbtn_hard_masks.value=false
			enf_sldr_contrast_weight.sensitive=true
		end
		
        enf_chkbtn_hard_masks.value=dt.preferences.read("enfuseAdvanced", pref_text.."hard_masks", "bool") 
        enf_chkbtn_save_masks.value=dt.preferences.read("enfuseAdvanced", pref_text.."save_masks", "bool") 
        enf_cmbx_contrast_window_size.value=dt.preferences.read("enfuseAdvanced", pref_text.."contrast_window_size", "integer")
        enf_cmbx_contrast_edge_scale.value=dt.preferences.read("enfuseAdvanced", pref_text.."contrast_edge_scale", "integer")
        enf_cmbx_contrast_min_curvature.value=dt.preferences.read("enfuseAdvanced", pref_text.."contrast_min_curvature", "integer") 
        enf_sldr_exposure_weight.value=dt.preferences.read("enfuseAdvanced", pref_text.."exposure_weight", "float")
        enf_sldr_saturation_weight.value=dt.preferences.read("enfuseAdvanced", pref_text.."saturation_weight", "float")
        enf_sldr_contrast_weight.value=dt.preferences.read("enfuseAdvanced", pref_text.."contrast_weight", "float")
        enf_sldr_exposure_optimum_weight.value=dt.preferences.read("enfuseAdvanced", pref_text.."exposure_optimum_weight", "float")
        enf_sldr_exposure_width_weight.value=dt.preferences.read("enfuseAdvanced", pref_text.."exposure_width_weight", "float")   
	
    end,
    "1 - DRI image", "2 - DRI image","3 - DRI image","1 - DFF image", "2 - DFF image","3 - DFF image","free preset",  
    
    reset_callback = function(self_type)
       enf_cmbx_fusion_type.value = dt.preferences.read("enfuseAdvanced", "def_fusion_type", "integer")
    end
} 
enf_entry_tag = dt.new_widget("entry"){
	tooltip = "Additional tags to be added on import. Seperate with commas, all spaces will be removed",
	text = pref_addtags,
	placeholder = "Enter tags, seperated by commas",
	editable = true
}
enf_widget = dt.new_widget("box") {
    orientation = "vertical",
    enf_label_align_options,
    enf_chkbtn_radial_distortion,
    enf_chkbtn_optimize_field,
    enf_chkbtn_optimize_image_center,
    enf_chkbtn_auto_crop,
    enf_chkbtn_distortion,
    enf_cmbx_grid_size,
    enf_cmbx_control_points,
    enf_cmbx_control_points_remove,
    enf_cmbx_correlation,
    enf_separator1,
    enf_separator1b,
    enf_label_enfuse_options,
    enf_cmbx_fusion_type,
    enf_chkbtn_image_variations,
    enf_sldr_exposure_weight,
    enf_sldr_saturation_weight,
    enf_sldr_contrast_weight,
    enf_sldr_exposure_optimum_weight,
    enf_sldr_exposure_width_weight, 
    enf_chkbtn_hard_masks,
    enf_chkbtn_save_masks,
    enf_cmbx_contrast_edge_scale,
    enf_cmbx_contrast_min_curvature,
    enf_cmbx_contrast_window_size,
    enf_button_save_preset,
    enf_button_load_preset,
    enf_separator2,
    enf_separator2b,
    enf_label_output_format,
    enf_cmbx_output_format,
    enf_label_path,
    enf_file_chooser_button_path,
	enf_chkbtn_source_location,
    enf_cmbx_existing_file,
	enf_cmbx_style,
	enf_chkbtn_cpytags,
	enf_entry_tag,
}

-- FUNCTION -- 
local function GetFileName(full_path)
	--[[Parses a full path (path/filename_identifier.extension) into individual parts
	Input: Folder1/Folder2/Folder3/Img_0001.CR2
	
	Returns:
	path: Folder1/Folder2/Folder3/
	filename: Img_0001
	identifier: 0001
	extension: .CR2
	
	EX:
	path_1, file_1, id_1, ext_1 = GetFileName(full_path_1)
	]]
	local path = string.match(full_path, ".*[\\/]")
	local filename = string.gsub(string.match(full_path, "[%w-_]*%.") , "%." , "" ) 
	local identifier = string.match(filename, "%d*$")
	local extension = string.match(full_path, "%.%w*")
    return path, filename, identifier, extension
end
local function truncate(x)
      return x<0 and math.ceil(x) or math.floor(x)
end 
local function replace_comma_to_dot(s)
	return string.gsub(s, "%,", ".")
end
local function remove_temp_files()
	if dt.configuration.running_os == "windows" then
		dt.print_log("enfuseAdvanced - Deleting temp files...")
		dt.control.execute("del "..images_to_align)
		dt.control.execute("del "..images_to_blend)
		dt.print_log("enfuseAdvanced - Done deleting")
	else
		dt.print_log("enfuseAdvanced - Deleting temp files...")
		dt.control.execute("rm "..images_to_align)
		dt.control.execute("rm "..images_to_blend)
		dt.print_log("enfuseAdvanced - Done deleting")
	end
end
local function build_execute_command(cmd, args, file_list)
	local result = cmd.." "..args.." "..file_list
	return result
end
local function copy_exif(from_file, to_file)
	exifStartCommand = exiftool_path.." -TagsFromFile "..df.sanitize_filename(from_file).." -exif:all --subifd:all -overwrite_original "..df.sanitize_filename(to_file)
	dt.print_log("enfuseAdvanced - EXIFTool Start Command: "..exifStartCommand)
	resultexif=dsys.external_command(exifStartCommand)
	if (resultexif == 0) then
		dt.print_log("enfuseAdvanced - EXIFTool copy successful")
		dt.print("Copied EXIF data")
	else
		dt.print(_('ERROR: exiftool doesn\'t work. for more informations see terminal output'))
		dt.print_error("exif copy failed")
	end
end
local function align_images()
	dt.print(_('aligning images'))
	
	--Setup Align Image Stack Arguments--
	align_args = ""
	if (enf_chkbtn_radial_distortion.value) then align_args = align_args.." -d" end
	if (enf_chkbtn_optimize_field.value) then align_args = align_args.." -m" end  
	if (enf_chkbtn_optimize_image_center.value) then align_args = align_args.." -i" end
	if (enf_chkbtn_auto_crop.value) then align_args = align_args.." -C" end     
	if (enf_chkbtn_distortion.value) then align_args = align_args.." --distortion" end
	align_args = align_args.." -g "..enf_cmbx_grid_size.value
	align_args = align_args.." -c "..enf_cmbx_control_points.value          
	align_args = align_args.." -t "..enf_cmbx_control_points_remove.value
	align_args = align_args.." --corr="..enf_cmbx_correlation.value
	if (dt.preferences.read("module_enfuseAdvanced", "align_use_gpu", "bool")) then align_args = align_args.." --gpu" end
	align_args = align_args.." -a "..df.sanitize_filename(first_path.."aligned_")..' '
	alignStartCommand = build_execute_command(AIS_path, align_args, images_to_align)
	dt.print_log("enfuseAdvanced - Align Start Command: "..alignStartCommand)
	resp = dsys.external_command(alignStartCommand)
	dt.print_log("enfuseAdvanced - Completed Align")
	return resp
end
local function blend_images()
	blend_args = ""
	if from_preset then --load args from preset preferences
		blend_args=blend_args.." --exposure-weight="..(replace_comma_to_dot(dt.preferences.read("enfuseAdvanced", preset_text.."_exposure_weight", "float")))
		blend_args=blend_args.." --saturation-weight="..(replace_comma_to_dot(dt.preferences.read("enfuseAdvanced", preset_text.."_saturation_weight", "float"))) 
		blend_args=blend_args.." --contrast-weight="..(replace_comma_to_dot(dt.preferences.read("enfuseAdvanced", preset_text.."_contrast_weight", "float")))
		blend_args=blend_args.." --exposure-optimum="..(replace_comma_to_dot(dt.preferences.read("enfuseAdvanced", preset_text.."_exposure_optimum_weight", "float")))
		blend_args=blend_args.." --exposure-width="..(replace_comma_to_dot(dt.preferences.read("enfuseAdvanced", preset_text.."_exposure_width_weight", "float")))
		if (enf_chkbtn_hard_masks.value) then blend_args=blend_args.."--hard-mask" end
		if (enf_chkbtn_save_masks.value) then blend_args=blend_args.."--save-masks" end
		blend_args=blend_args.." --contrast-window-size="..dt.preferences.read("enfuseAdvanced", preset_text.."_contrast_window_size", "integer")
		blend_args=blend_args.." --contrast-edge-scale="..dt.preferences.read("enfuseAdvanced", preset_text.."_contrast_edge_scale", "integer")
		blend_args=blend_args.." --contrast-min-curvature="..dt.preferences.read("enfuseAdvanced", preset_text.."_contrast_min_curvature", "integer")
		blend_args=blend_args.." --depth="..dt.preferences.read("module_enfuseAdvanced", "image_color_depth", "enum")
	else --load args from GUI values
		blend_args = blend_args.." --exposure-weight="..(replace_comma_to_dot(enf_sldr_exposure_weight.value))
		blend_args = blend_args.." --saturation-weight="..(replace_comma_to_dot(enf_sldr_saturation_weight.value))            
		blend_args = blend_args.." --contrast-weight="..(replace_comma_to_dot(enf_sldr_contrast_weight.value))
		blend_args = blend_args.." --exposure-optimum="..(replace_comma_to_dot(enf_sldr_exposure_optimum_weight.value))
		blend_args = blend_args.." --exposure-width="..(replace_comma_to_dot(enf_sldr_exposure_width_weight.value))
		if (enf_chkbtn_hard_masks.value) then blend_args = blend_args.." --hard-mask" end
		if (enf_chkbtn_save_masks.value) then blend_args = blend_args.." --save-masks" end
		blend_args = blend_args.." --contrast-window-size="..enf_cmbx_contrast_window_size.value
		blend_args = blend_args.." --contrast-edge-scale="..enf_cmbx_contrast_edge_scale.value
		blend_args = blend_args.." --contrast-min-curvature="..enf_cmbx_contrast_min_curvature.value
		blend_args = blend_args.." --depth="..dt.preferences.read("module_enfuseAdvanced", "image_color_depth", "enum")
	end
	
	--set output format per GUI selection
	if (enf_cmbx_output_format.value == "TIFF") then
		cmd_suffix_output_format="tif"
		blend_args = blend_args.." --compression="..dt.preferences.read("module_enfuseAdvanced", "compression_tiff", "enum")
	elseif (enf_cmbx_output_format.value == "JPEG") then
		cmd_suffix_output_format="jpg"
		blend_args = blend_args.." --compression="..truncate(dt.preferences.read("module_enfuseAdvanced", "compression_jpeg", "integer"))
	elseif (enf_cmbx_output_format.value == "PNG") then
		cmd_suffix_output_format="png"
	elseif (enf_cmbx_output_format.value == "PNM") then
		cmd_suffix_output_format="pnm"     
	elseif (enf_cmbx_output_format.value == "PBM") then
		cmd_suffix_output_format="pbm"   
	elseif (enf_cmbx_output_format.value == "PPM") then
		cmd_suffix_output_format="ppm"
	end

	--Set output path and add filename
	if (enf_chkbtn_source_location.value) then
		cmd_output_path = enf_source_path
	else
	cmd_output_path=enf_file_chooser_button_path.value 
	end
	path_with_filename = cmd_output_path..os_path_seperator..first_filename.."-"..last_id.."."..cmd_suffix_output_format
	
	--Create unique name with index if GUI selection create unique name (don't overwrite), also do this if user selected to make variants from presets
	if (enf_cmbx_existing_file.selected == 1) or (from_preset) then
		path_with_filename = df.create_unique_filename(path_with_filename)
	end
	
	cmd_output_image = " --output="..df.sanitize_filename(path_with_filename)
	blend_args = blend_args..cmd_output_image

	images_to_blend = ""
	for j=0, counted_images-1 do
		if j < 10 then
			id = "000"..tostring(j)
		else
			id = "00"..tostring(j)
		end
		--[[if dt.configuration.running_os == "windows" then
			images_to_blend = images_to_blend..first_path.."aligned_"..id..".tif "
		else
			images_to_blend = images_to_blend..'"'..first_path.."aligned_"..id..".tif"..'" '
		end]]
		images_to_blend = images_to_blend..first_path.."aligned_"..id..".tif "
	end
	BlendStartCommand=build_execute_command(enfuse_path, blend_args, images_to_blend)
	
	dt.print_log("enfuseAdvanced - Blend Start Command: "..BlendStartCommand)
	resultBlend=dsys.external_command(BlendStartCommand)
	dt.print_log("enfuseAdvanced - Completed Blend")

	return resultBlend, path_with_filename
end
local function show_status(enf_storage, image, format, filename, --Store: Called on each exported image
  number, total, high_quality, extra_data)
     dt.print(_('export TIFF for image fusion ')..tostring(truncate(number)).." / "..tostring(truncate(total)))   
end
local function create_image_fusion(enf_storage, image_table, extra_data) --Finalize: Called once when all images are done exporting	
--Create Images String--
	images_to_align = ""
	images_to_blend = ""
	counted_images=0
	first_id = "999999999999999999999999"
	last_id = "0"
	for source_image,image_path in pairs(image_table) do
		counted_images=counted_images+1
		--[[if dt.configuration.running_os == "windows" then
			images_to_align = images_to_align..image_path..' '
		else
			images_to_align = images_to_align..'"'..image_path..'" '
		end]]
		images_to_align = images_to_align..df.sanitize_filename(image_path)..' '
		curr_path, curr_filename, curr_id, curr_ext = GetFileName(image_path)
		if (curr_id < first_id) then 
			first_path = curr_path
			first_filename = curr_filename
			first_id = curr_id
			first_ext = curr_ext
			dt_source_image = source_image
		end 
		if (curr_id > last_id) then 
			last_path = curr_path
			last_filename = curr_filename
			last_id = curr_id
			last_ext = curr_ext
		end
		enf_source_path = source_image.path
		exif_source_file = source_image.path..os_path_seperator..source_image.filename
	end

--Check if at least 2 images selected--
	if (counted_images<=1) then
		dt.print(_('ERROR: not enough pictures selected. please select two or more images\nfrom the same object, but with different camera settings.'))
		dt.print_error("Not enough pictures selected")
		remove_temp_files()
		return
	end

--Ensure Proper Software Installed--
	if not_installed == 1 then
		dt.print_log("enfuseAdvanced - Required software not found")
		dt.print("Required software not found")
		remove_temp_files()
		return
	end	

--Check that output path selected
	cmd_output_path = enf_file_chooser_button_path.value
	if (cmd_output_path == nil) and not(enf_chkbtn_source_location.value) then
		dt.print(_('ERROR: no target directory selected'))
		remove_temp_files()
		return
	end

	dt.print_log("enfuseAdvanced - Starting Image Fusion")
	job = dt.gui.create_job(_('Creating DRI/DFF image'), true, stop_selection)
	
	percent_step = .33
	if (enf_chkbtn_image_variations.value) then percent_step = .2 end
	job.percent = job.percent + percent_step
	
--Align Images--
	resultalign = align_images()
	if (resultalign ~= 0) then --Aling Image Stack Failed-- 
		dt.print(_('ERROR: align_image_stack doesn\'t work. For more information see terminal output'))
		dt.print_error("Align Image Stack Failed")
		remove_temp_files()
		job.valid = false
		return
	end
	dt.print(_('aligning complete'))
	job.percent = job.percent + percent_step
	
--Blend Images--
	from_preset = false
	iterations = 1
	pref_text = ""
	if (enf_chkbtn_image_variations.value) then
		iterations = 3
		from_preset = true
		if string.match(enf_cmbx_fusion_type.value, "DRI") then 
			pref_text = "dri"
		elseif string.match(enf_cmbx_fusion_type.value, "DFF") then 
			pref_text = "dff" 
		else --if "variants" selected, but not using DRI or DFF preset then cannot create variants
			dt.print("Error, must select a DRI or DFF preset when starting a fustion with variants")
			dt.print_error("DRI or DFF preset not selected when variants option was checked")
			remove_temp_files()
			job.valid = false
			return
		end
	end

	for j = 1, iterations do
		if (from_preset) then
			preset_text=pref_text..j
		else
			preset_text=""
		end
		resultBlend, blended_image = blend_images() --Check here to ensure enfuse worked properly
		if resultBlend ~= 0 then
			dt.print(_('ERROR: enfuse didn\'t work. For more information see terminal output'))
			dt.print_error("Enfuse failed")
			remove_temp_files()
			job.valid = false
			return
		end
	--Copy EXIF Data (IF)--
		if (dt.preferences.read("module_enfuseAdvanced", "exiftool_copy_tags", "bool")) then copy_exif(exif_source_file, path_with_filename) end
	--Auto-Import--
		if (dt.preferences.read("module_enfuseAdvanced", "add_image_to_db", "bool")) then 
			local imported = dt.database.import(path_with_filename)
		--Apply Selected Style (IF)--
			if enf_cmbx_style.selected > 1 then
				set_style = styles[enf_cmbx_style.selected - 1]
				dt.styles.apply(set_style , imported)
			end
		--Copy Tags (IF)--
			if (enf_chkbtn_cpytags.value) then
				all_tags = dt.tags.get_tags(dt_source_image)
				for _,tag in pairs(all_tags) do
					if string.match(tag.name, 'darktable|') == nil then
						dt.tags.attach(tag, imported)
					end
				end
			end
		--Apply Entered Tags (IF)--
			set_tag = enf_entry_tag.text
			if set_tag ~= nil then
				for tag in string.gmatch(set_tag, '[^,]+') do
					tag = string.gsub(tag, " ", "")
					tag = dt.tags.create(tag)
					dt.tags.attach(tag, imported) 
				end
			end
		end
		job.percent = job.percent + percent_step
	end
	
	--Copy EXIF Data (IF)--
	
	remove_temp_files()
	dt.print("Image fusion process complete")
	dt.print_log("enfuseAdvanced - Image fusion process complete")
	job.valid = false
end
local function support_format(enf_storage, format) --Supported: Check to make sure image type is supported by darktable
  if string.match(string.lower(format.name),"tiff") == nil then
    return false
  else
    return true
  end   
end  

-- REGISTER --
dt.register_storage(
	"module_enfuseAdvanced", --Module name
	'DRI or DFF image', --Name
	show_status, --store: called once per exported image
	create_image_fusion, --finalize: called once when all images have finished exporting
	support_format, --supported
	nil, --initialize
	enf_widget
	)

-- PREFERENCES --                
entry_widget_style = dt.new_widget("entry"){
	tooltip = "Enter the style name exactly as it is",
	text = nil,
	placeholder = "Enter Style name",
	editable = true
}
dt.preferences.register("module_enfuseAdvanced", "style",	-- name
	"string",	-- type
	'enfuseAdvanced: Defualt Style',	-- label
	'Changes DEFAULT entry in the Style option. Requires restart to take effect.',	-- tooltip
	"",	-- default
	entry_widget_style
)
entry_widget_tags = dt.new_widget("entry"){
	tooltip = "Seperate with commas, all spaces will be removed",
	text = nil,
	placeholder = "Enter default tags",
	editable = true
}
dt.preferences.register("module_enfuseAdvanced", "add_tags",	-- name
	"string",	-- type
	'enfuseAdvanced: Defualt additional tags',	-- label
	'Changes DEFAULT entry in the additional tags option. Requires restart to take effect.',	-- tooltip
	"",	-- default
	entry_widget_tags
) 
dt.preferences.register("module_enfuseAdvanced", "copy_tags",	-- name
	"bool",	-- type
	'enfuseAdvanced: Copy tags from first image by default',	-- label
	'Changes DEFAULT selection for Copy Tags, Requires restart to take effect.',	-- tooltip
	true	-- default
)
dt.preferences.register("module_enfuseAdvanced", "exiftool_copy_tags",                -- name
	"bool",                                                   -- type
	_('enfuseAdvanced: copy exif data'),                             -- label
	_('copy the exif tags from the first image to the target'),  -- tooltip
	true)                                                     -- default                       
dt.preferences.register("module_enfuseAdvanced", "add_image_to_db",                   -- name
	"bool",                                                   -- type
	_('enfuseAdvanced: add fused image to database'),                -- label
	_('add the fused image to the darktable database'),          -- tooltip
	false)                                                    -- default                              
dt.preferences.register("module_enfuseAdvanced", "align_use_gpu",                     -- name
	"bool",                                                   -- type
	_('enfuseAdvanced: use GPU for remaping'),                       -- label
	_('set the GPU remapping for image align'),                  -- tooltip
	false) 
dt.preferences.register("module_enfuseAdvanced", "compression_jpeg",   -- name
	"integer",                                 -- type
	_('enfuseAdvanced: JPEG compression'),            -- label
	_('set the compression for JPEG files'),      -- tooltip
	98,                                        -- default
	50,                                        -- min
	100)                                       -- max                     
dt.preferences.register("module_enfuseAdvanced", "compression_tiff",   -- name
	"enum",                                    -- type
	_('enfuseAdvanced: TIFF compression'),            -- label
	_('set the compression type for tiff files'), -- tooltip
	"LZW",                                     -- default
	"NONE", "DEFLATE","PACKBITS")        -- va                 
dt.preferences.register("module_enfuseAdvanced", "image_color_depth",  -- name
	"enum",                                    -- type
	_('enfuseAdvanced: image color depth (bit)'),     -- label
	_('set the output color depth'),              -- tooltip
	"16",                                      -- default
	"8","32","r32","r64")                -- values

--AIS bin location
if not AIS_path then 
	AIS_path = ""
end
local AIS_path_widget = dt.new_widget("file_chooser_button"){
	title = "Select align_image_stack[.exe] file",
	value = AIS_path,
	is_directory = false,
}
dt.preferences.register("executable_paths", "align_image_stack",	-- name
	"file",	-- type
	'enfuseAdvanced: Align Image Stack Location',	-- label
	'Install location of align_image_stack. Requires restart to take effect.',	-- tooltip
	"align_image_stack",	-- default
	AIS_path_widget
)

--enfuse bin location
if not enfuse_path then 
	enfuse_path = ""
end
local enfuse_path_widget = dt.new_widget("file_chooser_button"){
	title = "Select enfuse[.exe] file",
	value = enfuse_path,
	is_directory = false,
}
dt.preferences.register("executable_paths", "enfuse",	-- name
	"file",	-- type
	'enfuseAdvanced: enfuse Location',	-- label
	'Install location of enfuse. Requires restart to take effect.',	-- tooltip
	"enfuse",	-- default
	enfuse_path_widget
)

--exiftool bin location
if not exiftool_path then 
	exiftool_path = ""
end
local exiftool_path_widget = dt.new_widget("file_chooser_button"){
	title = "Select exiftool[.exe] file",
	value = exiftool_path,
	is_directory = false,
}
dt.preferences.register("executable_paths", "exiftool",	-- name
	"file",	-- type
	'enfuseAdvanced: exiftool Location',	-- label
	'Install location of exiftool. Requires restart to take effect.',	-- tooltip
	"exiftool",	-- default
	exiftool_path_widget
)
                       
