---
title: Consuming content
slug: consuming-content
---

You have two hooks available to fetch content:

## Items

```rescript
Pages.useItem("collection", ~id="itemId")
```

Items have the following type:

```rescript
type item = {
  slug: string,
  filename: string,
  title: string,
  date: option<string>,
  draft: bool,
  meta: Js.Dict.t<Js.Json.t>,
  body: string,
}
```

## Collections

```rescript
Pages.useCollection("collection")
```

By default, `useCollection` returns **all** items, but it paginates once you provide a `page` param.

```rescript
Pages.useCollection("collection", ~page=1)
```

By default, all collections are sorted alphabetically on the filename by descending order (which is the most common for blogs, where you want the latest content first), but you can change that with the `direction` param:

```rescript
Pages.useCollection("collection", ~page=1, ~direction=#asc)
```

Collections have the following type:

```rescript
type listItem = {
  slug: string,
  filename: string,
  title: string,
  date: option<string>,
  draft: bool,
  meta: Js.Dict.t<Js.Json.t>,
  summary: string,
}

type paginated = {
  hasPreviousPage: bool,
  hasNextPage: bool,
  items: array<listItem>,
}
```


## AsyncData

As the server fetch is asynchronous, the two hooks return [AsyncData](https://github.com/bloodyowl/rescript-asyncdata) values:

```rescript
switch blocks {
| NotAsked
| Loading => "Loading"->React.string
| Done(Error(_)) => "Error"->React.string
| Done(Ok(value)) => /* Do something with `value` */
}
```

To help you reprensenting those states, `Pages` provides:

- `<ActivityIndicator />`
- `<ErrorIndicator />`
