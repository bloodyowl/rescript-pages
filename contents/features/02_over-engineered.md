---
title: React-powered
---

When the client boots, there's **no subsequent page reload**, it only fetches the missing data to navigate to the next page (but it works without JS!).

```reason
@react.component
let make = (~url, ~config) => {
  /* your app */
}
```
