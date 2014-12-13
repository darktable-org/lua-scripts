lua-scripts
===========

The Lua scripts in this repository are meant to be used together with darktable. Either copy them individually to `~/.config/darktable/lua` (you might have to create that folder) or just copy/symlink the whole repository there. That allows to update all your scripts with a simple call to `git pull`.

To enable one of the scripts you have to add a line like `require "official/hello_world"` which would enable the example script in `official/hello_world.lua`.

Each script includes its own documentation and usage in its header, please refer to them.

In order to have your own scripts added here they have to be under a free license (GPL2+ will definitely work, others can be discussed). Scripts in the `official/` subfolder are maintained by the darktable community, those under `contrib/` are meant to have an "owner" who maintains them.
