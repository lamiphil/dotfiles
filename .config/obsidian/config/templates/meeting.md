<%*
// Prompt for meeting name
const meetingName = await tp.system.prompt("Meeting Title");
if (!meetingName) {
    // If user cancels, keep default name and don't move
    return "";
}

// Get date from frontmatter or use today
const date = tp.frontmatter.date || tp.date.now("YYYY-MM-DD");
const year = tp.date.now("YYYY", 0, date);
const monthNum = tp.date.now("MM", 0, date);
const monthName = tp.date.now("MMMM", 0, date);

// Format filename: YYYY-MM-DD - Meeting Name
const datePrefix = tp.date.now("YYYY-MM-DD", 0, date);
const formattedName = `${datePrefix} - ${meetingName}`;

// Build target path: Meetings/{YYYY}/{MM - MonthName}/
const targetPath = `Meetings/${year}/${monthNum} - ${monthName}`;

// Move and rename file
await tp.file.move(`${targetPath}/${formattedName}`);
-%>
---
date: <% tp.date.now("YYYY-MM-DD") %>
tags:
  - meeting
---
## Notes
