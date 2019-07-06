local lu = require "luaunit"
local dt = require "darktable"
local ds = require "lib/dtutils.string"
dt.set_personality("linux")


Test_strip_accents = {}

  function Test_strip_accents:test_a()
    lu.assertEquals(ds.strip_accents("àáâãä"), "aaaaa")
  end

  function Test_strip_accents:test_c()
    lu.assertEquals(ds.strip_accents("ç"), "c")
  end

  function Test_strip_accents:test_e()
    lu.assertEquals(ds.strip_accents("èéêë"), "eeee")
  end

  function Test_strip_accents:test_i()
    lu.assertEquals(ds.strip_accents("ìíîï"), "iiii")
  end

  function Test_strip_accents:test_n()
    lu.assertEquals(ds.strip_accents("ñ"), "n")
  end

  function Test_strip_accents:test_o()
    lu.assertEquals(ds.strip_accents("òóôõö"), "ooooo")
  end

  function Test_strip_accents:test_u()
    lu.assertEquals(ds.strip_accents("ùúûü"), "uuuu")
  end

  function Test_strip_accents:test_y()
    lu.assertEquals(ds.strip_accents("ýÿ"), "yy")
  end

  function Test_strip_accents:test_A()
    lu.assertEquals(ds.strip_accents("ÀÁÂÃÄ"), "AAAAA")
  end

  function Test_strip_accents:test_C()
    lu.assertEquals(ds.strip_accents("Ç"), "C")
  end

  function Test_strip_accents:test_E()
    lu.assertEquals(ds.strip_accents("ÈÉÊË"), "EEEE")
  end

  function Test_strip_accents:test_I()
    lu.assertEquals(ds.strip_accents("ÌÍÎÏ"), "IIII")
  end

  function Test_strip_accents:test_N()
    lu.assertEquals(ds.strip_accents("Ñ"), "N")
  end

  function Test_strip_accents:test_O()
    lu.assertEquals(ds.strip_accents("ÒÓÔÕÖ"), "OOOOO")
  end

  function Test_strip_accents:test_U()
    lu.assertEquals(ds.strip_accents("ÙÚÛÜ"), "UUUU")
  end

  function Test_strip_accents:test_Y()
    lu.assertEquals(ds.strip_accents("Ý"), "Y")
  end

  function Test_strip_accents:test_quick_brown_fox()
    lu.assertEquals(ds.strip_accents("thè quìçk bròwñ fóx jùmped ôvér thê làzý dõgs báck"), "the quick brown fox jumped over the lazy dogs back")
  end

  function Test_strip_accents:test_QUICK_BROWN_FOX()
    lu.assertEquals(ds.strip_accents("THÈ QUÌÇK BRÒWÑ FÓX JÙMPÉD ÔVÊR THË LÀZÝ DÖGS BÂCK"), "THE QUICK BROWN FOX JUMPED OVER THE LAZY DOGS BACK")
  end


Test_escape_xml_characters = {}

  function Test_escape_xml_characters:test_ampersands()
    lu.assertEquals(ds.escape_xml_characters("a&string&with&ampersands"), "a&amp;string&amp;with&amp;ampersands")
  end

  function Test_escape_xml_characters:test_quotes()
    lu.assertEquals(ds.escape_xml_characters('a"string"with"quotes'), "a&quot;string&quot;with&quot;quotes")
  end

  function Test_escape_xml_characters:test_apostrophes()
    lu.assertEquals(ds.escape_xml_characters("a'string'with'apostrophes"), "a&apos;string&apos;with&apos;apostrophes")
  end

  function Test_escape_xml_characters:test_less_than()
    lu.assertEquals(ds.escape_xml_characters("a<string<with<less<than"), "a&lt;string&lt;with&lt;less&lt;than")
  end

  function Test_escape_xml_characters:test_greater_than()
    lu.assertEquals(ds.escape_xml_characters("a>string>with>greater>than"), "a&gt;string&gt;with&gt;greater&gt;than")
  end

  function Test_escape_xml_characters:test_all()
    lu.assertEquals(ds.escape_xml_characters("&\"'<>"), "&amp;&quot;&apos;&lt;&gt;")
  end

Test_urlencode = {}
  
  function Test_urlencode:test_spaces()
    lu.assertEquals(ds.urlencode("a string with spaces"), "a+string+with+spaces")
  end

  function Test_urlencode:test_dashes()
    lu.assertEquals(ds.urlencode("a-string-with-dashes"), "a%2Dstring%2Dwith%2Ddashes")
  end

  function Test_urlencode:test_slashes()
    lu.assertEquals(ds.urlencode("a/string/with/slashes"), "a%2Fstring%2Fwith%2Fslashes")
  end

  function Test_urlencode:test_ampersands()
    lu.assertEquals(ds.urlencode("a&string&with&ampersands"), "a%26string%26with%26ampersands")
  end


Test_sanitize = {}

  function Test_sanitize:test_linux()
    dt.set_personality("linux")
    str = "a string with spaces"
    os_quote = dt.configuration.running_os == "windows" and '"' or "'"
    lu.assertEquals(ds.sanitize(str), os_quote .. str .. os_quote)
    lu.assertNotStrIContains(ds.sanitize(str), os_quote .. os_quote)
  end

  function Test_sanitize:test_windows()
    dt.set_personality("windows")
    str = "a string with spaces"
    os_quote = dt.configuration.running_os == "windows" and '"' or "'"
    lu.assertEquals(ds.sanitize(str), os_quote .. str .. os_quote)
    lu.assertNotStrIContains(ds.sanitize(str), os_quote .. os_quote)
  end

  function Test_sanitize:test_macos()
    dt.set_personality("macos")
    str = "a string with spaces"
    os_quote = dt.configuration.running_os == "windows" and '"' or "'"
    lu.assertEquals(ds.sanitize(str), os_quote .. str .. os_quote)
    lu.assertNotStrIContains(ds.sanitize(str), os_quote .. os_quote)
  end

  function Test_sanitize:test_sanitize_idempotent()
    dt.set_personality("linux")
    lu.assertNotStrIContains(ds.sanitize(ds.sanitize("a string with spaces")), os_quote .. os_quote)
  end

local runner = lu.LuaUnit.new()
os.exit( runner:runSuite() )
