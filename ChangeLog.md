## Changes from most recent to oldest

**06 Jun 2024 - wpferguson**
* fix fujifilm_ratings running on all images 
* added string library functions to sanitize windows io.popen and os.execute functions
* added database maintenance script

**05 Jun 2024 - wpferguson**
* added fix for executable_manager not being visible on windows

**30 May 2024 - kkotowicz**
* open in explorer now uses applescript on macos to open multiple files

**20 May 2024 - wpferguson**
* added string variable substitution to the string library

**16 May 2024 - wpferguson**
* fix crash in script_manager

**15 May 2024 - wpferguson**
* added metadata to scripts (name, author, purpose, help url)

**06 May 2024 -  christian.sueltrop**
* added passport_guide_germany script

**08 Apr 2024 - wpferguson**
* made script_manager aware of library modules in other directories besides lib

**29 Mar 2024 - wpferguson**
* updated examples/gui_action to use NaN instead of nan

**29 Mar 2024 - dterrahe**
* add lua action script example

**28 Jan 2024 - wpferguson**
* fix script_manager crash when script existed in top level lua directory

**24 Jan 2024 - wpferguson**
* don't set lib visibility unless we are in lighttable mode

**15 Jan 2024 - MStraeten**
* update x-touch.lua with support for primaries slider

**14 Jan 2024 - wpferguson**
* added cycle_group_leader script
* added hif_group_leader script
* added jpg_group_leader script

**28 Oct 2023 - ddittmar**
* Added select non existing image script

**17 Oct 2023 - wpferguson**
* script_manager wrap username in quotes to handle spaces in username

**20 Sep 2023 - wpferguson**
* script_manager explicitly set stopped scripts to false

**18 Aug 2023 - wpferguson**
* swap the position of executable_manager and script_manager due to windows gtk bug

**17 Jul 2023 - wpferguson**
* update check for update instructions
* update flatpak readme

**16 Jul 2023 - wpferguson**
* added script_data.show function to contrib/gpx_export

**15 Jul 2023 - wpferguson**
* script_manager updates
* added check_max_api_version for the case where the API no longer supports the required 
  functions

**14 Jul 2023 - spaceChRis**
* add tooltip to filter manager

**25 Mar 2023 - wpferguson**
* Added script_manager darktable shortcut integration
* Moved filename/path/extension string functions to string library

**06 Mar 2023 - wpferguson - Added option to disable script_manager update check**

**12 Jan 2022 - wpferguson - Documented contrib/rename_images.lua**

**28 Dec 2021 - wpferguson - Replaced deprecated _which_ command with _command -v_ in lib/dtutils/file.lua**

**12 Dec 2021 - wpferguson**
* Added deprecated function to library
* Added deprecation warning to contrib/rename-tags.lua

**22 Oct 2021 - wpferguson for Volker Bödker - make sure sequence is 4 digits in rename_images.lua**

**31 Aug 2021 - wpferguson - remove styles hiding from AutoGrouper.lua**

**02 Jul 2021 - wpferguson - merged API-7.0.0-dev branch to master**
* API-7.0.0 is darktable 3.6
* breaking changes
  * register_event argments changed
  * register_action arguments changed
  * register_selection arguments changed
  * register_event arguments changed
* scripts updated to API-7.0.0 compatibility
* script_manger updated to be API aware and check out the proper branch
  based on darktable API version

**01 Jul 2021 - wpferguson - created branch for API-6.1.0 - darktable 3.4**

**20 Jun 2021 - wpferguson - created branches for older API versions**
* API-6.0.0 - darktable 3.2.1
* API-5.0.2 - darktable 3.0
* API-5.0.1 - darktable 2.6.1
* API-5.0.0 - darktable 2.4
* API-4.0.0 - darktable 2.2
* API-3.0.0 - darktable 2.0

**19 Jun 2021 - wpferguson - fix issue 312, image_path_in_ui**

**02 Jun 2021 - wpferguson - fix contrib/quicktag**
* set new entry field is_password to false so entry
is visible to user while typing.

**19 Mar 2021 - wpferguson - fixed crash in contrib/HDRmerge.lua**
* Made generated filename routine gracefully handle names that
are not in the expected format.

**15 Mar 2021 - scheckmedia - updated contrib/photils.lua**
* refactor print method
* add option to apply selected tags from a single image to multiple images
* add setting parameter to enable/disable the export of an image before tag suggestion

**25 Feb 2021 - wpferguson - added detached mode to contrib/gimp.lua**

* Added run_detached checkbox to the exporter GUI.  Selecting run_detached
let's GIMP keep running and accepting additional images.  It does not return
the edited images to darktable.

**24 Feb 2021 - Mark64 - make ext_editor lib visible in darkroom view**

**17 Feb 2021 - wpferguson - API 6.2.3 register_action changes**

* Added check for API version and supplied a name argument if the 
API version was greater than or equal to 6.2.3 

**10 Feb 2021 - wpferguson - bugfix select_untagged**

* Fixed callback to return a list of images as expected instead of
doing the selection in the callback

**10 Feb 2021 - wpferguson - bugfix API 6.2.1 compatibility**

* The inline check for API version didn't handle argument return
correctly so added a transition library with a register_event function
override to check the API version and process the arguments correctly.

**9 Feb 2021 - wpferguson - bugfix API 6.2.2 compatibility**

* The inline check for API version didn't handle argument return
correctly so changed it to a full if/else block 

**4 Reb 2021 - wpferguson - API 6.2.2 compatibililty**

* Added check for API version and supplied a name argument to register_selection
if the API version was greater than or eqal to 6.2.2 

**1 Feb 2021 - wpferguson - API 6.2.1 compatibility**

* Added check for API version and supplied a name argument to register_event
if the API version was greater than or eqal to 6.2.1 

**21 Jan 2021 - wpferguson - Modified dtutils function find_image_by_id**

* For users with API 6.2.0 or greater - Enabled use of new API function
darktable.database_get_image() in find_image_by_id().

**19 Jan 2021 - schwerdf - Added dtutils library function find_image_by_id()**

* Added new library function to retrieve an image from the library based on it's ID instead
of it's row number in the database 

**10 Jan 2021 - chrisaga - copy_attach_detach_tags localization**

**7 Jan 2021 - dtorop - add contrib/fujifilm_dynamic_range**

* add a new contrib script, fujifilm_dynamic_range to adjust exposure
based on the exposure bias camera setting
