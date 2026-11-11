-- Keeps each tab's Colemak-DH jump letter in its name ("a · dotfiles").
-- Letters run across all sessions in order, matching Rex's global tab numbers.
-- init.lua can't hook events in Rex Beta, so this runs as a separate
-- listener (`rex do --all`), started by the launch agent apply.sh installs.
local tab_keys = { "a", "r", "s", "t", "g", "m", "n", "e", "i", "o", "1", "2", "3", "4", "5", "6", "7", "8", "9" }

local function label_all()
  local i = 0
  for _, session in ipairs(rex.call("session.list").sessions or {}) do
    pcall(function()
      rex.call("session.attach", { session_id = session.session_id })
      local view = rex.session.view { session_id = session.session_id }
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
