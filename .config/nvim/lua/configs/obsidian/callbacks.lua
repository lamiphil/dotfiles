local M = {}

M.callbacks = {
  open_note = function(client, note)
    local note_path = tostring(note.path)
    opened_note_filename = note_path:match("([^/]+)%.md$")

    if opened_note_filename then
        print("📄 Entered note:", opened_note_filename)
    else
        print("⚠ Could not extract  note filename.")
    end
  end
}

return M

