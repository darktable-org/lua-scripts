lua-scripts
===========

The Lua scripts in this repository are meant to be used together with darktable. Either copy them individually to `~/.config/darktable/lua` (you might have to create that folder) or just copy/symlink the whole repository there. That allows to update all your scripts with a simple call to `git pull`.

To enable one of the scripts you have to add a line like `require "official/hello_world"` to your `~/.config/darktable/luarc` file which will enable the example script in `official/hello_world.lua` (note the lack of the `.lua` suffix).

Each script includes its own documentation and usage in its header, please refer to them.

In order to have your own scripts added here they have to be under a free license (GPL2+ will definitely work, others can be discussed). Scripts in the `official/` subfolder are maintained by the darktable community, those under `contrib/` are meant to have an "owner" who maintains them.

The available scripts are briefly desctibed subsequently. For the individual script documentation, visit the individual script files.


## Official

### check_for_updates.lua

*Compatibility: 1.x, 2.x*

Automatically look for newer releases on github and inform
when there is something. It will only check on startup and only once a week.

### copy_paste_metadata.lua

*Compatibility: 2.x*

Copy metadata (title, description, …), rating, colour labels and tags between images by keyboard shortcut or by buttons in the “selected images” lighttable module.

### debug-helpers.lua

*Compatibility: unknown*

A collection of helper functions to help debugging lua scripts.

### delete_long_tags.lua

*Compatibility: 1.x, 2.x*

Automatically delete all tags longer than a given length.

### enfuse.lua

*Compatibility: 2.x*

Run enfuse on selected images to merge them into a HDR and make the HDR available in Darktable. Does not work with raw files, only formats understood by enfuse are possible (e.g., jpeg).

### generate_image_txt.lua

*Compatibility: >1.2.x, 2.x*

Run a custom command on images to generate text metadata. This data is stored in a text sidecar file and can be overlaid over the image by darktable.

### image_path_in_ui.lua

*Compatibility: 1.x, 2.x*

Add a widget with the paths of all selected images for easy copy/paste.

### import_filter_manager.lua

*Compatibility: unknown*

Adds a dropdown list with import filters to the import dialog. Several import filters can plug into the manager. This allows customized import schemes such as “prefer raw over jpeg” where a jpeg is only added if no corresponding raw file exists. Requires suitable filters, an example set is implemented in “import_filters.lua”.

### import_filters.lua

*Compatibility: unknown*

Implements suitable import filters to be used with “import_filter_manager.lua”. Two filters are available, one that resembles the “ignore jpeg” functionality of darktable's import dialog and one that implements the “prefer raw over jpeg” strategy explained in the import_filter_manager.lua description.

### save_selection.lua

*Compatibility: 1.x, 2.x*

Provides shortcuts to save selections to and restore them from up to five temporary buffers.

### selection_to_pdf.lua

*Compatibility: 1.x, 2.x*

Register a new exporter that exports selected images into a single PDF file by using LaTeX. Requires a proper LaTeX installation.

### yield.lua

*Compatibility: unknown*

Some compatibility code, but for what exactly?
