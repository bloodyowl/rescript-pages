---
title: Markdown
slug: markdown
---

## Metadata

```markdown
---
title: My title # your title
date: 2020-11-20 # publication date, the file will only appear in dev mode until that date
draft: true # draft mode, the file will only appear in dev mode if true
customField: "hello" # you can add as many string custom fields as you want
---

The body of your article
```

## Summary

You can choose where to cut the summary (information available in collections) by adding the following:

```html
In the summary

<!--truncate-->

Not in the summary
```

If not specified, it will cut at 250 characters.
