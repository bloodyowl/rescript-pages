---
title: Styling
slug: styling
---

ReScript pages automatically pre-renders your [emotion](https://emotion.sh/docs/introduction) styles.

You can write some basic bindings:

```rescript
@module("@emotion/css") external css: {..} => string = "css"
@module("@emotion/css") external keyframes: {..} => string = "keyframes"
@module("@emotion/css") external cx: array<string> => string = "cx"

@module("@emotion/css") external injectGlobal: string => unit = "injectGlobal"
```

You can create styles:

```rescript
let container = css({
  "display": "flex",
  "flexDirection": "row",
  "alignItems": "flex-start",
  "flexGrow": 1,
  "position": "relative",
  "@media (max-width: 600px)": {"flexDirection": "column-reverse"},
})

let body = css({
  "width": 1,
  "flexGrow": 1,
  "flexShrink": 1,
  "display": "flex",
  "flexDirection": "column",
  "padding": 10,
  "boxSizing": "border-box",
  "@media (max-width: 600px)": {"width": "100%"},
})
```

And use them using in `className` props!
