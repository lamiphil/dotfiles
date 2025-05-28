local M = {}
local api = vim.api

-- TODO: Save .md file when leaving Insert mode

M.get_obsidian_client = function()
  -- Attempt to require the obsidian module
  local obsidian_ok, obsidian = pcall(require, "obsidian")
  if not obsidian_ok then
    print("⚠ obsidian.nvim is not available")
    return nil
  end

  -- Retrieve the client
  local client = obsidian.get_client()
  if not client then
    print("⚠ Could not get obsidian client")
    return nil
  end

  return client
end

M.get_current_workspace = function(note_path)
  local client = M.get_obsidian_client()
  if not client then
    print("⚠ Client is nil")
    return nil
  end
  print("Current path: " .. note_path)

  -- Retrieve the workspace module
  local Workspace = require("obsidian.workspace")

  -- Print all workspaces before finding the correct one
  print("📂 Available Workspaces: " .. vim.inspect(client.opts.workspaces))

  -- Get the current workspace based on the current working directory
  local current_workspace = Workspace.get_workspace_for_dir(note_path, client.opts.workspaces)

  -- Ensure current_workspace is valid before concatenating
  if current_workspace then
    print("Current workspace: " .. current_workspace.name)
    return current_workspace
  else
    print("⚠ No matching workspace found for the current directory")
    return nil
  end
end

return M
