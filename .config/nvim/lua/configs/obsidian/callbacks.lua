local utils = require("configs.obsidian.utils")
local M = {}
print("📌 Callbacks loaded")

-- M.callbacks = {
--   enter_note = function(client, note)
--     local note_path = tostring(note.path)
--     local opened_note_filename = note_path:match("([^/]+)%.md$")
--
--     if opened_note_filename then
--       print("📄 Entered note:", opened_note_filename)
--
--       -- Check if the note is a daily note
--       local is_daily_note = utils.is_daily_note(note_path)
--       if is_daily_note then
--         print("🗓 Detected today's daily note.")
--
--         local previous_note_path = utils.get_previous_day_filename(note_path)
--         if vim.fn.filereadable(previous_note_path) == 1 then
--           local unfinished_todos = utils.get_unfinished_todos(previous_note_path)
--           utils.append_todos_to_today(note_path, unfinished_todos)
--           print("✅ Moved unfinished TODOs from yesterday.")
--         else
--           print("⚠ No previous daily note found.")
--         end
--       end
--     else
--       print("⚠ Could not extract note filename.")
--     end
--   end
-- }

return M
