# Lua scripts

## Description

darktable can be customized and extended using the Lua programming language. This repository contains the collected
efforts of the darktable developers, maintainers, contributors and community. The following sections list the scripts
contained in the repository, whether they can be run by themselves (Standalone - Yes) or depend on other
scripts (Standalone - No), what operating systems they are known to work on (L - Linux, M - MacOS, W - Windows), and their purpose.

### Official Scripts

These scripts are written primarily by the darktable developers and maintained by the authors and/or repository maintainers. They are located in the official/ directory.

Name|Standalone|OS   |Purpose
----|:--------:|:---:|-------
check_for_updates|Yes|LMW|Check for updates to darktable
copy_paste_metadata|Yes|LMW|Copy and paste metadata, tags, ratings, and color labels between images
delete_long_tags|Yes|LMW|Delete all tags longer than a specified length
delete_unused_tags|Yes|LMW|Delete tags that have no associated images
enfuse|No|L|Exposure blend several images (HDR)
generate_image_txt|No|L|Generate txt sidecar files to be overlaid on zoomed images
image_path_in_ui|Yes|LMW|Plugin to display selected image path
import_filter_manager|Yes|LMW|Manager for import filters
import_filters|No|LMW|Two import filters for use with import_filter_manager
save_selection|Yes|LMW|Provide save and restore from multiple selection buffers
selection_to_pdf|No|L|Generate a PDF file from the selected images


### Contributed Scripts

These scripts are contributed by users. They are meant to have an "owner", i.e. the author, who maintains them. Over time the community has helped maintain these scripts, as well as the authors. They are located in the contrib/ directory.

Name|Standalone|OS   |Purpose
----|:--------:|:---:|-------
autostyle|Yes|LMW|Automatically apply styles on import
clear_GPS|Yes|LMW|Reset GPS information for selected images
copy_attach_detach_tags|Yes|LMW|Copy and paste tags from/to images
cr2hdr|Yes|L|Process image created with Magic Lantern Dual ISO
fujifilm_ratings|No|LM|Support importing Fujifilm ratings
geoJSON_export|No|L|Create a geo JSON script with thumbnails for use in ...
geoToolbox|No|LMW|A toolbox of geo functions
gimp|No|LMW|Open an image in GIMP for editing and return the result
gpx_export|No|LMW|Export a GPX track file from selected images GPS data
hugin|No|LMW|Combine selected images into a panorama and return the result
kml_export|No|L|Export photos with a KML file for usage in Google Earth
LabelsToTags|?|LMW|Apply tags based on color labels and ratings
passport_guide|Yes|LMW|Add passport cropping guide to darkroom crop tool
pdf_slideshow|No|LM|Export images to a PDF slideshow
quicktag|Yes|LMW|Create shortcuts for quickly applying tags
rate_group|Yes|LMW|Apply or remove a star rating from grouped images
rename-tags|Yes|LMW|Change a tag name
select_untagged|Yes|LMW|Enable selection of untagged images
slideshowMusic|No|L|Play music during a slideshow
video_mencoder|No|L|Export video from darktable

### Example Scripts

These scripts provide examples of how to use specific portions of the API. They run, but are meant for demonstrattion purposes only. They are located in the examples/ directory.

Name|Standalone|OS   |Purpose
----|:--------:|:---:|-------
api_version|Yes|LMW|Print the current API version
gettextExample|Yes|LM|How to use translation
hello_world|Yes|LMW|Prints hello world when darktable starts
moduleExample|Yes|LMW|How to create a lighttable module
preferenceExamples|Yes|LMW|How to use preferences in a script
printExamples|Yes|LMW|How to use various print functions from a script
running_os|Yes|LMW|Print out the running operating system

### Tools

Tool scripts perform functions relating to the repository, such as generating documentation. They are located in the tools/ directory.

Name|Standalone|OS   |Purpose
----|:--------:|:---:|-------
get_lib_manpages|No|LM|Retrieve the library documentation and output it in man page and PDF format
get_libdoc|No|LMW|Retrieve the library documentation and output it as text

