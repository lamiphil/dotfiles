<%*
// Prompt for issue name
const issueName = await tp.system.prompt("Issue Title");
if (!issueName) {
    // If user cancels, keep default name and don't move
    return "";
}

// Move and rename file to Issues folder
await tp.file.move(`Issues/${issueName}`);
-%>
---
date:
status: open
tags:
  - issue
  - ongoing
---
# Description

# Logs
