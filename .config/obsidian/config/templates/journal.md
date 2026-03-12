---
date: <% tp.date.now("YYYY-MM-DD") %>
tags:
  - journal
---
# {{date}}
## Todos


## Logs

### Meetings
```dataview
LIST
FROM "Meetings"
WHERE date = this.file.day
```

### Issues
```dataview
LIST
FROM "Issues"
WHERE file.mday = this.file.day
```