## Download and Install

The recommended method of installation is using git to clone the repository. This ensures that all dependencies on other scripts
are met as well as providing an easy update path. Single scripts listed as standalone may be downloaded and installed by themselves.

### snap packages

The snap version of darktable comes with lua included starting with version 2.4.3snap2. It is currently in the edge channel, but should reach the stable channel soon.

Ensure git is installed on your system. If it isn't, use the package manager to install it. Then open a terminal and:

    cd ~/snap/darktable/current
    git clone https://github.com/darktable-org/lua-scripts.git lua

### flatpak and appimage packages

These packages run in their own environment and don't have access to a lua interpreter, therefore the scripts can't run. The packagers could enable the internal interpreter, or allow the package to link the interpreter from the operating system, or bundle a copy of lua with the package. If you use one of these packages and wish to use the lua scripts, please contact the package maintainer and suggest the above fixes.

### Linux and MacOS

Ensure git is installed on your system. If it isn't, use the package manager to install it. Then open a terminal and:

    cd ~/.config/darktable/
    git clone https://github.com/darktable-org/lua-scripts.git lua

### Windows

Ensure git is installed on your system. Git can be obtained from https://gitforwindows.org/, as well as other places. If you use the gitforwindows.org distribution, install the Git Bash Shell also as it will aid in debugging the scripts if necessary. Then open a command prompt and run:

Open a command prompt.

    cd %LOCALAPPDATA%\darktable
    git clone https://github.com/darktable-org/lua-scripts.git lua

## Enabling

When darktable starts it looks for a file name `~/.config/darktable/luarc` (`%LOCALAPPDATA%\darktable\luarc` for windows) and reads it to see which scripts to include. The file is a plain text file with entries of the form `require "<directory>/<name>"` where directory is the directory containing the scripts, from the above list, and name is the name from the above list. To include GIMP the line would be `require "contrib/gimp"`.

You can also create or add lines to the luarc file from the command line:

`echo 'require "contrib/gimp"' > ~/.config/darktable/luarc` to create the file with a gimp entry\
or `echo 'require "contrib/hugin"' >> ~/.config/darktable/luarc` to add an entry for hugin.

On windows from a command prompt:

`echo 'require "contrib/gimp"' > %LOCALAPPDATA%\darktable\luarc` to create the file with a gimp entry\
or `echo 'require "contrib/hugin"' >> %LOCALAPPDATA%\darktable\luarc` to add an entry for hugin.

## Disabling

To disable a script open the luarc file in your text editor and insert `--` at the start of the line containing the script you wish to disable, then save the file.

## Updating

To update the script repository, open a terminal or command prompt and do the following:

### Snap

    cd ~/snap/darktable/current/lua
    git pull

### Linux and MacOS

    cd ~/.config/darktable/lua/
    git pull

### Windows

    cd %LOCALAPPDATA%\darktable\lua
    git pull

## Documentation

Each script includes its own documentation and usage in its header, please refer to them.

Lua-script libraries documentation may be generated using the tools in the tools/ directory.

More information about the scripting with Lua can be found in the darktable user manual:
https://www.darktable.org/usermanual/en/lua_chapter.html

The darktable Lua API documentation is here:
https://www.darktable.org/lua-api/

## Troubleshooting

Running darktable with Lua debugging enabled provides more information about what is occurring within the scripts.

### Snap

Open a terminal and start darktable with the command `snap run darktable -d lua`. This provides debugging information to give you insight into what is happening.

### Linux and MacOS

Open a terminal and start darktable with the command `darktable -d lua`. This provides debugging information to give you insight into what is happening.

### Windows

Open the Git Bash Shell. Start darktable with the command `/c/Program\ Files/darktable/bin/darktable -d lua`. This provides debugging information to give you insight into what is happening.

## Contributing

In order to have your own scripts added here they have to be under a free license (GPL2+ will definitely work, others can be discussed).
