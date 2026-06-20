-- Helper to load the spoon with mocked hs
require("mock_hs")

-- Patch require("hs.pasteboard") and require("hs.hash") used at module level
local real_require = require
_G.require = function(mod)
   if mod == "hs.pasteboard" then return hs.pasteboard end
   if mod == "hs.hash" then return hs.hash end
   return real_require(mod)
end

local spoon_path = "../Spoons/TextClipboardHistory.spoon/init.lua"

-- Loader returns a fresh obj each time (avoids state bleed between tests)
local function load_spoon()
   -- Reset shared state
   hs.settings._reset()
   hs.pasteboard._reset()

   -- Force reload by clearing package cache
   package.loaded["TextClipboardHistory"] = nil

   local chunk = assert(loadfile(spoon_path))
   local spoon = chunk()

   -- Initialize internal state that start() would normally set up
   -- (we avoid calling start() because it registers timers and watchers)
   spoon.clipboardHistoryLRU = {}
   spoon.snippetHistory = {}
   spoon.snippets = {}
   spoon.enableSnippets = false
   spoon.deduplicate = true
   spoon.hist_size = 100
   spoon.menuDataCache = nil
   spoon.filteredMenuDataCache = nil
   spoon.lastSearchQuery = ""
   spoon.highlight_search_matches = false
   spoon.paste_on_select = false
   spoon.prevFocusedWindow = nil
   spoon.clipboardAccessLog = {}

   -- Initialize the module-level clipboard_history table via a controlled insert
   -- The internal variable starts nil; calling clearAll initialises it safely
   -- but clearAll calls pasteboard.clearContents which is mocked.
   -- Instead we call pasteboardToClipboard with a sentinel then clear it.
   -- Simpler: directly expose an init helper via the spoon.
   spoon:_initHistory()

   return spoon
end

return { load_spoon = load_spoon }
