---
title: HTML customization
slug: html-customization
---

You can add meta tags to your pages using `<Pages.Head />`:

```reason
<Pages.Head>
  <title> {"My title"->React.string} </title>
  <meta name="description" content="Helloworld">
</Pages.Head>
```

You can also add scripts & style elements:

```reason
<Pages.Head>
  <script> {`console.log("hello")`->React.string} </script>
  <style> {`body {padding: 0}`->React.string} </style>
</Pages.Head>
```
