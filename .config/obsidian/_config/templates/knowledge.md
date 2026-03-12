<%*
// Move and rename file to Knowledge & Ideas folder
await tp.file.move(`Atlas/New Knowledge`);
-%>
---
date: <% tp.date.now("YYYY-MM-DD") %>
tags:
  - knowledge
---