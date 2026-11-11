-- Keeps each tab's Colemak-DH jump letter in its name ("a · dotfiles").
-- init.lua can't hook events in Rex Beta, so this runs as a separate
-- listener (`rex do --all`), started by the launch agent apply.sh installs.
local tab_keys = { "a", "r", "s", "t", "g", "m", "n", "e", "i", "o" }

local function label_tabs(session_id)
  rex.call("session.attach", { session_id = session_id })
  local view = rex.session.view { session_id = session_id }
  for i, window in ipairs(view and view.windows or {}) do
    local name = (window.label or ""):gsub("^%l · ", "")
    local label = tab_keys[i] and (tab_keys[i] .. " · " .. name) or name
    if label ~= window.label then
      rex.call("session.set_window_label", { session_id = session_id, window_id = window.window_id, label = label })
    end
  end
end

local function label_all()
  for _, session in ipairs(rex.call("session.list").sessions or {}) do
    pcall(label_tabs, session.session_id)
  end
end

-- session_view_changed covers reordering, which has no event of its own.
for _, event in ipairs { "window_created", "window_closed", "window_label_changed", "session_view_changed" } do
  rex.on(event, function(e)
    if e and e.session_id then label_tabs(e.session_id) end
  end)
end
-- session_created carries no session ID, so relabel everything.
rex.on("session_created", label_all)

label_all()
