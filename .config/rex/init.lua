local prefix = "ctrl+space>"

-- Sessions (Herdr workspaces)
rex.bind(prefix .. "shift+c", "session.new")
rex.bind(prefix .. "shift+d", "session.close")
rex.bind(prefix .. "shift+p", "session.previous")
rex.bind(prefix .. "shift+n", "session.next")

-- Tabs (Rex windows), scoped to the current session.
-- Colemak-DH home row picks tabs in the app's global order (all sessions,
-- like Rex's default numbering). tab-letters.lua keeps each letter in the
-- tab name ("a · dotfiles") so the sidebar shows it.
local tab_keys = { "a", "r", "s", "t", "g", "m", "n", "e", "i", "o", "1", "2", "3", "4", "5", "6", "7", "8", "9" }

rex.action {
  name = "session_tab_goto",
  title = "Go to Tab",
  args = { index = "integer" },
  run = function(_, args)
    rex.client.queue("client.tab.goto", { index = args.index })
    return true
  end,
}

-- terminal-browser (Chromium over Kitty graphics) in a right split.
-- session.new_split ignores the block command, so go through `rex run`.
local rex_cli = os.getenv("HOME")
  .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"

rex.action {
  name = "browser_split",
  title = "Open Browser in Split",
  run = function(ctx)
    local cmd = { rex_cli, "run", "-s", ctx.session_id, "--split", "right", "--shell", "none", "--label", "browser" }
    if ctx.block_id then
      table.insert(cmd, "-b")
      table.insert(cmd, ctx.block_id)
    end
    table.insert(cmd, "--")
    table.insert(cmd, "/opt/homebrew/bin/terminal-browser")
    local result = rex.exec(cmd)
    if not result.ok then error(result.stderr, 0) end
    return true
  end,
}
rex.bind(prefix .. "shift+b", "browser_split")

