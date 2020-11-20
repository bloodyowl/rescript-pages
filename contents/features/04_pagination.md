---
title: Pagination
---

You define the page size in your config, the generator creates the correct paginated pages & API endpoints.

```reason
Pages.useCollection(
  collection,
  ~page=1,
  ~direction=#asc
)
```
