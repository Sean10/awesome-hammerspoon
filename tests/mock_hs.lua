-- Mock hs.* APIs for testing outside Hammerspoon
local settings_store = {}
local pasteboard_count = 0
local pasteboard_contents = ""

hs = {
   settings = {
      get = function(key) return settings_store[key] end,
      set = function(key, val) settings_store[key] = val end,
      _reset = function() settings_store = {} end,
      _store = function() return settings_store end,
   },
   pasteboard = {
      changeCount = function() return pasteboard_count end,
      getContents = function() return pasteboard_contents end,
      setContents = function(s) pasteboard_contents = s; pasteboard_count = pasteboard_count + 1 end,
      clearContents = function() pasteboard_contents = ""; pasteboard_count = pasteboard_count + 1 end,
      pasteboardTypes = function() return {} end,
      contentTypes = function() return {} end,
      readImage = function() return nil end,
      _reset = function()
         pasteboard_count = 0
         pasteboard_contents = ""
         hs.pasteboard.pasteboardTypes = function() return {} end
         hs.pasteboard.contentTypes = function() return {} end
         hs.pasteboard.readImage = function() return nil end
         hs.pasteboard.getContents = function() return pasteboard_contents end
      end,
      -- Test helpers to simulate specific pasteboard conditions
      _setTypes = function(types) hs.pasteboard.pasteboardTypes = function() return types end end,
      _setContentTypes = function(types) hs.pasteboard.contentTypes = function() return types end end,
      _setImage = function(img) hs.pasteboard.readImage = function() return img end end,
   },
   hash = {
      MD5 = function(s)
         -- Simple deterministic hash for testing
         local h = 0
         for i = 1, #s do h = (h * 31 + string.byte(s, i)) % (2^32) end
         return tostring(h)
      end,
   },
   logger = {
      new = function(name)
         return {
            d = function() end, df = function() end,
            i = function() end, e = function() end,
         }
      end,
   },
   timer = {
      doEvery = function(_, fn) return { stop = function() end } end,
   },
   chooser = {
      new = function(_) return {
         choices = function() end,
         show = function() end,
         hide = function() end,
         isVisible = function() return false end,
         query = function() return "" end,
      } end,
   },
   pathwatcher = {
      new = function(_, fn) return { start = function() end, stop = function() end } end,
   },
   fs = {
      pathToAbsolute = function(p) return p end,
   },
   fnutils = {
      partial = function(fn, ...) local args = {...}; return function(...) return fn(table.unpack(args), ...) end end,
   },
   eventtap = {
      keyStroke = function() end,
   },
   image = {
      imageFromName = function(_) return {} end,
   },
}
