---
name: code-review
description: Review selected code or recent changes for bugs, security issues, performance problems, and readability. Use when the user asks for a review, a second pair of eyes, or feedback on a diff.
---

Review the code I've selected or the recent changes for:

- Potential bugs and unhandled edge cases
- Security concerns (injection, unsafe input handling, leaked secrets)
- Performance issues (unnecessary re-renders, N+1 queries, heavy work on the main thread)
- Readability and naming

Be concise and actionable. Group findings by severity (blocking / nice-to-have) and reference specific lines. Don't rewrite everything — point to the smallest change that fixes each issue.
