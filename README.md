# ReScript Pages

> Yet another static website generator

## Key features

- **Markdown collection based content**: Write markdown files in directories, the directories become _collections_, the files become _items_
- **Completely over-engineered**: generates a Single-Page-Application that kicks in after the initial load, loading the minimum delta to transition to the next page
- **Simple API**: you basically have two hooks to get data:
  - `useItem(collection, ~id)`, 
  - `useCollection(collection, ~page=1, ~direction=#desc)`
- **Pagination**: You define the page size in your config, the generator creates the correct pagination
- **RSS & Sitemap** generation
- **i18n support**

## Installation

```console
$ yarn add rescript-pages
```

## Usage

Create an entry file with a `default` export with your configuration:

```js
let default = Pages.make(
  App.make,
  {
    siteTitle: "Title",
    siteDescription: "Description",
    distDirectory: "dist",
    baseUrl: "https://example.url",
    staticsDirectory: Some("public"),
    paginateBy: 20,
    variants: [
      {
        subdirectory: None,
        localeFile: None,
        contentDirectory: "contents",
        getUrlsToPrerender: ({getAll, getPages}) =>
          Array.concatMany([
            ["/"],
            getAll("pages")->Array.map(slug => `/${slug}`),
            getAll("posts")->Array.map(slug => `/post/${slug}`),
            ["/posts"],
            getPages("posts")->Array.map(page => `/posts/${page->Int.toString}`),
            ["404.html"],
          ]),
      },
    ],
  },
)
```

We provide two commands:

- **start**: starts a dev server
- **build**: builds the website

```console
$ pages start entry.bs.js
$ pages build entry.bs.js
```
