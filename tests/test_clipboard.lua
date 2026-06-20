local loader = require("spoon_loader")

-- ============================================================
-- Helpers
-- ============================================================

local function make_item(text, lru_time)
   return {
      text = text,
      originalText = text,
      subText = "",
      isSnippet = false,
      lruTime = lru_time,
   }
end

local function make_snippet(text, lru_time)
   return {
      text = "📋 " .. text,
      originalText = text,
      subText = "Snippet",
      isSnippet = true,
      lruTime = lru_time or 0,
   }
end

local function make_action(action_name)
   return { text = "《" .. action_name .. "》", action = action_name }
end

-- ============================================================
-- Suite: dedupe_and_resize
-- ============================================================

describe("dedupe_and_resize", function()
   local obj

   before_each(function()
      obj = loader.load_spoon()
      obj.hist_size = 5
      obj.deduplicate = true
   end)

   it("removes duplicate entries", function()
      local result = obj:dedupe_and_resize({"a", "b", "a", "c"})
      assert.same({"a", "b", "c"}, result)
   end)

   it("trims to hist_size", function()
      local result = obj:dedupe_and_resize({"1","2","3","4","5","6","7"})
      assert.equal(5, #result)
      assert.equal("1", result[1])
   end)

   it("preserves order for unique entries", function()
      local result = obj:dedupe_and_resize({"x", "y", "z"})
      assert.same({"x", "y", "z"}, result)
   end)

   it("returns empty list for empty input", function()
      assert.same({}, obj:dedupe_and_resize({}))
   end)

   it("handles single entry", function()
      assert.same({"hello"}, obj:dedupe_and_resize({"hello"}))
   end)
end)

-- ============================================================
-- Suite: pasteboardToClipboard (history management)
-- ============================================================

describe("pasteboardToClipboard", function()
   local obj

   before_each(function()
      obj = loader.load_spoon()
      obj.hist_size = 100
      obj.deduplicate = true
      obj.clipboardHistoryLRU = {}
      -- Access the module-level clipboard_history via the spoon environment
      -- We start() a minimal version to init internal state
      obj.snippetHistory = {}
      -- Directly call internals via start() is complex; use pasteboardToClipboard
      -- which inserts into clipboard_history
   end)

   it("inserts item at front of history", function()
      obj:pasteboardToClipboard("first")
      obj:pasteboardToClipboard("second")
      local data = obj:_populateChooser()
      -- second should appear before first (index 1 in history = front of list)
      local texts = {}
      for _, item in ipairs(data) do
         if item.originalText then table.insert(texts, item.originalText) end
      end
      assert.equal("second", texts[1])
      assert.equal("first", texts[2])
   end)

   it("sets a real LRU timestamp for new item", function()
      local before = os.time()
      obj:pasteboardToClipboard("hello")
      local after = os.time()
      local ts = obj.clipboardHistoryLRU["hello"]
      assert.truthy(ts)
      assert.truthy(ts >= before and ts <= after)
   end)

   it("deduplicates: re-inserting same item keeps only one copy", function()
      obj:pasteboardToClipboard("dup")
      obj:pasteboardToClipboard("other")
      obj:pasteboardToClipboard("dup")
      local data = obj:_populateChooser()
      local count = 0
      for _, item in ipairs(data) do
         if item.originalText == "dup" then count = count + 1 end
      end
      assert.equal(1, count)
   end)

   it("clears menu cache on insert", function()
      obj:pasteboardToClipboard("x")
      assert.is_nil(obj.menuDataCache)
   end)
end)

-- ============================================================
-- Suite: clearAll
-- ============================================================

describe("clearAll", function()
   local obj

   before_each(function()
      obj = loader.load_spoon()
      obj.clipboardHistoryLRU = {}
      obj.menuDataCache = "stale"
      obj:pasteboardToClipboard("item1")
      obj:pasteboardToClipboard("item2")
   end)

   it("history is empty after clearAll", function()
      obj:clearAll()
      local data = obj:_populateChooser()
      local items = {}
      for _, d in ipairs(data) do
         if d.originalText then table.insert(items, d.originalText) end
      end
      assert.equal(0, #items)
   end)

   it("LRU table is cleared", function()
      obj:clearAll()
      assert.same({}, obj.clipboardHistoryLRU)
   end)

   it("menu cache is cleared", function()
      obj:clearAll()
      assert.is_nil(obj.menuDataCache)
   end)
end)

-- ============================================================
-- Suite: loadSnippets
-- ============================================================

describe("loadSnippets", function()
   local obj
   local tmpfile

   before_each(function()
      obj = loader.load_spoon()
      obj.enableSnippets = true
      obj.snippetHistory = {}
      tmpfile = "/tmp/test_snippets_" .. tostring(math.random(100000, 999999)) .. ".txt"
   end)

   after_each(function()
      os.remove(tmpfile)
   end)

   it("loads snippets separated by blank lines", function()
      local f = io.open(tmpfile, "w")
      f:write("snippet one\n\nsnippet two\n\nsnippet three\n")
      f:close()
      obj.snippetFilePath = tmpfile
      obj:loadSnippets()
      assert.equal(3, #obj.snippets)
      assert.equal("snippet one", obj.snippets[1])
      assert.equal("snippet two", obj.snippets[2])
      assert.equal("snippet three", obj.snippets[3])
   end)

   it("loads multi-line snippet as single entry", function()
      local f = io.open(tmpfile, "w")
      f:write("line one\nline two\n\nnext snippet\n")
      f:close()
      obj.snippetFilePath = tmpfile
      obj:loadSnippets()
      assert.equal(2, #obj.snippets)
      assert.equal("line one\nline two", obj.snippets[1])
   end)

   it("returns empty list for missing file", function()
      obj.snippetFilePath = "/nonexistent/path/snippets.txt"
      obj:loadSnippets()
      assert.same({}, obj.snippets)
   end)

   it("returns empty list for empty file", function()
      local f = io.open(tmpfile, "w"); f:write(""); f:close()
      obj.snippetFilePath = tmpfile
      obj:loadSnippets()
      assert.same({}, obj.snippets)
   end)

   it("deduplicates identical snippets", function()
      local f = io.open(tmpfile, "w")
      f:write("hello\n\nhello\n\nworld\n")
      f:close()
      obj.snippetFilePath = tmpfile
      obj:loadSnippets()
      assert.equal(2, #obj.snippets)
   end)

   it("clears menu cache on reload", function()
      obj.menuDataCache = "stale"
      local f = io.open(tmpfile, "w"); f:write("x\n"); f:close()
      obj.snippetFilePath = tmpfile
      obj:loadSnippets()
      assert.is_nil(obj.menuDataCache)
   end)
end)

-- ============================================================
-- Suite: _filterMenuData — search filtering
-- ============================================================

describe("_filterMenuData", function()
   local obj
   local base_items

   before_each(function()
      obj = loader.load_spoon()
      obj.highlight_search_matches = false
      base_items = {
         make_item("hello world",          1748000100),
         make_item("goodbye world",        1748000090),
         make_item("hello there",          1748000080),
         make_item("completely different", 1748000070),
         make_action("clear"),
      }
   end)

   it("returns all items unchanged when query is empty", function()
      local result = obj:_filterMenuData(base_items, "")
      assert.equal(#base_items, #result)
   end)

   it("returns all items unchanged when query is nil", function()
      local result = obj:_filterMenuData(base_items, nil)
      assert.equal(#base_items, #result)
   end)

   it("filters out non-matching items", function()
      local result = obj:_filterMenuData(base_items, "hello")
      local texts = {}
      for _, item in ipairs(result) do
         if item.originalText then table.insert(texts, item.originalText) end
      end
      assert.equal(2, #texts)
   end)

   it("always includes control action items", function()
      local result = obj:_filterMenuData(base_items, "hello")
      local has_action = false
      for _, item in ipairs(result) do
         if item.action == "clear" then has_action = true end
      end
      assert.is_true(has_action)
   end)

   it("is case-insensitive", function()
      local result = obj:_filterMenuData(base_items, "HELLO")
      local texts = {}
      for _, item in ipairs(result) do
         if item.originalText then table.insert(texts, item.originalText) end
      end
      assert.equal(2, #texts)
   end)

   it("matches all words in multi-word query", function()
      local result = obj:_filterMenuData(base_items, "hello world")
      local texts = {}
      for _, item in ipairs(result) do
         if item.originalText then table.insert(texts, item.originalText) end
      end
      assert.equal(1, #texts)
      assert.equal("hello world", texts[1])
   end)

   it("exact match scores higher than partial match", function()
      local items = {
         make_item("hello world", 1748000100),
         make_item("hello",       1748000090),
      }
      local result = obj:_filterMenuData(items, "hello")
      -- exact match "hello" should rank first
      assert.equal("hello", result[1].originalText)
   end)

   -- BUG TEST: search results should respect LRU when relevance score is equal
   it("BUG: items with equal relevance score are sorted by LRU (most recent first)", function()
      -- Both items match "world" with the same partial score
      -- The one with higher lruTime should rank first
      local items = {
         make_item("world aaa", 1748000050),  -- older LRU
         make_item("world bbb", 1748000200),  -- newer LRU
         make_item("world ccc", 1748000100),  -- middle LRU
      }
      local result = obj:_filterMenuData(items, "world")
      local texts = {}
      for _, item in ipairs(result) do
         if item.originalText then table.insert(texts, item.originalText) end
      end
      -- Most recently used should be first
      assert.equal("world bbb", texts[1])
      assert.equal("world ccc", texts[2])
      assert.equal("world aaa", texts[3])
   end)
end)

-- ============================================================
-- Suite: _populateChooser — LRU ordering
-- ============================================================

describe("_populateChooser LRU ordering", function()
   local obj

   before_each(function()
      obj = loader.load_spoon()
      obj.enableSnippets = false
      obj.snippets = {}
      obj.snippetHistory = {}
      obj.clipboardHistoryLRU = {}
      obj.menuDataCache = nil
   end)

   it("most recently added item appears first (no LRU timestamps)", function()
      obj:pasteboardToClipboard("old item")
      obj:pasteboardToClipboard("new item")
      obj.menuDataCache = nil
      local data = obj:_populateChooser()
      assert.equal("new item", data[1].originalText)
   end)

   it("item accessed via LRU timestamp moves above older items", function()
      obj:pasteboardToClipboard("item A")
      obj:pasteboardToClipboard("item B")
      obj:pasteboardToClipboard("item C")

      -- Simulate user selecting "item A" (oldest) — give it a fresh timestamp
      obj.clipboardHistoryLRU["item A"] = os.time() + 100
      obj.menuDataCache = nil

      local data = obj:_populateChooser()
      assert.equal("item A", data[1].originalText)
   end)

   it("all items with real LRU timestamps sort correctly", function()
      local base = 1748000000
      obj:pasteboardToClipboard("alpha")
      obj:pasteboardToClipboard("beta")
      obj:pasteboardToClipboard("gamma")

      obj.clipboardHistoryLRU["alpha"] = base + 300
      obj.clipboardHistoryLRU["beta"]  = base + 100
      obj.clipboardHistoryLRU["gamma"] = base + 200
      obj.menuDataCache = nil

      local data = obj:_populateChooser()
      local texts = {}
      for _, item in ipairs(data) do
         if item.originalText then table.insert(texts, item.originalText) end
      end
      assert.equal("alpha", texts[1])
      assert.equal("gamma", texts[2])
      assert.equal("beta",  texts[3])
   end)

   -- BUG TEST: items without LRU record use fallback timestamp ~year 2001
   -- They should NOT outrank items with real (2026-era) timestamps
   it("BUG: items without LRU record rank below items that have been accessed", function()
      -- Simulate history loaded from disk with no persisted LRU (skip_lru=true)
      obj:pasteboardToClipboard("never accessed", true)
      obj:pasteboardToClipboard("also never accessed", true)

      -- Simulate user having accessed "never accessed" at some point
      obj.clipboardHistoryLRU["never accessed"] = os.time()
      obj.menuDataCache = nil

      local data = obj:_populateChooser()
      -- The item with a real timestamp should rank first
      assert.equal("never accessed", data[1].originalText)
   end)

   it("snippets appear in chooser and sort by their own LRU", function()
      obj.enableSnippets = true
      obj.snippets = {"snippet one", "snippet two"}
      obj.snippetHistory = {
         ["snippet one"] = 1748000100,
         ["snippet two"] = 1748000200,
      }
      obj:pasteboardToClipboard("clipboard item")
      obj.menuDataCache = nil

      local data = obj:_populateChooser()
      local snippet_texts = {}
      for _, item in ipairs(data) do
         if item.isSnippet then table.insert(snippet_texts, item.originalText) end
      end
      assert.equal(2, #snippet_texts)
   end)
end)

-- ============================================================
-- Suite: _processSelectedItem — selection updates LRU
-- ============================================================

describe("_processSelectedItem LRU update", function()
   local obj

   before_each(function()
      obj = loader.load_spoon()
      obj.paste_on_select = false
      obj.clipboardHistoryLRU = {}
      obj.snippetHistory = {}
      obj.prevFocusedWindow = nil
   end)

   it("selecting a clipboard item updates its LRU timestamp", function()
      obj:pasteboardToClipboard("target item")
      obj.clipboardHistoryLRU["target item"] = nil  -- clear so we can check it gets set

      local before = os.time()
      obj:_processSelectedItem({
         text = "target item",
         originalText = "target item",
         isSnippet = false,
      })
      local after = os.time()

      local ts = obj.clipboardHistoryLRU["target item"]
      assert.truthy(ts)
      assert.truthy(ts >= before and ts <= after)
   end)

   it("selecting a snippet updates snippet LRU, not clipboard LRU", function()
      obj:_processSelectedItem({
         text = "📋 my snippet",
         originalText = "my snippet",
         isSnippet = true,
      })
      assert.truthy(obj.snippetHistory["my snippet"])
      assert.is_nil(obj.clipboardHistoryLRU["my snippet"])
   end)

   it("action item does not update LRU", function()
      obj:pasteboardToClipboard("some item")
      local lru_before = {}
      for k, v in pairs(obj.clipboardHistoryLRU) do lru_before[k] = v end

      obj:_processSelectedItem({ action = "none" })

      assert.same(lru_before, obj.clipboardHistoryLRU)
   end)
end)

-- ============================================================
-- Suite: snippet auto-pin (new feature — expected to FAIL until implemented)
-- ============================================================

describe("auto-pin to snippets", function()
   local obj
   local tmpfile

   before_each(function()
      obj = loader.load_spoon()
      tmpfile = "/tmp/test_autopin_" .. tostring(math.random(100000, 999999)) .. ".txt"
      local f = io.open(tmpfile, "w"); f:write(""); f:close()
      obj.snippetFilePath = tmpfile
      obj.enableSnippets = true
      obj.snippets = {}
      obj.snippetHistory = {}
      obj.clipboardHistoryLRU = {}
      obj.clipboardAccessLog = {}
      obj.autoPinThreshold = 5
      obj.autoPinWindowDays = 1
   end)

   after_each(function()
      os.remove(tmpfile)
   end)

   it("item accessed 5+ times in 24h is appended to snippets.txt", function()
      -- Simulate 5 accesses within the last hour
      local now = os.time()
      obj.clipboardAccessLog["frequent item"] = {
         now - 3600, now - 3000, now - 2400, now - 1800, now - 1200,
      }
      obj:checkAutoPinCandidates()

      local f = io.open(tmpfile, "r")
      local content = f:read("*a")
      f:close()
      assert.truthy(content:find("frequent item", 1, true))
   end)

   it("item accessed 4 times in 24h is NOT pinned", function()
      local now = os.time()
      obj.clipboardAccessLog["rare item"] = {
         now - 3600, now - 2400, now - 1800, now - 900,
      }
      obj:checkAutoPinCandidates()

      local f = io.open(tmpfile, "r")
      local content = f:read("*a")
      f:close()
      assert.falsy(content:find("rare item", 1, true))
   end)

   it("item already in snippets.txt is not appended again", function()
      local f = io.open(tmpfile, "w"); f:write("frequent item\n"); f:close()
      obj:loadSnippets()

      local now = os.time()
      obj.clipboardAccessLog["frequent item"] = {
         now - 3600, now - 3000, now - 2400, now - 1800, now - 1200,
      }
      obj:checkAutoPinCandidates()

      local f2 = io.open(tmpfile, "r")
      local content = f2:read("*a")
      f2:close()
      -- Should appear exactly once
      local count = 0
      for _ in content:gmatch("frequent item") do count = count + 1 end
      assert.equal(1, count)
   end)

   it("accesses older than autoPinWindowDays do not count toward threshold", function()
      local now = os.time()
      local two_days_ago = now - (2 * 24 * 3600)
      obj.clipboardAccessLog["stale item"] = {
         two_days_ago, two_days_ago + 100, two_days_ago + 200,
         two_days_ago + 300, two_days_ago + 400,
      }
      obj:checkAutoPinCandidates()

      local f = io.open(tmpfile, "r")
      local content = f:read("*a")
      f:close()
      assert.falsy(content:find("stale item", 1, true))
   end)

   it("pasteboardToClipboard records access in clipboardAccessLog", function()
      obj:pasteboardToClipboard("tracked item")
      assert.truthy(obj.clipboardAccessLog)
      assert.truthy(obj.clipboardAccessLog["tracked item"])
      assert.equal(1, #obj.clipboardAccessLog["tracked item"])
   end)

   it("_processSelectedItem records access in clipboardAccessLog", function()
      obj.paste_on_select = false
      obj.prevFocusedWindow = nil
      obj:_processSelectedItem({
         text = "tracked item",
         originalText = "tracked item",
         isSnippet = false,
      })
      assert.truthy(obj.clipboardAccessLog)
      assert.truthy(obj.clipboardAccessLog["tracked item"])
   end)
end)

-- ============================================================
-- Suite: checkAndStorePasteboard — clipboard capture
-- ============================================================

describe("checkAndStorePasteboard", function()
   local obj

   before_each(function()
      obj = loader.load_spoon()
      obj.honor_ignoredidentifiers = true
      obj.clipboardHistoryLRU = {}
      -- Reset pasteboard mock to clean state
      hs.pasteboard._reset()
   end)

   after_each(function()
      hs.pasteboard._reset()
   end)

   it("stores text content when pasteboard changes", function()
      -- Simulate user copying "hello"
      hs.pasteboard.setContents("hello world")
      obj:checkAndStorePasteboard()

      local data = obj:_populateChooser()
      local found = false
      for _, item in ipairs(data) do
         if item.originalText == "hello world" then found = true end
      end
      assert.is_true(found)
   end)

   it("does NOT store when pasteboard has not changed", function()
      hs.pasteboard.setContents("initial")
      obj:checkAndStorePasteboard()  -- stores "initial", updates last_change

      -- Second call with same changeCount — should not re-add
      local data1 = obj:_populateChooser()
      local count1 = 0
      for _, item in ipairs(data1) do
         if item.originalText == "initial" then count1 = count1 + 1 end
      end

      obj:checkAndStorePasteboard()  -- no change, should be no-op

      local data2 = obj:_populateChooser()
      local count2 = 0
      for _, item in ipairs(data2) do
         if item.originalText == "initial" then count2 = count2 + 1 end
      end

      assert.equal(count1, count2)
   end)

   it("ignores nil text content (e.g. when only image is copied)", function()
      -- Simulate image copy: text is nil but image exists
      -- Use setContents to bump changeCount, then override getContents to return nil
      hs.pasteboard.setContents("bump")
      hs.pasteboard.getContents = function() return nil end
      hs.pasteboard._setImage({})

      obj:checkAndStorePasteboard()

      local data = obj:_populateChooser()
      local items = {}
      for _, item in ipairs(data) do
         if item.originalText then table.insert(items, item.originalText) end
      end
      -- "bump" was set before getContents was overridden, and checkAndStore
      -- runs after, so nothing should be stored
      assert.equal(0, #items)
   end)

   it("ignores content matching ignoredIdentifiers (e.g. 1Password)", function()
      hs.pasteboard.setContents("secret password")
      hs.pasteboard._setTypes({"com.agilebits.onepassword"})

      obj:checkAndStorePasteboard()

      local data = obj:_populateChooser()
      local found = false
      for _, item in ipairs(data) do
         if item.originalText == "secret password" then found = true end
      end
      assert.is_false(found)
   end)

   it("ignores transient pasteboard type (e.g. TextExpander auto-expand)", function()
      hs.pasteboard.setContents("expanded text")
      hs.pasteboard._setTypes({"org.nspasteboard.TransientType"})

      obj:checkAndStorePasteboard()

      local data = obj:_populateChooser()
      local found = false
      for _, item in ipairs(data) do
         if item.originalText == "expanded text" then found = true end
      end
      assert.is_false(found)
   end)

   it("stores content when honor_ignoredidentifiers is false regardless of type", function()
      obj.honor_ignoredidentifiers = false
      hs.pasteboard.setContents("should store")
      hs.pasteboard._setTypes({"com.agilebits.onepassword"})

      obj:checkAndStorePasteboard()

      local data = obj:_populateChooser()
      local found = false
      for _, item in ipairs(data) do
         if item.originalText == "should store" then found = true end
      end
      assert.is_true(found)
   end)

   it("stores multiple successive copies in order", function()
      hs.pasteboard.setContents("first copy")
      obj:checkAndStorePasteboard()
      hs.pasteboard.setContents("second copy")
      obj:checkAndStorePasteboard()
      hs.pasteboard.setContents("third copy")
      obj:checkAndStorePasteboard()

      local data = obj:_populateChooser()
      local texts = {}
      for _, item in ipairs(data) do
         if item.originalText then table.insert(texts, item.originalText) end
      end
      -- Most recent first
      assert.equal("third copy",  texts[1])
      assert.equal("second copy", texts[2])
      assert.equal("first copy",  texts[3])
   end)

   it("stores content with ignored type in contentTypes (not pasteboardTypes)", function()
      hs.pasteboard.setContents("concealed content")
      hs.pasteboard._setContentTypes({"org.nspasteboard.ConcealedType"})

      obj:checkAndStorePasteboard()

      local data = obj:_populateChooser()
      local found = false
      for _, item in ipairs(data) do
         if item.originalText == "concealed content" then found = true end
      end
      assert.is_false(found)
   end)
end)