-- Copy mode like Herdr: prefix+[ enters; Rex's vi keys apply inside.
-- On CSA, { } are Option+7/8, which type text everywhere else, so copy
-- mode also turns on the "copy" key mode where they jump paragraphs. Once
-- copy mode ends, those actions are unavailable and the keys fall through.
-- The key mode is per client but copy mode is per pane, and Lua can't see
-- copy mode, so remember which panes are in it.
local copy_blocks, copy_keys_on = {}, false

-- Mode actions fail (and cancel the rest of the queue) when there is nothing
-- to enter or leave, so only queue them when the state changes.
local function set_copy_keys(on)
  if on == copy_keys_on then return end
  rex.client.queue(on and "client.mode.enter" or "client.mode.exit_all", on and { name = "copy" } or nil)
  copy_keys_on = on
end

rex.action {
  name = "copy_mode_enter",
  title = "Enter Copy Mode",
  run = function(ctx)
    if ctx.block_id then copy_blocks[ctx.block_id] = true end
    rex.client.queue("pane.copy_mode.enter")
    set_copy_keys(true)
    return true
  end,
}
rex.bind(prefix .. "[", "copy_mode_enter")
rex.bind(prefix .. "alt+9", "copy_mode_enter") -- "[" on Canadian CSA
rex.unbind("shift+cmd+c") -- default copy mode entry
rex.bind("copy/alt+7", "pane.copy_mode.move", { to = "paragraph_backward" })
rex.bind("copy/alt+8", "pane.copy_mode.move", { to = "paragraph_forward" })

-- y copies and clears the selection but stays in copy mode; Enter yanks and
-- leaves; q/Esc leave. Selecting char, line, line clears any selection type.
local copy_key_text = { y = "y", enter = "\r", q = "q", escape = "\27" }
rex.action {
  name = "copy_mode_key",
  title = "Copy Mode Key",
  args = { key = "string" },
  run = function(ctx, args)
    if not copy_blocks[ctx.block_id] then
      -- The key mode outlived copy mode in this pane: type the key instead.
      set_copy_keys(false)
      local _, err = rex.block.call("com.superlogical.terminal", "write", { data = copy_key_text[args.key] })
      if err ~= nil then error(err, 0) end
      return true
    end
    if args.key == "y" then
      rex.client.queue("pane.copy")
      for _, mode in ipairs({ "char", "line", "line" }) do
        rex.client.queue("pane.copy_mode.select", { mode = mode })
      end
      return true
    end
    rex.client.queue(args.key == "enter" and "pane.copy_mode.yank" or "pane.copy_mode.exit")
    set_copy_keys(false)
    copy_blocks[ctx.block_id] = nil
    return true
  end,
}
for key in pairs(copy_key_text) do
  rex.bind("copy/" .. key, "copy_mode_key", { key = key })
end

-- Ctrl+Shift+K/J scroll Pi. Fullscreen Pi (alternate screen) scrolls itself,
-- so it gets the key (kitty encoding; copy mode would swallow it). Regular
-- Pi lives in the scrollback, which Rex can only scroll by pages.
rex.action {
  name = "pi_scroll",
  title = "Scroll Pi",
  args = { key = "string" },
  run = function(_, args)
    local term = "com.superlogical.terminal"
    local process = rex.block.call(term, "process", {}) or {}
    local foreground = process.foreground or {}
    local modes = rex.block.call(term, "modes", {}) or {}
    if foreground.argv0 == "pi" and modes.screen ~= "alternate" then
      rex.client.queue(args.key == "k" and "client.scroll.page_up" or "client.scroll.page_down")
      return true
    end
    local code = args.key == "k" and 107 or 106
    local _, err = rex.block.call(term, "write", { data = "\27[" .. code .. ";6u" })
    if err ~= nil then error(err, 0) end
    return true
  end,
}
rex.bind("ctrl+shift+k", "pi_scroll", { key = "k" })
rex.bind("ctrl+shift+j", "pi_scroll", { key = "j" })

rex.bind(prefix .. "c", "client.tab.new")
rex.bind(prefix .. "shift+t", "client.tab.rename")
rex.bind(prefix .. "shift+w", "client.tab.close")
for index, key in ipairs(tab_keys) do
  rex.bind(prefix .. key, "session_tab_goto", { index = index })
end

-- Panes
rex.bind(prefix .. "v", "pane.split", { direction = "right" })
rex.bind(prefix .. "h", "pane.split", { direction = "down" })
rex.bind(prefix .. "w", "pane.close")
rex.bind(prefix .. "z", "pane.zoom")
rex.bind(prefix .. "tab", "pane.focus_next")
rex.bind(prefix .. "shift+tab", "pane.focus_previous")
rex.bind(prefix .. "b", "client.sidebar.toggle")

-- Preserve zoom while focusing the nearest pane in a direction. Among equally
-- near panes (e.g. a stacked group), prefer the most recently visited one,
-- then the largest. Rex keeps no focus history, so navigation records it
-- (it lives until the config reloads).
local last_visit, visit_clock = {}, 0

local function mark_visited(block_id)
  visit_clock = visit_clock + 1
  last_visit[block_id] = visit_clock
end
local function collect_panes(node, panes)
  if node.block_id then
    table.insert(panes, { id = node.block_id, rect = node.rect })
  elseif node.split then
    collect_panes(node.split.before, panes)
    collect_panes(node.split.after, panes)
  end
end

local function pane_score(rect, current, direction)
  local distance, overlap, cross
  if direction == "left" and rect[1] + rect[3] <= current[1] then
    distance = current[1] - rect[1] - rect[3]
    overlap = math.min(rect[2] + rect[4], current[2] + current[4]) - math.max(rect[2], current[2])
    cross = math.abs(rect[2] + rect[4] / 2 - current[2] - current[4] / 2)
  elseif direction == "right" and rect[1] >= current[1] + current[3] then
    distance = rect[1] - current[1] - current[3]
    overlap = math.min(rect[2] + rect[4], current[2] + current[4]) - math.max(rect[2], current[2])
    cross = math.abs(rect[2] + rect[4] / 2 - current[2] - current[4] / 2)
  elseif direction == "up" and rect[2] + rect[4] <= current[2] then
    distance = current[2] - rect[2] - rect[4]
    overlap = math.min(rect[1] + rect[3], current[1] + current[3]) - math.max(rect[1], current[1])
    cross = math.abs(rect[1] + rect[3] / 2 - current[1] - current[3] / 2)
  elseif direction == "down" and rect[2] >= current[2] + current[4] then
    distance = rect[2] - current[2] - current[4]
    overlap = math.min(rect[1] + rect[3], current[1] + current[3]) - math.max(rect[1], current[1])
    cross = math.abs(rect[1] + rect[3] / 2 - current[1] - current[3] / 2)
  else
    return nil
  end
  return { overlaps = overlap > 0, distance = distance, area = rect[3] * rect[4], cross = cross, visit = 0 }
end

local function better_score(candidate, current)
  if current == nil or candidate.overlaps ~= current.overlaps then
    return current == nil or candidate.overlaps
  end
  if math.abs(candidate.distance - current.distance) > 0.000001 then
    return candidate.distance < current.distance
  end
  if candidate.visit ~= current.visit then
    return candidate.visit > current.visit
  end
  if math.abs(candidate.area - current.area) > 0.000001 then
    return candidate.area > current.area
  end
  return candidate.cross < current.cross
end

local function focus_direction(direction)
  local view, err = rex.session.view {}
  if err ~= nil then error(err, 0) end

  local window
  for _, candidate in ipairs(view.windows or {}) do
    if candidate.window_id == view.active_window_id then window = candidate end
  end
  if window == nil or window.focused_block_id == nil then return end

  local panes = {}
  for _, layer in ipairs(window.layers or {}) do
    if layer.kind == "tiled" and layer.layout then collect_panes(layer.layout, panes) end
  end

  local current
  for _, pane in ipairs(panes) do
    if pane.id == window.focused_block_id then current = pane.rect end
  end
  if current == nil then return end

  local target, target_score
  for _, pane in ipairs(panes) do
    if pane.id ~= window.focused_block_id then
      local score = pane_score(pane.rect, current, direction)
      if score then score.visit = last_visit[pane.id] or 0 end
      if score and better_score(score, target_score) then
        target, target_score = pane.id, score
      end
    end
  end
  if target == nil then return end
  mark_visited(window.focused_block_id)
  mark_visited(target)

  if window.zoomed_block_id ~= nil then
    -- One atomic call avoids briefly restoring the layout and resizing every terminal.
    local _, zoom_err = rex.session.zoom_block { block_id = target, zoom = true }
    if zoom_err ~= nil then error(zoom_err, 0) end
    return target
  end

  local _, focus_err = rex.session.focus_block { block_id = target }
  if focus_err ~= nil then error(focus_err, 0) end
  return target
end

local direction_keys = { left = "h", down = "j", up = "k", right = "l" }
rex.action {
  name = "smart_navigate",
  title = "Navigate Pane",
  args = { direction = "string", force = "boolean?" },
  run = function(ctx, args)
    if ctx.origin == "key" and not args.force then
      local process = rex.block.call("com.superlogical.terminal", "process", {})
      local foreground = process and process.foreground or {}
      -- Only Neovim gets the key: it moves between its own splits and hands
      -- off to Rex at its edges. Every other app navigates Rex panes directly.
      local name = (foreground.argv0 or foreground.name or ""):match("[^/]+$") or ""
      if name == "nvim" or name == "vim" or foreground.name == "nvim" then
        -- Write the raw control byte: pane.send_key goes back through this
        -- same binding and never reaches Neovim.
        local byte = string.char(direction_keys[args.direction]:byte() - 96)
        local _, err = rex.block.call("com.superlogical.terminal", "write", { data = byte })
        if err ~= nil then error(err, 0) end
        return true
      end
    end
    local target = focus_direction(args.direction)
    if target then
      -- Copy-mode keys follow the pane that is in copy mode.
      set_copy_keys(copy_blocks[target] == true)
    end
    return true
  end,
}

for direction, key in pairs(direction_keys) do
  rex.bind("ctrl+" .. key, "smart_navigate", { direction = direction })
  rex.bind("cmd+" .. key, "smart_navigate", { direction = direction, force = true })
end

-- Herdr-style direct resizing.
rex.bind("ctrl+alt+h", "pane.resize", { direction = "left", amount = 5 })
rex.bind("ctrl+alt+j", "pane.resize", { direction = "down", amount = 5 })
rex.bind("ctrl+alt+k", "pane.resize", { direction = "up", amount = 5 })
rex.bind("ctrl+alt+l", "pane.resize", { direction = "right", amount = 5 })

-- Canadian CSA input and Ghostty-compatible word deletion.
-- Write the characters directly: key names are re-encoded with the active
-- CSA layout, where the bracket keys don't produce these characters.
rex.action {
  name = "type_text",
  title = "Type Text",
  args = { text = "string" },
  run = function(_, args)
    local _, err = rex.block.call("com.superlogical.terminal", "write", { data = args.text })
    if err ~= nil then error(err, 0) end
    return true
  end,
}
rex.bind("alt+7", "type_text", { text = "{" })
rex.bind("alt+8", "type_text", { text = "}" })
rex.bind("alt+9", "type_text", { text = "[" })
rex.bind("alt+0", "type_text", { text = "]" })
rex.bind("alt+backspace", "pane.send_key", { key = "ctrl+w" })
rex.bind("ctrl+backspace", "pane.send_key", { key = "ctrl+w" })

-- Ghostty changes font size by two points per keypress.
local function font_twice(action)
  return function()
    rex.client.queue(action)
    rex.client.queue(action)
    return true
  end
end
rex.bind("ctrl+[NumpadAdd]", font_twice("client.font.increase"))
rex.bind("ctrl+-", font_twice("client.font.decrease"))

rex.bind(prefix .. "shift+s", "client.settings")
rex.bind(prefix .. "shift+r", "client.config.reload")
