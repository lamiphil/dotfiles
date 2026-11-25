-- Keeps each tab's Colemak-DH jump letter in its name ("a · dotfiles").
-- Letters run across all sessions in order, matching Rex's global tab numbers.
-- init.lua can't hook events in Rex Beta, so this runs as a separate
-- listener (`rex do --all`), started by the launch agent apply.sh installs.
local tab_keys = { "a", "r", "s", "t", "g", "m", "n", "e", "i", "o", "1", "2", "3", "4", "5", "6", "7", "8", "9" }

-- Rex sometimes drops a tab's zoom when you come back to it. Remember each
-- tab's zoom while it is active, and zoom it again right after it becomes
-- active. An unzoom later than that is yours and is remembered.
local zoomed, active, activated_at = {}, {}, {}

local function has_block(node, id)
  if type(node) ~= "table" then return false end
  if node.block_id == id then return true end
  for _, child in pairs(node) do
    if has_block(child, id) then return true end
  end
  return false
end

local function keep_zoom(session_id, view)
  local window
  for _, w in ipairs(view.windows or {}) do
    if w.window_id == view.active_window_id then
      window = w
    elseif w.zoomed_block_id then
      zoomed[w.window_id] = w.zoomed_block_id
    end
  end
  if window == nil then return end
  local id = window.window_id
  if active[session_id] ~= id then
    active[session_id], activated_at[session_id] = id, os.time()
  end
  local wanted = zoomed[id]
  if window.zoomed_block_id == nil and wanted and os.time() - activated_at[session_id] <= 1
    and has_block(window.layers, wanted) then
    rex.call("session.zoom_block", { session_id = session_id, block_id = wanted, zoom = true })
    return
  end
  zoomed[id] = window.zoomed_block_id
end

local function label_all()
  local i = 0
  for _, session in ipairs(rex.call("session.list").sessions or {}) do
    pcall(function()
      rex.call("session.attach", { session_id = session.session_id })
      local view = rex.session.view { session_id = session.session_id }
      if view then keep_zoom(session.session_id, view) end
      for _, window in ipairs(view and view.windows or {}) do
        i = i + 1
        local name = (window.label or ""):gsub("^[%l%d] · ", "")
        local label = tab_keys[i] and (tab_keys[i] .. " · " .. name) or name
        if label ~= window.label then
          rex.call("session.set_window_label", { session_id = session.session_id, window_id = window.window_id, label = label })
        end
      end
    end)
  end
end

-- Any tab change can shift letters in later sessions, so relabel everything.
-- session_view_changed covers reordering, which has no event of its own.
for _, event in ipairs { "window_created", "window_closed", "window_label_changed", "session_view_changed", "session_created", "session_closed" } do
  rex.on(event, label_all)
end

label_all()
