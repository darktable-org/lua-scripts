# dtMediaWiki

Wikimedia Commons export plugin for [darktable](https://www.darktable.org/)

See also: [Commons:DtMediaWiki](https://commons.wikimedia.org/wiki/Commons:DtMediaWiki)

## Dependencies

- [lua-sec](https://luarocks.org/modules/brunoos/luasec)
  - Lua bindings for OpenSSL library to provide TLS/SSL communication
- [lua-luajson](https://luarocks.org/modules/harningt/luajson)
  - JSON parser/encoder for Lua
- [lua-multipart-post](https://luarocks.org/modules/catwell/multipart-post)
  - HTTP Multipart Post helper

Note that `mediawikiapi.lua` is independent of darktable.

## Installation

- Download the plugin from [https://github.com/trougnouf/dtMediaWiki/archive/master.zip](https://github.com/trougnouf/dtMediaWiki/archive/master.zip)
- Create the [darktable plugin directory](https://www.darktable.org/usermanual/en/lua_chapter.html#lua_usage) if it doesn't exist
  - `# mkdir /usr/share/darktable/lua/contrib`
- Copy (or link) the dtMediaWiki directory over there
  - `# cp -r /path/to/dtMediaWiki /usr/share/darktable/lua/contrib`
- Activate the plugin in your darktable luarc config file by adding `require "contrib/dtMediaWiki/dtMediaWiki"`
  - `$ echo 'require "contrib/dtMediaWiki/dtMediaWiki"' >> ~/.config/darktable/luarc`

… or simply use the [Arch Linux package](https://aur.archlinux.org/packages/darktable-plugin-dtmediawiki-git/) and activate the plugin.

## Usage

- Login to Wikimedia Commons by setting your "Wikimedia username" and "Wikimedia password" in _[darktable preferences](https://www.darktable.org/usermanual/en/preferences_chapter.html) > lua options_ then restarting darktable.
  - This will add the "Wikimedia Commons" entry into target storage.
- Ensure your image contains the following [metadata](https://www.darktable.org/usermanual/en/metadata_editor.html) and [tags](https://www.darktable.org/usermanual/en/tagging.html):
  - **title** and/or **description** – The default output filename is `title (filename) description.ext` or `title (filename).ext` depending on what is available
  - **rights** – Use something compatible with the [`{{self}}`](https://commons.wikimedia.org/wiki/Template:Self) template, some options are [`cc-by-sa-4.0`](https://commons.wikimedia.org/wiki/Template:Cc-by-sa-4.0), [`cc-by-4.0`](https://commons.wikimedia.org/wiki/Template:Cc-by-4.0), [`GFDL`](https://commons.wikimedia.org/wiki/Template:GFDL), see [Commons:Copyright tags](https://commons.wikimedia.org/wiki/Commons:Copyright_tags)
  - **tags** – Categories and templates. Any tag that matches `Category:something` will be added as `[[Category:something]]` (no need to include the brackets), likewise any template matching `{{something}}` will be added as-is.

The image coordinates will be added if they exist, and the creator metadata will be added as `[[User:Wikimedia username|creator]]` if it has been set.

## Thanks

- Iulia and Leslie for excellent coworking companionship and love
- darktable developers for an excellent open-source imaging software with a well documented [Lua API](https://www.darktable.org/lua-api/)
- [LrMediaWiki](https://github.com/Hasenlaeufer/LrMediaWiki) developers [robinkrahl](https://github.com/robinkrahl) and [Hasenlaeufer](https://github.com/Hasenlaeufer) for what inspired this and some base code
- MediaWiki [User:Platonides](https://www.mediawiki.org/wiki/User:Platonides) for helping me figure out the cookie issue
- [catwell](https://github.com/catwell): author of lua-multipart-post and a responsive fellow
- [simon04](https://github.com/simon04): second user and first contributor

![:)](https://upload.wikimedia.org/wikipedia/commons/3/30/Binette-typo.png)

--[Trougnouf](https://commons.wikimedia.org/wiki/User:Trougnouf)
