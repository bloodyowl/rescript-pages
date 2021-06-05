---
title: Simple API
---

**You only need two hooks** to access the data from your markdown files. At build time, the system knows what you read from your components.

```rescript
/* items */
Pages.useItem(collection, ~id)
/* collections */
Pages.useCollection(collection)
```
