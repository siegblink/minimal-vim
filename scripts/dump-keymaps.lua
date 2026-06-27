-- dump-keymaps.lua — regenerate / verify the "Custom Keymaps" inventory from the nvim config SOURCE.
--
-- WHY a source scan (not a runtime `nvim_get_keymap` dump):
--   * lists only keymaps YOU defined — no built-in Neovim defaults as noise
--   * captures buffer-local Rust / Cargo.toml maps without rust-analyzer attaching
--   * groups maps by source file, which maps directly onto "concern"
--   * needs no plugins/config loaded, so it is fast and deterministic
--
-- USAGE (it only READS files; your config is NOT loaded):
--   nvim -l ~/.config/nvim/scripts/dump-keymaps.lua                 # print inventory (markdown)
--   nvim -l ~/.config/nvim/scripts/dump-keymaps.lua /other/cfg      # scan a different config dir
--   nvim -l ~/.config/nvim/scripts/dump-keymaps.lua > keys.md       # save the markdown
--
--   nvim -l ~/.config/nvim/scripts/dump-keymaps.lua --check         # diff config vs the doc
--   nvim -l ~/.config/nvim/scripts/dump-keymaps.lua --check DOC CFG # diff explicit paths
--     --check compares the keys in your config against the ones documented under
--     "## Custom Keymaps" in ~/.commands/nvim-commands.md and prints what changed.
--     Exit code is non-zero when they differ (handy for a pre-commit hook / CI).
--
-- KNOWN LIMITATION: plugin DEFAULT maps you don't write yourself are not detected
-- (e.g. Comment.nvim's gcc/gc/gb). They live in DOC_ONLY below so --check ignores them.

local HOME = vim.fn.expand("~")
local DEFAULT_CFG = HOME .. "/.config/nvim"
local DEFAULT_DOC = HOME .. "/.commands/nvim-commands.md"

-- Preferred display order + friendly names. Unknown files still appear (after
-- these, alphabetically), so maps in NEW plugin files are never silently dropped.
local ORDER = {
  "vim-options.lua", "bufferline.lua", "neo-tree.lua", "snacks.lua",
  "lsp-config.lua", "none-ls.lua", "trouble.lua", "completions.lua",
  "debugging.lua", "rustaceanvim.lua", "crates.lua", "markdown-preview.lua",
}
local LABEL = {
  ["vim-options.lua"]      = "Core / Window / Editor",
  ["bufferline.lua"]       = "Buffers",
  ["neo-tree.lua"]         = "File Explorer (Neo-tree)",
  ["snacks.lua"]           = "Finder / Git / Terminal / Scratch (Snacks)",
  ["lsp-config.lua"]       = "LSP",
  ["none-ls.lua"]          = "Formatting (none-ls)",
  ["trouble.lua"]          = "Diagnostics & Lists (Trouble)",
  ["completions.lua"]      = "Completion (nvim-cmp)",
  ["debugging.lua"]        = "Debugging (nvim-dap)",
  ["rustaceanvim.lua"]     = "Rust (rustaceanvim)",
  ["crates.lua"]           = "Cargo.toml Dependencies (crates.nvim)",
  ["markdown-preview.lua"] = "Markdown",
}
local SCOPE = {
  ["completions.lua"]      = "insert mode",
  ["rustaceanvim.lua"]     = "buffer-local · .rs files",
  ["crates.lua"]           = "buffer-local · Cargo.toml",
  ["markdown-preview.lua"] = "markdown files",
  ["neo-tree.lua"]         = "some maps act inside the Neo-tree window",
}
local MODEWORD = { i = "insert", v = "visual", x = "visual", s = "select", o = "operator", t = "terminal", c = "command" }

-- Keys that live in the doc on purpose but the scanner can't see (plugin defaults).
-- --check won't flag these as "stale". Stored as raw lhs; normalized on use.
local DOC_ONLY = { "gcc", "gc{motion}", "gbc", "gb{motion}", "gc", "gb" }

local function basename(p) return p:match("[^/]+$") end

local function prettify(name)
  name = name:gsub("%.lua$", ""):gsub("%.vim$", ""):gsub("[-_]", " ")
  return (name:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

-- Canonical form for comparison: lowercase only the text INSIDE <...> (so
-- <Leader>/<leader> and <C-k>/<c-k> match) while preserving bare suffix letters
-- (so <leader>rD ~= <leader>rd, <leader>dO ~= <leader>do).
local function normalize(lhs)
  return (lhs:gsub("<(.-)>", function(inner) return "<" .. inner:lower() .. ">" end))
end

-- All quoted strings on a line, in order, honoring both ' and " quotes.
local function strings(line)
  local out = {}
  for _, s in line:gmatch([=[(['"])(.-)%1]=]) do out[#out + 1] = s end
  return out
end

-- Value of a `name = "..."` field on the line (e.g. desc, ft).
local function field(line, name)
  local _, v = line:match(name .. [[%s*=%s*(['"])(.-)%1]])
  return v
end

-- Does a captured first-string look like a key (vs a repo name / settings key)?
local function keylike(s)
  if not s or s == "" then return false end
  if s:sub(1, 1) == "<" then return true end          -- <leader>x, <C-n>, <CR>...
  if #s <= 2 and not s:find("[/ ]") then return true end -- single keys like h, gd
  return false
end

local function clean_rhs(r)
  if not r then return nil end
  r = r:gsub("%s+$", ""):gsub(",%s*$", "")
  if r:find("function") then return "custom function" end
  return r ~= "" and r or nil
end

-- Parse a single line into { lhs, desc, rhs, mode } or nil. `lines`/`i` allow a
-- short look-ahead so a multi-line map's `desc =` (on a later line) is still found.
local function parse(line, lines, i)
  if line:match("^%s*%-%-") then return nil end -- skip comments / disabled maps
  local s = strings(line)
  local lhs, desc, rhs, mode

  if line:find("vim%.keymap%.set%(") or line:find("nvim_set_keymap%(") then
    mode, lhs = s[1], s[2]
    if not lhs then return nil end -- helper internals like set("n", lhs, ...) have no 2nd string
    desc = field(line, "desc")
    rhs = s[3]
    if not rhs then
      if line:find("function%s*%(") then
        rhs = "custom function"
        if not desc then -- look ahead for a deferred desc =
          for j = i + 1, math.min(i + 12, #lines) do
            local l2 = lines[j]
            if l2:find("vim%.keymap%.set%(") or l2:match("^%s*map%(") then break end
            local d = field(l2, "desc")
            if d then desc = d; break end
          end
        end
      else
        rhs = line:match("set%(%s*['\"][^'\"]*['\"]%s*,%s*['\"][^'\"]*['\"]%s*,%s*([%w_%.:]+)")
      end
    end
  elseif line:match("^%s*map%(") and not line:find("function%s*map") then
    lhs, mode = s[1], "n"
    if s[#s] and s[#s] ~= lhs then desc = s[#s] end
  elseif line:match("^%s*%[%s*['\"]") then -- ["<C-b>"] = ...  /  ["h"] = ...
    lhs = s[1]
    if not keylike(lhs) then return nil end
    rhs = line:match("%]%s*=%s*(.+)$")
  elseif line:match("^%s*{%s*['\"]") then  -- lazy keys spec entry { "<lhs>", ... }
    lhs = s[1]
    if not keylike(lhs) then return nil end -- rejects { "owner/repo" } plugin deps
    desc = field(line, "desc")
    rhs = s[2]
    if desc and rhs == desc then rhs = nil end
  else
    return nil
  end

  if not lhs or lhs == "" then return nil end
  return { lhs = lhs, desc = desc, rhs = clean_rhs(rhs), mode = mode }
end

-- Scan a config dir -> byfile (basename -> ordered entries), ordered list, total.
local function scan(cfg)
  cfg = (vim.fn.fnamemodify(cfg, ":p") or cfg):gsub("/$", "")
  local files = {}
  for _, pat in ipairs({ "**/*.lua", "**/*.vim" }) do
    for _, f in ipairs(vim.fn.globpath(cfg, pat, false, true)) do
      if not f:find("/%.git/") and not f:find("/scripts/") then files[f] = true end
    end
  end

  local byfile, seen = {}, {}
  for f in pairs(files) do
    local bn = basename(f)
    local lines = vim.fn.readfile(f)
    for i, line in ipairs(lines) do
      local e = parse(line, lines, i)
      if e then
        local key = bn .. "|" .. (e.mode or "") .. "|" .. e.lhs
        if not seen[key] then
          seen[key] = true
          byfile[bn] = byfile[bn] or {}
          table.insert(byfile[bn], e)
        end
      end
    end
  end

  local ordered, used = {}, {}
  for _, bn in ipairs(ORDER) do
    if byfile[bn] then ordered[#ordered + 1] = bn; used[bn] = true end
  end
  local rest = {}
  for bn in pairs(byfile) do if not used[bn] then rest[#rest + 1] = bn end end
  table.sort(rest)
  for _, bn in ipairs(rest) do ordered[#ordered + 1] = bn end

  local total = 0
  for _, list in pairs(byfile) do total = total + #list end
  return byfile, ordered, total, cfg
end

-- Build markdown inventory string from a scan.
local function render(cfg, byfile, ordered, total)
  local out = {}
  local function w(s) out[#out + 1] = s end
  w("## Custom Keymaps")
  w("")
  w(("_Generated from `%s` — %d keymaps across %d groups. Leader = `<Space>`._"):format(cfg, total, #ordered))
  w("_Re-run `nvim -l scripts/dump-keymaps.lua` after config changes. Comment.nvim defaults (gcc/gc/gb) are plugin defaults and not auto-detected._")
  w("")
  for _, bn in ipairs(ordered) do
    local head = "### " .. (LABEL[bn] or prettify(bn))
    if SCOPE[bn] then head = head .. ("  _(%s)_"):format(SCOPE[bn]) end
    w(head)
    for _, e in ipairs(byfile[bn]) do
      local desc = e.desc or e.rhs or "—"
      local line = ("- `%s` - %s"):format(e.lhs, desc)
      local mw = e.mode and MODEWORD[e.mode]
      if mw then line = line .. ("  _(%s)_"):format(mw) end
      w(line)
    end
    w("")
  end
  return table.concat(out, "\n") .. "\n"
end

-- Extract documented keys from the "## Custom Keymaps" section of the doc.
-- Returns { [normalized lhs] = raw lhs } or nil, err.
local function parse_doc(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil, "cannot read " .. path end
  local in_section, seen_group, keys = false, false, {}
  for _, line in ipairs(lines) do
    local h2 = line:match("^##%s+(.+)")
    if h2 then
      in_section = h2:find("Custom Keymaps") ~= nil
      seen_group = false
    elseif in_section then
      if line:match("^###%s+") then
        seen_group = true               -- only collect bullets inside a group, not the intro
      elseif seen_group then
        local lhs = line:match("^%s*%-%s+`([^`]+)`")
        if lhs then
          local n = normalize(lhs)
          if not keys[n] then keys[n] = lhs end
        end
      end
    end
  end
  return keys
end

-- ── main ──────────────────────────────────────────────────────────────────
local args = arg or {}
local check, positionals = false, {}
for _, a in ipairs(args) do
  if a == "--check" then check = true else positionals[#positionals + 1] = a end
end

if not check then
  local byfile, ordered, total, cfg = scan(positionals[1] or DEFAULT_CFG)
  io.write(render(cfg, byfile, ordered, total))
  return
end

-- check mode
local doc_path = positionals[1] or DEFAULT_DOC
local cfg_dir  = positionals[2] or DEFAULT_CFG

local byfile, ordered, total, cfg = scan(cfg_dir)
local cfg_keys = {} -- normalized -> { lhs, desc, group }
for _, bn in ipairs(ordered) do
  for _, e in ipairs(byfile[bn]) do
    cfg_keys[normalize(e.lhs)] = { lhs = e.lhs, desc = e.desc or e.rhs, group = LABEL[bn] or prettify(bn) }
  end
end

local doc_keys, err = parse_doc(doc_path)
if not doc_keys then io.stderr:write("error: " .. err .. "\n"); os.exit(2) end

local ignore = {}
for _, k in ipairs(DOC_ONLY) do ignore[normalize(k)] = true end

local added, stale = {}, {}
for n, info in pairs(cfg_keys) do
  if not doc_keys[n] then added[#added + 1] = info end
end
for n, raw in pairs(doc_keys) do
  if not cfg_keys[n] and not ignore[n] then stale[#stale + 1] = raw end
end
table.sort(added, function(a, b) return a.lhs < b.lhs end)
table.sort(stale)

local doc_count = 0
for _ in pairs(doc_keys) do doc_count = doc_count + 1 end

local o = {}
local function w(s) o[#o + 1] = s end
w(("Keymap check"))
w(("  config: %s  (%d keys)"):format(cfg, total))
w(("  doc:    %s  (%d entries)"):format(doc_path, doc_count))
w("")
w(("++ ADDED — in config, missing from the doc (%d):"):format(#added))
if #added == 0 then w("   (none)") else
  for _, i in ipairs(added) do
    w(("   `%s` - %s   [%s]"):format(i.lhs, i.desc or "—", i.group))
  end
end
w("")
w(("-- STALE — in the doc, gone from config (%d):"):format(#stale))
if #stale == 0 then w("   (none)") else
  for _, k in ipairs(stale) do w(("   `%s`"):format(k)) end
  w("   (verify: may be a plugin-default map the scanner can't see)")
end
w("")
if #added == 0 and #stale == 0 then w("✓ in sync") else w("✗ differences found") end

io.write(table.concat(o, "\n") .. "\n")
io.flush()
os.exit((#added > 0 or #stale > 0) and 1 or 0)
