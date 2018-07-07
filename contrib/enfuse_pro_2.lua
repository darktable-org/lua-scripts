--[[
  Enfuse professional plugin for darktable 2.2.X and 2.4.X

  copyright (c) 2017, 2018  Holger Klemm (Original Linux-only version)
  
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

--[[ Enfuse Pro 2 - cross-platform compatible
Modified by: Kevin Ertel
   
ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* align_image_stack
* enfuse
* exiftool

USAGE
* require this file from your main luarc config file.
* On the initial startup go to darktable settings > lua options and set your executable paths and other preferences, then restart darktable

This plugin will add the new export module "fusion to DRI or DFF image".
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local gettext = dt.gettext

-- works with LUA API version 5.0.0
dt.configuration.check_version(...,{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("enfuse_pro",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("enfuse_pro", msgid)
end

--Detect User Styles--
styles = dt.styles
styles_count = 1 -- "none" = 1
for _,i in pairs(dt.styles) do
	if type(i) == "userdata" then styles_count = styles_count + 1 end
end

-- INITS --
pref_style = dt.preferences.read("module_enfuse_pro", "style", "string")
pref_cpytags = dt.preferences.read("module_enfuse_pro", "copy_tags", "bool")
pref_addtags = dt.preferences.read("module_enfuse_pro", "add_tags", "string")
if dt.configuration.running_os == "windows" then
	os_path_seperator = "\\"
else
	os_path_seperator = "/"
end

--Ensure Required Software is Installed--
not_installed = 0
dt.print_log("enfuse_pro_2 - Executable Path Preference: "..df.get_executable_path_preference("align_image_stack"))
local AIS_path = df.check_if_bin_exists("align_image_stack")
if not AIS_path then
	dt.print_error("align image stack not found")
	dt.print("ERROR - align image stack not found")
	not_installed = 1
end

dt.print_log("enfuse_pro_2 - Executable Path Preference: "..df.get_executable_path_preference("enfuse"))
local enfuse_path = df.check_if_bin_exists("enfuse")
if not enfuse_path then
	dt.print_error("enfuse not found")
	dt.print("ERROR - enfuse not found")
	not_installed = 1
end

dt.print_log("enfuse_pro_2 - Executable Path Preference: "..df.get_executable_path_preference("exiftool"))
local exiftool_path = df.check_if_bin_exists("exiftool")
if not exiftool_path then
	dt.print_error("exiftool not found")
	dt.print("ERROR - exiftool not found")
	not_installed = 1
end
	
--Ensure proper version of Enfuse installed--
	--[[
	enfuseVersionStartCommand='enfuse --version | grep "enfuse 4.2"'
	enfuse_version=dt.control.execute(enfuseVersionStartCommand)
	if (enfuse_version ~= 0) then
		dt.print(_('ERROR: wrong enfuse version found. the plugin works only with enfuse 4.2! please install enfuse version 4.2'))
		not_installed = 1
	end]]

-- align defaults
--dt.preferences.write("enfuse_pro",  "initialized", "bool", false)
if not(dt.preferences.read("enfuse_pro",  "initialized", "bool")) then
   dt.preferences.write("enfuse_pro", "selected_fusion", "integer", 1)
   dt.preferences.write("enfuse_pro", "def_radial_distortion", "bool", false)      
   dt.preferences.write("enfuse_pro", "def_optimize_field", "bool", false) 
   dt.preferences.write("enfuse_pro", "def_optimize_image_center", "bool", true) 
   dt.preferences.write("enfuse_pro", "def_auto_crop", "bool", true) 
   dt.preferences.write("enfuse_pro", "def_distortion", "bool", true) 
   dt.preferences.write("enfuse_pro", "def_grid_size", "integer", 5)
   dt.preferences.write("enfuse_pro", "def_control_points", "integer", 8)
   dt.preferences.write("enfuse_pro", "def_control_points_remove", "integer", 3)
   dt.preferences.write("enfuse_pro", "def_correlation", "integer", 9)
   
   -- enfuse defaults
   dt.preferences.write("enfuse_pro", "def_fusion_type", "integer", 1)
   dt.preferences.write("enfuse_pro", "def_image_variants", "bool", false)
   dt.preferences.write("enfuse_pro", "def_hard_masks", "bool", false) 
   dt.preferences.write("enfuse_pro", "def_save_masks", "bool", false) 
   dt.preferences.write("enfuse_pro", "def_contrast_window_size", "integer", 3)
   dt.preferences.write("enfuse_pro", "def_contrast_edge_scale", "integer", 1)
   dt.preferences.write("enfuse_pro", "def_contrast_min_curvature", "integer", 1) 
   dt.preferences.write("enfuse_pro", "def_exposure_weight", "float", 1.0)
   dt.preferences.write("enfuse_pro", "def_saturation_weight", "float", 0.2)
   dt.preferences.write("enfuse_pro", "def_contrast_weight", "float", 0.0)
   dt.preferences.write("enfuse_pro", "def_exposure_optimum_weight", "float", 0.5)
   dt.preferences.write("enfuse_pro", "def_exposure_width_weight", "float",0.2)
   dt.preferences.write("enfuse_pro", "selected_overwrite", "integer",1)
   dt.preferences.write("enfuse_pro", "sentitiv_overwrite", "bool",true)
   
   -- preset DRI 1
	temp_text = {"dri1_","dri2_","dri3_"}
	for i,preset in pairs(temp_text) do
		dt.preferences.write("enfuse_pro", preset.."hard_masks", "bool", false) 
		dt.preferences.write("enfuse_pro", preset.."save_masks", "bool", false) 
		dt.preferences.write("enfuse_pro", preset.."contrast_window_size", "integer", 3)
		dt.preferences.write("enfuse_pro", preset.."contrast_edge_scale", "integer", 1)
		dt.preferences.write("enfuse_pro", preset.."contrast_min_curvature", "integer", 1) 
		dt.preferences.write("enfuse_pro", preset.."exposure_weight", "float", 1.0)
		dt.preferences.write("enfuse_pro", preset.."saturation_weight", "float", 0.2)
		dt.preferences.write("enfuse_pro", preset.."contrast_weight", "float", 0.0)
		dt.preferences.write("enfuse_pro", preset.."exposure_optimum_weight", "float", 0.5)
		dt.preferences.write("enfuse_pro", preset.."exposure_width_weight", "float",0.2)
	end
   
   -- preset DFF 1
   	temp_text = {"dff1_","dff2_","dff3_"}
	for i,preset in pairs(temp_text) do
		dt.preferences.write("enfuse_pro", preset.."hard_masks", "bool", true) 
		dt.preferences.write("enfuse_pro", preset.."save_masks", "bool", false) 
		dt.preferences.write("enfuse_pro", preset.."contrast_window_size", "integer", 3)
		dt.preferences.write("enfuse_pro", preset.."contrast_edge_scale", "integer", 1)
		dt.preferences.write("enfuse_pro", preset.."contrast_min_curvature", "integer", 1)  
		dt.preferences.write("enfuse_pro", preset.."exposure_weight", "float", 0.0)
		dt.preferences.write("enfuse_pro", preset.."saturation_weight", "float", 0.0)
		dt.preferences.write("enfuse_pro", preset.."contrast_weight", "float", 1.0)
		dt.preferences.write("enfuse_pro", preset.."exposure_optimum_weight", "float", 0.5)
		dt.preferences.write("enfuse_pro", preset.."exposure_width_weight", "float",0.2)
	end
   
	-- preset FREE
	dt.preferences.write("enfuse_pro", "free_hard_masks", "bool", false) 
	dt.preferences.write("enfuse_pro", "free_save_masks", "bool", false) 
	dt.preferences.write("enfuse_pro", "free_contrast_window_size", "integer", 3)
	dt.preferences.write("enfuse_pro", "free_contrast_edge_scale", "integer", 1)
	dt.preferences.write("enfuse_pro", "free_contrast_min_curvature", "integer", 1)  
	dt.preferences.write("enfuse_pro", "free_exposure_weight", "float", 0.0)
	dt.preferences.write("enfuse_pro", "free_saturation_weight", "float", 0.0)
	dt.preferences.write("enfuse_pro", "free_contrast_weight", "float", 0.0)
	dt.preferences.write("enfuse_pro", "free_exposure_optimum_weight", "float", 0.0)
	dt.preferences.write("enfuse_pro", "free_exposure_width_weight", "float",0.0)
   
   -- output
   dt.preferences.write("enfuse_pro", "selected_output_format", "integer", 1)
   dt.preferences.write("enfuse_pro",  "initialized", "bool", true) 
end

--GUI
j=0
local separator1 = dt.new_widget("separator"){}
local separator1b = dt.new_widget("separator"){}
local separator2 = dt.new_widget("separator"){}
local separator2b = dt.new_widget("separator"){}
local label_align_options= dt.new_widget("section_label"){
     label = _('image align options')
}
local label_enfuse_options= dt.new_widget("section_label"){
     label = _('image fusion options')
}
local label_output_format= dt.new_widget("section_label"){
     label = _('target file')
}
local label_path = dt.new_widget("label"){
     label = _('directory'),
     ellipsize = "start",
     halign = "start"
}
chkbtn_radial_distortion = dt.new_widget("check_button"){
	label = _('optimize radial distortion for all images'),
	value = dt.preferences.read("enfuse_pro", "def_radial_distortion", "bool"),
	tooltip = _('optimize radial distortion for all images, \nexcept for first'),
}
chkbtn_optimize_field = dt.new_widget("check_button"){
    label = _('optimize field of view for all images'), 
    value = dt.preferences.read("enfuse_pro", "def_optimize_field", "bool"),
    tooltip =_('optimize field of view for all images, except for first. \nUseful for aligning focus stacks (DFF) with slightly \ndifferent magnification.'), 
}
chkbtn_optimize_image_center = dt.new_widget("check_button"){
    label = _('optimize image center shift for all images'), 
    value = dt.preferences.read("enfuse_pro", "def_optimize_image_center", "bool"),
    tooltip =_('optimize image center shift for all images, \nexcept for first.'),   
}
chkbtn_auto_crop = dt.new_widget("check_button"){
    label = _('auto crop the image'), 
    value = dt.preferences.read("enfuse_pro", "def_auto_crop", "bool"),
    tooltip =_('auto crop the image to the area covered by all images.'),   
}
chkbtn_distortion = dt.new_widget("check_button"){
    label = _('load distortion from lens database'), 
    value = dt.preferences.read("enfuse_pro", "def_distortion", "bool"),
    tooltip =_('try to load distortion information from lens database'),   
}
chkbtn_hard_masks = dt.new_widget("check_button"){
    label = _('hard mask'), 
    value = dt.preferences.read("enfuse_pro", "def_hard_masks", "bool"),
    tooltip =_('force hard blend masks on the finest scale. this avoids \naveraging of fine details (only), at the expense \nof increasing the noise. this improves the \nsharpness of focus stacks considerably.\ndefault (soft mask)'),   
    reset_callback = function(self) 
       self.value = dt.preferences.read("enfuse_pro", "def_hard_masks", "bool")
    end
}
chkbtn_save_masks = dt.new_widget("check_button"){
    label = _('save masks'), 
    value = dt.preferences.read("enfuse_pro", "def_save_masks", "bool"),
    tooltip =_('Save the generated weight masks to your home directory,\nenblend saves masks as 8 bit grayscale, \ni.e. single channel images. \nfor accuracy we recommend to choose a lossless format.'),  
    reset_callback = function(self) 
       self.value = dt.preferences.read("enfuse_pro", "def_save_masks", "bool")
    end 
}
chkbtn_cpytags = dt.new_widget("check_button"){
    label = '  Copy Tags', 
    value = pref_cpytags,
    tooltip ='Copy tags from first image.',  
}
sldr_exposure_weight = dt.new_widget("slider"){
  label = _('exposure weight'),
  tooltip = _('set the relative weight of the well-exposedness criterion \nas defined by the chosen exposure weight function. \nincreasing this weight relative to the others will\n make well-exposed pixels contribute more to\n the final output. \ndefault: (1.0)'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse_pro", "def_exposure_weight", "float") --1 def
}
sldr_saturation_weight = dt.new_widget("slider"){
  label = _('saturation weight'),
  tooltip = _('set the relative weight of high-saturation pixels. \nincreasing this weight makes pixels with high \nsaturation contribute more to the final output. \ndefault: (0.2)'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse_pro", "def_saturation_weight", "float"), --0.5
}
sldr_contrast_weight = dt.new_widget("slider"){
  label = _('contrast weight'),
  tooltip = _('sets the relative weight of high local-contrast pixels. \ndefault: (0.0).'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse_pro", "def_contrast_weight", "float")--0 default
}
sldr_exposure_optimum_weight = dt.new_widget("slider"){
  label = _('exposure optimum'),
  tooltip = _('determine at what normalized exposure value\n the optimum exposure of the input images\n is. this is, set the position of the maximum\n of the exposure weight curve. use this \noption to fine-tune exposure weighting. \ndefault: (0.5)'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse_pro", "def_exposure_optimum_weight", "float")--0.5 default0
}
sldr_exposure_width_weight = dt.new_widget("slider"){
  label = _('exposure width'),
  tooltip = _('set the characteristic width (FWHM) of the exposure \nweight function. low numbers give less weight to \npixels that are far from the user-defined \noptimum and vice versa. use this option to \nfine-tune exposure weighting. \ndefault: (0.2)'),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse_pro", "def_exposure_width_weight", "float") --0.2 default
}
file_chooser_button_path = dt.new_widget("file_chooser_button"){
    title = _('Select export path'),  -- The title of the window when choosing a file
    is_directory = true,             -- True if the file chooser button only allows directories to be selecte
    tooltip =_('select the target directory for the fused image. \nthe filename is created automatically.'),
}
chkbtn_source_location = dt.new_widget("check_button"){
    label = _('save to source image location'), 
    value = true,
    tooltip =_('If checked ignores the location below and saves output image(s) to the same location as the source images.'),  
	reset_callback = function(self) 
       self.value = true
    end 
}
cmbx_grid_size = dt.new_widget("combobox"){
    label = _('image grid size'), 
    tooltip =_('break image into a rectangular grid \nand attempt to find num control points in each section.\ndefault: (5x5)'),
    value = dt.preferences.read("enfuse_pro", "def_grid_size", "integer"), --5
    "1", "2", "3","4","5","6","7","8","9",
    reset_callback = function(self)
       self.value = dt.preferences.read("enfuse_pro", "def_grid_size", "integer")
    end
} 
cmbx_control_points = dt.new_widget("combobox"){
    label = _('control points/grid'), 
    tooltip =_('number of control points (per grid, see option -g) \nto create between adjacent images \ndefault: (8).'),
    value = dt.preferences.read("enfuse_pro", "def_control_points", "integer"),   --8, "1", "2", "3","4","5","6","7","8","9",
    "1", "2", "3","4","5","6","7","8","9",             
    reset_callback = function(self)
       self.value = dt.preferences.read("enfuse_pro", "def_control_points", "integer")
    end
} 
cmbx_control_points_remove = dt.new_widget("combobox"){
    label = _('remove control points with error'), 
    tooltip =_('remove all control points with an error higher \nthan num pixels \ndefault: (3)'),
    value = dt.preferences.read("enfuse_pro", "def_control_points_remove", "integer"), --3, "1", "2", "3","4","5","6","7","8","9",
    "1", "2", "3","4","5","6","7","8","9",              
    reset_callback = function(self)
       self.value = dt.preferences.read("enfuse_pro", "def_control_points_remove", "integer")
    end
} 
cmbx_correlation  = dt.new_widget("combobox"){
    label = _('correlation threshold for control points'), 
    tooltip =_('correlation threshold for identifying \ncontrol points \ndefault: (0.9).'),
    value = dt.preferences.read("enfuse_pro", "def_correlation", "integer"), --9, "0,1", "0,2", "0,3","0,4","0,5","0,6","0,7","0,8","0,9",
    "0.1", "0.2", "0.3","0.4","0.5","0.6","0.7","0.8","0.9","1.0",     
    reset_callback = function(self)
       self.value = dt.preferences.read("enfuse_pro", "def_correlation", "integer")
    end
} 
cmbx_contrast_window_size = dt.new_widget("combobox"){
    label = _('contrast window size'), 
    tooltip =_('set the window size for local contrast analysis. \nthe window will be a square of size × size pixels. \nif given an even size, Enfuse will \nautomatically use the next odd number.\nfor contrast analysis size values larger \nthan 5 pixels might result in a \nblurry composite image. values of 3 and \n5 pixels have given good results on \nfocus stacks. \ndefault: (5) pixels'),
    value = dt.preferences.read("enfuse_pro", "def_contrast_window_size", "integer"), --3, "3","4","5","6","7","8","9","10",
    "3", "4", "5","6","7","8","9","10",   
} 
cmbx_contrast_edge_scale = dt.new_widget("combobox"){
    label = _('contrast edge scale'), 
    tooltip =_('a non-zero value for EDGE-SCALE switches on the \nLaplacian-of-Gaussian (LoG) edge detection algorithm.\n edage-scale is the radius of the Gaussian used \nin the search for edges. a positive LCE-SCALE \nturns on local contrast enhancement (LCE) \nbefore the LoG edge detection. \nDefault: (0.0) pixels.'),
    value = dt.preferences.read("enfuse_pro", "def_contrast_edge_scale", "integer"), --1, "0:0:0",
    "0.0","0.1","0.2","0.3","0.4","0.5",

}  
cmbx_contrast_min_curvature = dt.new_widget("combobox"){
    label = _('contrast min curvature'),
    tooltip =_('define the minimum curvature for the LoG edge detection. Append a ‘%’ to specify the minimum curvature relative to maximum pixel value in the source image. Default: (0.0%)'),
    value = dt.preferences.read("enfuse_pro", "def_contrast_min_curvature", "integer"), --1, "0.0%","0.1%", "0.2%", "0.3%","0.4%","0.5%","0.6%","0.7%","0.8%","0.9%","1.0%", 
    "0.0%", "0.1%", "0.2%","0.3%","0.4%","0.5%","0.6%","0.7%","0.8%","0.9%","1.0%",   
}  
cmbx_existing_file = dt.new_widget("combobox"){
    label = _('on conflict'), 
    value = dt.preferences.read("enfuse_pro", "selected_overwrite", "integer"), --1, 
    sensitive= dt.preferences.read("enfuse_pro", "sentitiv_overwrite", "bool"), --1, 
    _('create unique filename'),_('overwrite'),           
    reset_callback = function(self)
       self.value = dt.preferences.read("enfuse_pro", "selected_overwrite", "integer")
    end
}  
cmbx_style = dt.new_widget("combobox"){
	label = "Apply Style on Import",
	tooltip = "Apply selected style on auto-import to newly created blended image",
	value = 1,
	"none",
	}
pref_style_enum = 1
for k=1, (styles_count-1) do
	cmbx_style[k+1] = styles[k].name
	if styles[k].name == pref_style then pref_style_enum = k+1 end
end
cmbx_style.value = pref_style_enum
chkbtn_image_variations = dt.new_widget("check_button"){
    label = _('create image variants with saved presets'), 
    value = dt.preferences.read("enfuse_pro", "def_image_variants", "bool"),
    tooltip =_('creates image variants with the three \nsaved DRI or DFF presets'),   
    sensitive=true,
    clicked_callback = function(self) 
		if (self.value) then
			dt.preferences.write("enfuse_pro", "def_image_variants", "bool", true)
			dt.preferences.write("enfuse_pro", "sentitiv_overwrite", "bool",false)
			cmbx_existing_file.value=1
			cmbx_existing_file.sensitive=false
		else  
		   dt.preferences.write("enfuse_pro", "def_image_variants", "bool", false)
		   dt.preferences.write("enfuse_pro", "sentitiv_overwrite", "bool",true)
		   cmbx_existing_file.sensitive=true 
		end    
    end,
    reset_callback = function(self) 
       dt.preferences.write("enfuse_pro", "def_image_variants", "bool", false)
       dt.preferences.write("enfuse_pro", "sentitiv_overwrite", "bool",true)
       self.value = false
       cmbx_existing_file.sensitive=true
    end

}
button_save_preset = dt.new_widget("button"){
	label = _('save fusion preset'),
	tooltip =_('save the selected fusion preset'),
	clicked_callback = function() 
		pref_text = ""
		if (cmbx_fusion_type.value == "1 - DRI image") then
			pref_text = "dri1_"
		elseif (cmbx_fusion_type.value == "2 - DRI image") then
			pref_text = "dri2_"
		elseif (cmbx_fusion_type.value == "3 - DRI image") then
			pref_text = "dri3_"
		elseif (cmbx_fusion_type.value == "1 - DFF image") then
			pref_text = "dff1_"
		elseif (cmbx_fusion_type.value == "2 - DFF image") then
			pref_text = "dff2_"
		elseif (cmbx_fusion_type.value == "3 - DFF image") then
			pref_text = "dff3_"
		elseif (cmbx_fusion_type.value == "free preset") then
			pref_text = "free_"
		else
			dt.print(_('unkown error'))
		end
		-- Write Preset
		if pref_text ~= "" then
			dt.preferences.write("enfuse_pro", pref_text.."hard_masks", "bool", chkbtn_hard_masks.value) 
			dt.preferences.write("enfuse_pro", pref_text.."save_masks", "bool", chkbtn_save_masks.value) 
			dt.preferences.write("enfuse_pro", pref_text.."contrast_window_size", "integer", cmbx_contrast_window_size.selected)
			dt.preferences.write("enfuse_pro", pref_text.."contrast_edge_scale", "integer", cmbx_contrast_edge_scale.selected)
			dt.preferences.write("enfuse_pro", pref_text.."contrast_min_curvature", "integer", cmbx_contrast_min_curvature.selected) 
			dt.preferences.write("enfuse_pro", pref_text.."exposure_weight", "float", sldr_exposure_weight.value)
			dt.preferences.write("enfuse_pro", pref_text.."saturation_weight", "float", sldr_saturation_weight.value)
			dt.preferences.write("enfuse_pro", pref_text.."contrast_weight", "float", sldr_contrast_weight.value)
			dt.preferences.write("enfuse_pro", pref_text.."exposure_optimum_weight", "float", sldr_exposure_optimum_weight.value)
			dt.preferences.write("enfuse_pro", pref_text.."exposure_width_weight", "float",sldr_exposure_width_weight.value)
			dt.print(_('preset '..pref_text..' saved')) 
		end
	end
}
button_load_preset = dt.new_widget("button"){
      label = _('load fusion defaults'),
      tooltip =_('load the default fusion settings'),
      clicked_callback = function() 
        chkbtn_hard_masks.value=dt.preferences.read("enfuse_pro", "def_hard_masks", "bool") 
        chkbtn_save_masks.value=dt.preferences.read("enfuse_pro", "def_save_masks", "bool") 
        cmbx_contrast_window_size.value=dt.preferences.read("enfuse_pro", "def_contrast_window_size", "integer")
        cmbx_contrast_edge_scale.value=dt.preferences.read("enfuse_pro", "def_contrast_edge_scale", "integer")
        cmbx_contrast_min_curvature.value=dt.preferences.read("enfuse_pro", "def_contrast_min_curvature", "integer")
        sldr_exposure_weight.value=dt.preferences.read("enfuse_pro", "def_exposure_weight", "float")
        sldr_saturation_weight.value=dt.preferences.read("enfuse_pro", "def_saturation_weight", "float")
        sldr_contrast_weight.value=dt.preferences.read("enfuse_pro", "def_contrast_weight", "float")
        sldr_exposure_optimum_weight.value=dt.preferences.read("enfuse_pro", "def_exposure_optimum_weight", "float")
        sldr_exposure_width_weight.value=dt.preferences.read("enfuse_pro", "def_exposure_width_weight", "float")
     end
      
}
cmbx_output_format = dt.new_widget("combobox"){
    label = _('file format'), 
    value = dt.preferences.read("enfuse_pro", "selected_output_format", "integer"), --1, "TIFF", "JPEG", "PNG","PNM","PBM","PGM","PPM",
    changed_callback = function(self) 
      dt.preferences.write("enfuse_pro", "selected_output_format", "integer", self.selected)
    end,
    "TIFF", "JPEG", "PNG","PNM","PBM","PPM",            
    reset_callback = function(self)
       self.value = dt.preferences.read("enfuse_pro", "selected_output_format", "integer")
    end
}  
cmbx_fusion_type = dt.new_widget("combobox"){
    label = _('fusion preset'), 
    tooltip =_('select the preset and save the preset\n if you want to reuse it or create an image\n variant'),
    value = 1, --dt.preferences.read("enfuse_pro", "def_fusion_type", "integer"), --1, "DRI image", "DFF image", "without preset",
    changed_callback = function(self) 
		dt.preferences.write("enfuse_pro", "def_fusion_type", "integer", self.selected)

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
			chkbtn_hard_masks.sensitive=false
			chkbtn_hard_masks.value=false
			sldr_contrast_weight.sensitive=true
		elseif string.match(pref_text,"^dff")~=nil then
			chkbtn_hard_masks.sensitive=false
			chkbtn_hard_masks.value=true
			sldr_contrast_weight.sensitive=false
		else
			chkbtn_hard_masks.sensitive=true
			chkbtn_hard_masks.value=false
			sldr_contrast_weight.sensitive=true
		end
		
        chkbtn_hard_masks.value=dt.preferences.read("enfuse_pro", pref_text.."hard_masks", "bool") 
        chkbtn_save_masks.value=dt.preferences.read("enfuse_pro", pref_text.."save_masks", "bool") 
        cmbx_contrast_window_size.value=dt.preferences.read("enfuse_pro", pref_text.."contrast_window_size", "integer")
        cmbx_contrast_edge_scale.value=dt.preferences.read("enfuse_pro", pref_text.."contrast_edge_scale", "integer")
        cmbx_contrast_min_curvature.value=dt.preferences.read("enfuse_pro", pref_text.."contrast_min_curvature", "integer") 
        sldr_exposure_weight.value=dt.preferences.read("enfuse_pro", pref_text.."exposure_weight", "float")
        sldr_saturation_weight.value=dt.preferences.read("enfuse_pro", pref_text.."saturation_weight", "float")
        sldr_contrast_weight.value=dt.preferences.read("enfuse_pro", pref_text.."contrast_weight", "float")
        sldr_exposure_optimum_weight.value=dt.preferences.read("enfuse_pro", pref_text.."exposure_optimum_weight", "float")
        sldr_exposure_width_weight.value=dt.preferences.read("enfuse_pro", pref_text.."exposure_width_weight", "float")   
	
    end,
    "1 - DRI image", "2 - DRI image","3 - DRI image","1 - DFF image", "2 - DFF image","3 - DFF image","free preset",  
    
    reset_callback = function(self_type)
       cmbx_fusion_type.value = dt.preferences.read("enfuse_pro", "def_fusion_type", "integer")
    end
} 
entry_tag = dt.new_widget("entry"){
	tooltip = "Additional tags to be added on import. Seperate with commas, all spaces will be removed",
	text = pref_addtags,
	placeholder = "Enter tags, seperated by commas",
	editable = true
}
local widget = dt.new_widget("box") {
    orientation = "vertical",
    label_align_options,
    chkbtn_radial_distortion,
    chkbtn_optimize_field,
    chkbtn_optimize_image_center,
    chkbtn_auto_crop,
    chkbtn_distortion,
    cmbx_grid_size,
    cmbx_control_points,
    cmbx_control_points_remove,
    cmbx_correlation,
    separator1,
    separator1b,
    label_enfuse_options,
    cmbx_fusion_type,
    chkbtn_image_variations,
    sldr_exposure_weight,
    sldr_saturation_weight,
    sldr_contrast_weight,
    sldr_exposure_optimum_weight,
    sldr_exposure_width_weight, 
    chkbtn_hard_masks,
    chkbtn_save_masks,
    cmbx_contrast_edge_scale,
    cmbx_contrast_min_curvature,
    cmbx_contrast_window_size,
    button_save_preset,
    button_load_preset,
    separator2,
    separator2b,
    label_output_format,
    cmbx_output_format,
    label_path,
    file_chooser_button_path,
	chkbtn_source_location,
    cmbx_existing_file,
	cmbx_style,
	chkbtn_cpytags,
	entry_tag,
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
		dt.print_log("Deleting temp files...")
		dt.control.execute("del "..images_to_align)
		dt.control.execute("del "..images_to_blend)
		dt.print_log("Done deleting")
	else
		dt.print_log("Deleting temp files...")
		dt.control.execute("rm "..images_to_align)
		dt.control.execute("rm "..images_to_blend)
		dt.print_log("Done deleting")
	end
end
local function build_execute_command(cmd, args, file_list)
	local result = false

	if dt.configuration.running_os == "macos" then
		cmd = string.gsub(cmd, "open", "")
		cmd = string.gsub(cmd, "-W", "")
		cmd = string.gsub(cmd, "-a", "")
	end
	result = cmd.." "..args.." "..file_list
	return result
end
function copy_exif()
	exiftool_path = string.gsub(exiftool_path, "open", "")
	exiftool_path = string.gsub(exiftool_path, "-W", "")
	exiftool_path = string.gsub(exiftool_path, "-a", "")
	if dt.configuration.running_os == "windows" then
		exifStartCommand = exiftool_path.." -TagsFromFile "..source_file.." -exif:all --subifd:all -overwrite_original "..path_with_filename
	else
		exifStartCommand = exiftool_path.." -TagsFromFile "..'"'..source_file..'"'.." -exif:all --subifd:all -overwrite_original "..'"'..path_with_filename..'"'
	end
	dt.print_log("EXIFTool Start Command: "..exifStartCommand)
	resultexif=dt.control.execute(exifStartCommand)
	if (resultexif == 0) then
		dt.print_log("EXIFTool copy successful")
		dt.print("Copied EXIF data")
	else
		dt.print(_('ERROR: exiftool doesn\'t work. for more informations see terminal output'))
		dt.print_error("exif copy failed")
	end
end
function align_images()
	dt.print(_('aligning images'))
	
	--Setup Align Image Stack Arguments--
	align_args = ""
	if (chkbtn_radial_distortion.value) then align_args = align_args.." -d" end
	if (chkbtn_optimize_field.value) then align_args = align_args.." -m" end  
	if (chkbtn_optimize_image_center.value) then align_args = align_args.." -i" end
	if (chkbtn_auto_crop.value) then align_args = align_args.." -C" end     
	if (chkbtn_distortion.value) then align_args = align_args.." --distortion" end
	align_args = align_args.." -g "..cmbx_grid_size.value
	align_args = align_args.." -c "..cmbx_control_points.value          
	align_args = align_args.." -t "..cmbx_control_points_remove.value
	align_args = align_args.." --corr="..cmbx_correlation.value
	if (dt.preferences.read("module_enfuse_pro", "align_use_gpu", "bool")) then align_args = align_args.." --gpu" end
	if dt.configuration.running_os == "windows" then
		align_args = align_args.." -a "..first_path.."aligned_ "
	else
		align_args = align_args.." -a "..'"'..first_path..'aligned_" '
	end
	alignStartCommand = build_execute_command(AIS_path, align_args, images_to_align)
	dt.print_log("Align Start Command: "..alignStartCommand)
	resp = dt.control.execute(alignStartCommand)
	dt.print_log("Completed Align")
	return resp
end
function blend_images()
	blend_args = ""
	if from_preset then --load args from preset preferences
		blend_args=blend_args.." --exposure-weight="..(replace_comma_to_dot(dt.preferences.read("enfuse_pro", preset_text.."_exposure_weight", "float")))
		blend_args=blend_args.." --saturation-weight="..(replace_comma_to_dot(dt.preferences.read("enfuse_pro", preset_text.."_saturation_weight", "float"))) 
		blend_args=blend_args.." --contrast-weight="..(replace_comma_to_dot(dt.preferences.read("enfuse_pro", preset_text.."_contrast_weight", "float")))
		blend_args=blend_args.." --exposure-optimum="..(replace_comma_to_dot(dt.preferences.read("enfuse_pro", preset_text.."_exposure_optimum_weight", "float")))
		blend_args=blend_args.." --exposure-width="..(replace_comma_to_dot(dt.preferences.read("enfuse_pro", preset_text.."_exposure_width_weight", "float")))
		if (chkbtn_hard_masks.value) then blend_args=blend_args.."--hard-mask" end
		if (chkbtn_save_masks.value) then blend_args=blend_args.."--save-masks" end
		blend_args=blend_args.." --contrast-window-size="..dt.preferences.read("enfuse_pro", preset_text.."_contrast_window_size", "integer")
		blend_args=blend_args.." --contrast-edge-scale="..dt.preferences.read("enfuse_pro", preset_text.."_contrast_edge_scale", "integer")
		blend_args=blend_args.." --contrast-min-curvature="..dt.preferences.read("enfuse_pro", preset_text.."_contrast_min_curvature", "integer")
		blend_args=blend_args.." --depth="..dt.preferences.read("module_enfuse_pro", "image_color_depth", "enum")
	else --load args from GUI values
		blend_args = blend_args.." --exposure-weight="..(replace_comma_to_dot(sldr_exposure_weight.value))
		blend_args = blend_args.." --saturation-weight="..(replace_comma_to_dot(sldr_saturation_weight.value))            
		blend_args = blend_args.." --contrast-weight="..(replace_comma_to_dot(sldr_contrast_weight.value))
		blend_args = blend_args.." --exposure-optimum="..(replace_comma_to_dot(sldr_exposure_optimum_weight.value))
		blend_args = blend_args.." --exposure-width="..(replace_comma_to_dot(sldr_exposure_width_weight.value))
		if (chkbtn_hard_masks.value) then blend_args = blend_args.." --hard-mask" end
		if (chkbtn_save_masks.value) then blend_args = blend_args.." --save-masks" end
		blend_args = blend_args.." --contrast-window-size="..cmbx_contrast_window_size.value
		blend_args = blend_args.." --contrast-edge-scale="..cmbx_contrast_edge_scale.value
		blend_args = blend_args.." --contrast-min-curvature="..cmbx_contrast_min_curvature.value
		blend_args = blend_args.." --depth="..dt.preferences.read("module_enfuse_pro", "image_color_depth", "enum")
	end
	
	--set output format per GUI selection
	if (cmbx_output_format.value == "TIFF") then
		cmd_suffix_output_format="tif"
		blend_args = blend_args.." --compression="..dt.preferences.read("module_enfuse_pro", "compression_tiff", "enum")
	elseif (cmbx_output_format.value == "JPEG") then
		cmd_suffix_output_format="jpg"
		blend_args = blend_args.." --compression="..truncate(dt.preferences.read("module_enfuse_pro", "compression_jpeg", "integer"))
	elseif (cmbx_output_format.value == "PNG") then
		cmd_suffix_output_format="png"
	elseif (cmbx_output_format.value == "PNM") then
		cmd_suffix_output_format="pnm"     
	elseif (cmbx_output_format.value == "PBM") then
		cmd_suffix_output_format="pbm"   
	elseif (cmbx_output_format.value == "PPM") then
		cmd_suffix_output_format="ppm"
	end

	--Set output path and add filename
	if (chkbtn_source_location.value) then
		cmd_output_path = source_path
	else
	cmd_output_path=file_chooser_button_path.value 
	end
	path_with_filename = cmd_output_path..os_path_seperator..first_filename.."-"..last_id.."."..cmd_suffix_output_format
	
	--Create unique name with index if GUI selection create unique name (don't overwrite), also do this if user selected to make variants from presets
	if (cmbx_existing_file.selected == 1) or (from_preset) then
		path_with_filename = df.create_unique_filename(path_with_filename)
	end
	
	if dt.configuration.running_os == "windows" then
		cmd_output_image = " --output="..path_with_filename
	else
		cmd_output_image = " --output="..'"'..path_with_filename..'"'
		
	end
	blend_args = blend_args..cmd_output_image

	images_to_blend = ""
	for j=0, counted_images-1 do
		if j < 10 then
			id = "000"..tostring(j)
		else
			id = "00"..tostring(j)
		end
		if dt.configuration.running_os == "windows" then
			images_to_blend = images_to_blend..first_path.."aligned_"..id..".tif "
		else
			images_to_blend = images_to_blend..'"'..first_path.."aligned_"..id..".tif"..'" '
		end
	end
	BlendStartCommand=build_execute_command(enfuse_path, blend_args, images_to_blend)
	
	dt.print_log("Blend Start Command: "..BlendStartCommand)
	resultBlend=dt.control.execute(BlendStartCommand)
	dt.print_log("Completed Blend")

	return resultBlend, path_with_filename
end
local function show_status(storage, image, format, filename, --Store: Called on each exported image
  number, total, high_quality, extra_data)
     dt.print(_('export TIFF for image fusion ')..tostring(truncate(number)).." / "..tostring(truncate(total)))   
end
function create_image_fusion(storage, image_table, extra_data) --Finalize: Called once when all images are done exporting	
--Create Images String--
	images_to_align = ""
	images_to_blend = ""
	counted_images=0
	first_id = "999999999999999999999999"
	last_id = "0"
	for source_image,image_path in pairs(image_table) do
		counted_images=counted_images+1
		if dt.configuration.running_os == "windows" then
			images_to_align = images_to_align..image_path..' '
		else
			images_to_align = images_to_align..'"'..image_path..'" '
		end
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
		source_path = source_image.path
		source_file = source_image.path..os_path_seperator..source_image.filename
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
		dt.print_log("Required software not installed")
		dt.print("Required software not installed")
		remove_temp_files()
		return
	end	

--Check that output path selected
	cmd_output_path = file_chooser_button_path.value
	if (cmd_output_path == nil) and not(chkbtn_source_location.value) then
		dt.print(_('ERROR: no target directory selected'))
		remove_temp_files()
		return
	end

	dt.print_log("Starting Image Fusion")
	job = dt.gui.create_job(_('Creating DRI/DFF image'), true, stop_selection)
	
	percent_step = .33
	if (chkbtn_image_variations.value) then percent_step = .2 end
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
	if (chkbtn_image_variations.value) then
		iterations = 3
		from_preset = true
		if string.match(cmbx_fusion_type.value, "DRI") then 
			pref_text = "dri"
		elseif string.match(cmbx_fusion_type.value, "DFF") then 
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
		if (dt.preferences.read("module_enfuse_pro", "exiftool_copy_tags", "bool")) then copy_exif() end
	--Auto-Import--
		if (dt.preferences.read("module_enfuse_pro", "add_image_to_db", "bool")) then 
			local imported = dt.database.import(path_with_filename)
		--Apply Selected Style (IF)--
			if cmbx_style.selected > 1 then
				set_style = styles[cmbx_style.selected - 1]
				dt.styles.apply(set_style , imported)
			end
		--Copy Tags (IF)--
			if (chkbtn_cpytags.value) then
				all_tags = dt.tags.get_tags(dt_source_image)
				for _,tag in pairs(all_tags) do
					if string.match(tag.name, 'darktable|') == nil then
						dt.tags.attach(tag, imported)
					end
				end
			end
		--Apply Entered Tags (IF)--
			set_tag = entry_tag.text
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
	dt.print_log("Image fusion process complete")
	job.valid = false
end
local function support_format(storage, format) --Supported: Check to make sure image type is supported by darktable
  fmt = string.lower(format.name)
  if string.match(fmt,"tiff") == nil then
    return false
  else
    return true
  end   
end  

-- REGISTER --
dt.register_storage("module_enfuse_pro", _('DRI or DFF image'), show_status, create_image_fusion, support_format, nil, widget)

-- PREFERENCES --                
entry_widget_style = dt.new_widget("entry"){
	tooltip = "Enter the style name exactly as it is",
	text = nil,
	placeholder = "Enter Style name",
	editable = true
}
dt.preferences.register("module_enfuse_pro", "style",	-- name
	"string",	-- type
	'enfuse_pro: Defualt Style',	-- label
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
dt.preferences.register("module_enfuse_pro", "add_tags",	-- name
	"string",	-- type
	'enfuse_pro: Defualt additional tags',	-- label
	'Changes DEFAULT entry in the additional tags option. Requires restart to take effect.',	-- tooltip
	"",	-- default
	entry_widget_tags
) 
dt.preferences.register("module_enfuse_pro", "copy_tags",	-- name
	"bool",	-- type
	'enfuse_pro: Copy tags from first image by default',	-- label
	'Changes DEFAULT selection for Copy Tags, Requires restart to take effect.',	-- tooltip
	true	-- default
)
dt.preferences.register("module_enfuse_pro", "exiftool_copy_tags",                -- name
	"bool",                                                   -- type
	_('enfuse pro: copy exif data'),                             -- label
	_('copy the exif tags from the first image to the target'),  -- tooltip
	true)                                                     -- default                       
dt.preferences.register("module_enfuse_pro", "add_image_to_db",                   -- name
	"bool",                                                   -- type
	_('enfuse pro: add fused image to database'),                -- label
	_('add the fused image to the darktable database'),          -- tooltip
	false)                                                    -- default                              
dt.preferences.register("module_enfuse_pro", "align_use_gpu",                     -- name
	"bool",                                                   -- type
	_('enfuse pro: use GPU for remaping'),                       -- label
	_('set the GPU remapping for image align'),                  -- tooltip
	false) 
dt.preferences.register("module_enfuse_pro", "compression_jpeg",   -- name
	"integer",                                 -- type
	_('enfuse pro: JPEG compression'),            -- label
	_('set the compression for JPEG files'),      -- tooltip
	98,                                        -- default
	50,                                        -- min
	100)                                       -- max                     
dt.preferences.register("module_enfuse_pro", "compression_tiff",   -- name
	"enum",                                    -- type
	_('enfuse pro: TIFF compression'),            -- label
	_('set the compression type for tiff files'), -- tooltip
	"LZW",                                     -- default
	"NONE", "DEFLATE","PACKBITS")        -- va                 
dt.preferences.register("module_enfuse_pro", "image_color_depth",  -- name
	"enum",                                    -- type
	_('enfuse pro: image color depth (bit)'),     -- label
	_('set the output color depth'),              -- tooltip
	"16",                                      -- default
	"8","32","r32","r64")                -- values

--AIS bin location
if not AIS_path then 
	AIS_path = ""
end
AIS_path_widget = dt.new_widget("file_chooser_button"){
	title = "Select align_image_stack[.exe] file",
	value = AIS_path,
	is_directory = false,
}
dt.preferences.register("executable_paths", "align_image_stack",	-- name
	"file",	-- type
	'enfuse_pro: Align Image Stack Location',	-- label
	'Install location of align_image_stack. Requires restart to take effect.',	-- tooltip
	"align_image_stack",	-- default
	AIS_path_widget
)

--enfuse bin location
if not enfuse_path then 
	enfuse_path = ""
end
enfuse_path_widget = dt.new_widget("file_chooser_button"){
	title = "Select enfuse[.exe] file",
	value = enfuse_path,
	is_directory = false,
}
dt.preferences.register("executable_paths", "enfuse",	-- name
	"file",	-- type
	'enfuse_pro: enfuse Location',	-- label
	'Install location of enfuse. Requires restart to take effect.',	-- tooltip
	"enfuse",	-- default
	enfuse_path_widget
)

--exiftool bin location
if not exiftool_path then 
	exiftool_path = ""
end
exiftool_path_widget = dt.new_widget("file_chooser_button"){
	title = "Select exiftool[.exe] file",
	value = exiftool_path,
	is_directory = false,
}
dt.preferences.register("executable_paths", "exiftool",	-- name
	"file",	-- type
	'enfuse_pro: exiftool Location',	-- label
	'Install location of exiftool. Requires restart to take effect.',	-- tooltip
	"exiftool",	-- default
	exiftool_path_widget
)
                       
