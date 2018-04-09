lua-scripts
===========

Download
--------

The Lua scripts in this repository are meant to be used together with darktable. Either copy them individually to `~/.config/darktable/lua` (Linux/Unix) or `%LOCALAPPDATA%\darktable\lua` (Windows) (you might have to create that folder) or just copy/symlink the whole repository there. 

We recommend to clone the repo straight in or symlink it, because some scripts have dependencies to functions in the `lib` folder.

To clone the scripts with git, you just need this commands:

`cd ~/.config/darktable`

`git clone https://github.com/darktable-org/lua-scripts/`

That allows to update all your scripts with a simple call to `git pull`.

Enableling 
----------

To enable one of the scripts you have to add a line like `require "examples/hello_world"` to your: `~/.config/darktable/luarc` (Linux/Unix) or `%LOCALAPPDATA%\darktable\luarc` (Windows) file which will enable the example script in `examples/hello_world.lua` (note the lack of the `.lua` suffix).

Alternativ you can add/enabled the scripts in the luarc with this command:

`echo 'require "examples/hello_world"' >> luarc`

Documentation
-------------

Each script includes its own documentation and usage in its header, please refer to them.

More information about the scripting with lua can be found in the darktable user manual:
https://www.darktable.org/usermanual/en/lua_chapter.html

The darktable Lua API documentation is here:
https://www.darktable.org/lua-api/


Contribution
------------

In order to have your own scripts added here they have to be under a free license (GPL2+ will definitely work, others can be discussed). Scripts in the `official/` subfolder are maintained by the darktable community, those under `contrib/` are meant to have an "owner" who maintains them.
