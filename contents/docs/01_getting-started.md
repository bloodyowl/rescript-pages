---
title: Getting started
slug: getting-started
---

## Installation

```console
$ yarn add rescript-pages bs-css-emotion reason-react rescript-asyncdata
```

Add them to your `bsconfig.json` dependencies:

```diff
 "bs-dependencies": [
+  "rescript-pages",
+  "bs-css-emotion",
+  "reason-react",
+  "rescript-asyncdata"
 ]
```

## Contents

Create a directory for your contents, let's say `contents`. In this directory, you can create collection by adding directories:

```
contents
|_ blog
|_ pages
```

There, you have two collections, `blog` & `pages`. You can add markdown files in them.

The posts will be sorted by filename, but you can specify custom slugs.

## Configuration

You'll need to create a React component with the following signature:

```reason
@react.component
let make = (~url: ReasonReact.Router.url, ~config: Pages.config) => React.element
```

And then expose your application:

```js
/* This function takes the data store and returns an array of URLs to pre-render */
let getUrlsToPrerender = ({Pages.getAll: getAll}) =>
  Array.concatMany([["/"], getAll("docs")->Array.map(slug => `/docs/${slug}`), ["404.html"]])

let default = Pages.make(
  make, /* Your root React component */
  {
    siteTitle: "bloodyowl", /* Default title */
    siteDescription: "My site", /* Default description */
    mode: SPA, /* SPA (with JS) or Static (without JS) */
    distDirectory: "dist", /* Where to write the built file */
    baseUrl: "https://bloodyowl.io", /* Where the website lives */
    staticsDirectory: Some("public"), /* Assets to copy to the `distDirectory` root */
    paginateBy: 2,  /* Page size */
    variants: [
      {
        subdirectory: None,  /* Where to write in `distDirectory` */
        localeFile: None, /* JSON file containing locales */
        contentDirectory: "contents", /* Where to find markdown contents */
        getUrlsToPrerender: getUrlsToPrerender,
        getRedirectMap: Some(_ =>
          Js.Dict.fromArray([("old-url", "new-url")])
        ),
      },
    ],
  },
)
```
