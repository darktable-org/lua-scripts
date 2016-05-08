lua-scripts
===========

The Lua scripts in this repository are meant to be used together with darktable. Either copy them individually to `~/.config/darktable/lua` (you might have to create that folder) or just copy/symlink the whole repository there. That allows to update all your scripts with a simple call to `git pull`.

To enable one of the scripts you have to add a line like `require "official/hello_world"` to your `~/.config/darktable/luarc` file which will enable the example script in `official/hello_world.lua` (note the lack of the `.lua` suffix).

Each script includes its own documentation and usage in its header, please refer to them.

In order to have your own scripts added here they have to be under a free license (GPL2+ will definitely work, others can be discussed). Scripts in the `official/` subfolder are maintained by the darktable community, those under `contrib/` are meant to have an "owner" who maintains them.

The available scripts are briefly desctibed subsequently. For the individual script documentation, visit the individual script files.


## Official

These scripts are maintained by the darktable project, therefore no individual maintainers are provided. Suitable places for questions and bug reports are the darktable mailing list and bug tracker and the github issues tracker.


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
*Tags: tagging*

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
*Tags: storage*

Register a new exporter that exports selected images into a single PDF file by using LaTeX. Requires a proper LaTeX installation.


### yield.lua

*Compatibility: unknown*

Some compatibility code, but for what exactly?


## Contributed

The scripts of this section are maintained by individual people, which are listed in this overview and are as well mentioned in the individual scripts (there's the more accurate information). Please try to contact the maintainers for bug reports first.


### autostyle.lua

*Compatibility: 1.x, 2.x*
*Maintainer: Marc Cousin (cousinmarc@gmail.com)*

Automatically apply a given style when an exif tag is present in the file, e.g. to apply a style to compensate for Auto-DR from some Fujifilm cameras.


### calcDistance.lua

*Compatibility: 2.x*
*Maintainer: Tobias Jakobs*
*Tags: geo*

Calculate the distance between the places where two images were taken by using the GPS metadata.


### copy_attach_detach_tags.lua

*Compatibility: 2.x, 3.x*
*Maintainer: Christian Kanzian*
*Tags: tagging*

Copy, paste, replace and remove tags from images by shortcuts and a distinct lighttable module.


### cr2hdr.lua

*Compatibility: 1.x, 2.x*
*Maintainer: Till Theato (theato@ttill.de)*
*Dependencies: cr2hdr program from Magic Lantern (http://www.magiclantern.fm/forum/index.php?topic=7139.0)*

Process images shot with Magic Lantern's Dual ISO feature for dynamic range improvement with the cr2hdr program from lighttable and import the result (with shortcut and/or on import).


### geoJSON_export.lua

*Compatibility: 2.x*
*Maintainer: Tobias Jakobs*
*Dependencies: mkdir, convert (ImageMagick), xdg-open, xdg-user-dir*
*Tags: geo*

Generate GeoJSON file from image metadata. **What exactly is exported? What is a typical use case?**


### geo_uri.lua

*Compatibility: 2.x*
*Maintainer: Tobias Jakobs*
*Dependencies: gnome-maps ≥ 3.20*
*Tags: geo*

Open a geo uri in gnome-maps. **Where is this URI found? What is a typical use case?**


### gimp.lua

*Compatibility: 2.x*
*Maintainer: Bill Ferguson (wpferguson@gmail.com)*
*Dependencies: GIMP*
*Tags: storage*

Adds new export option to lounch gimp with the selectet photo. After editing in GIMP the result is imported back into Darktable.


### gps_select.lua

*Compatibility: 1.x, 2.x*
*Maintainer: Tobias Jakobs*
*Tags: geo*

Select images with or without GPS information with shortcuts.


### hugin.lua

*Compatibility: 1.x, 2.x*
*Maintainer: Tobias Jakobs*
*Dependencies: Hugin*
*Tags: storage*

Add a new storage option to send images to hugin.


### kml_export.lua

*Compatibility: 2.x*
*Maintainer: Erik Augustin*
*Dependencies: mkdir, zip, convert (ImageMagick), xdg-open, xdg-user-dir*
*Tags: geo, storage*

Adds a new export option to export KML files. **I have no clue what it really does.**


### rate_group.lua

*Compatibility: unknown*
*Maintainer: Dom H (dom@hxy.io)*

Provide shortcuts for rating or rejecting all images within a group.


### slideshowMusic.lua

*Compatibility: 1.x, 2.x*
*Maintainer: Tobias Jakobs*
*Dependencies: rhythmbox-client*

Play music during a slide show.


### video_mencoder.lua

*Compatibility: 1.x*
*Maintainer: Tobias Jakobs*
*Dependencies: mencoder, xdg-open, xdg-user-dir*

Video export from darktable. **Some more information would be great.**


## Examples

In this category one can find useful stubs and templates for lua script development.


### api_version.lua

*Compatibility: unknown*
*Maintainer: Tobias Jakobs*

Print Darktable Lua API version.


### gettextExample.lua

*Compatibility: 2.x*
*Maintainer: Tobias Jakobs*

Example of Darktable Lua script localization.


### hello_world.lua

*Compatibility: 1.x, 2.x*
*Maintainer: Tobias Ellinghaus*

The obligatory “Hello world” example. Prints “Hello, world” on the command line.


### moduleExample.lua

*Compatibility: 2.x*
*Maintainer: Tobias Jakobs*

Template lighttable module with some GUI elements.


### preferenceExamples.lua

*Compatibility: 1.x, 2.x*
*Maintainer: Tobias Jakobs*

Examples of the different preference types that are possible with Lua within Darktable's configuration.
