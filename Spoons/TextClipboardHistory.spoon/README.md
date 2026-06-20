# TextClipboardHistory

Hammerspoon Spoon：保留剪贴板的文本历史，并支持固定 Snippet、LRU 排序、自动 Pin 等扩展功能。

---

## 功能概览

| 功能 | 说明 |
|------|------|
| 剪贴板历史 | 自动记录所有文本复制，默认保留最近 100 条 |
| LRU 排序 | 按最近使用时间排序，常用内容自动靠前 |
| Snippet 固定剪贴板 | 从文件加载常用片段，显示在历史列表顶部 |
| 自动 Pin | 高频访问的历史条目自动追加到 Snippet 文件 |
| 持久化 | 历史、LRU、Snippet 访问记录均通过 `hs.settings` 持久化，重启后恢复 |
| 搜索 | 实时过滤，支持高亮匹配，结果按 LRU tiebreak |
| Paste-on-select | 选中后自动粘贴（可运行时开关） |

---

## 快速配置（init.lua）

```lua
local cb = hs.loadSpoon("TextClipboardHistory")

cb.hist_size           = 100     -- 最多保留条数
cb.frequency           = 0.8     -- 轮询间隔（秒）
cb.deduplicate         = true    -- 去重
cb.paste_on_select     = false   -- 选中后是否自动粘贴
cb.honor_ignoredidentifiers = false  -- true = 过滤密码管理器等工具的复制

-- Snippet 相关
cb.enableSnippets      = true
cb.snippetFilePath     = os.getenv("HOME") .. "/.config/hammerspoon/snippets.txt"

-- 自动 Pin：24 小时内访问 ≥ 5 次，自动追加到 snippets.txt
cb.autoPinThreshold    = 5
cb.autoPinWindowDays   = 1

cb:bindHotkeys({ show_clipboard = { {"cmd", "shift"}, "v" } })
cb:start()
```

---

## Snippet 文件格式

路径默认为 `~/.config/hammerspoon/snippets.txt`，用**空行**分隔每条 Snippet，支持多行内容：

```
第一条单行 Snippet

第二条
可以是多行
内容

https://example.com/常用链接
```

文件修改后自动热重载，无需重启 Hammerspoon。

---

## LRU 排序规则

- 访问过的条目：按最近访问时间降序排列
- 从未访问的条目：排在所有访问过的条目后面，按插入顺序（最新复制的靠前）
- Snippet 有独立的 LRU，与剪贴板历史互不干扰
- 选中 Snippet 不会将其加入剪贴板历史

---

## 自动 Pin 机制

`checkAutoPinCandidates()` 在每次 `start()` 后及定期调用：

1. 统计 `autoPinWindowDays` 天内每个条目的访问次数
2. 达到 `autoPinThreshold` 次且不在 snippets.txt 中 → 自动追加
3. 追加后热重载 Snippet 列表

手动清理不再需要的 Pin：直接编辑 `snippets.txt` 删除对应条目即可。

---

## 持久化存储

所有状态通过 `hs.settings`（底层 `NSUserDefaults`）写入：

| Key | 内容 |
|-----|------|
| `TextClipboardHistory.items` | 剪贴板历史列表 |
| `TextClipboardHistory.clipboardHistoryLRU` | 条目的最近访问时间戳 |
| `TextClipboardHistory.clipboardAccessLog` | 条目的访问次数日志（用于 auto-pin） |
| `TextClipboardHistory.snippetHistory` | Snippet 的最近使用时间戳 |
| `TextClipboardHistory.paste_on_select` | paste-on-select 开关状态 |

重启 Hammerspoon 或设备后，历史和排序均自动恢复。

---

## 快捷键绑定参考

```lua
cb:bindHotkeys({
    show_clipboard   = { {"cmd", "shift"}, "v" },  -- 打开历史列表
    toggle_clipboard = { {"cmd", "shift"}, "x" },  -- 切换显示/隐藏
})
```

---

## 已知行为

- 图片内容不记录，仅记录文本
- `honor_ignoredidentifiers = true` 时，来自密码管理器（1Password 等）、文本扩展工具（TextExpander 等）的复制会被过滤
- Snippet 选中后写入系统剪贴板，但**不计入**剪贴板历史条数
