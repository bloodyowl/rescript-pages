---
title: Styling
slug: styling
---

ReScript pages automatically pre-renders your [bs-css-emotion](https://github.com/reasonml-labs/bs-css).

You can create styles:

```reason
 module Styles = {
  open CssJs
  let container = style(.[display(flexBox), flexDirection(row)])
  let column = style(.[
    width(250->px),
    boxSizing(borderBox),
    padding2(~v=20->px, ~h=10->px),
    flexGrow(0.0),
    flexShrink(0.0),
  ])
  let body = style(.[flexGrow(1.0), flexShrink(1.0)])
  let link = style(.[color(currentColor), textDecoration(none), display(block), padding(10->px)])
  let activeLink = style(.[fontWeight(bold)])
}
```

And use them using in `className` props!
