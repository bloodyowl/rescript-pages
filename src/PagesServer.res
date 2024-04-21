open Pages

type dirent
@send external isDirectory: dirent => bool = "isDirectory"
@send external isFile: dirent => bool = "isFile"
@get external name: dirent => string = "name"
@module("fs") external readdirSync: (string, {..}) => array<dirent> = "readdirSync"
@module("fs") external readFileSync: (string, @as("utf8") _) => string = "readFileSync"
@val external cwd: unit => string = "process.cwd"
@module("path") external join: (string, string) => string = "join"
@module("path") external resolve: (string, string) => string = "resolve"
@module("path") external join3: (string, string, string) => string = "join"
@module("path") external basename: (string, string) => string = "basename"
@module("path") external extname: string => string = "extname"
@module("front-matter")
external frontMatter: string => {"attributes": 'a, "body": string} = "default"
type config = {
  "html": bool,
  "langPrefix": string,
  "xhtmlOut": bool,
  "highlight": (string, Nullable.t<string>) => string,
}

module ReactDOMServer = {
  @module("react-dom/server")
  external renderToString: React.element => string = "renderToString"

  @module("react-dom/server")
  external renderToStaticMarkup: React.element => string = "renderToStaticMarkup"
}

external directionAsString: direction => string = "%identity"

type remarkable
type remarkablePlugin

@new @module("remarkable")
external remarkable: (string, config) => remarkable = "Remarkable"
@send external render: (remarkable, string) => string = "render"
@send external use: (remarkable, remarkablePlugin) => unit = "use"

@module("remarkable/dist/cjs/linkify.js")
external linkify: remarkablePlugin = "linkify"

@module("highlight.js") @scope("default")
external highlight: (~lang: Nullable.t<string>, string) => {"value": string} = "highlight"
@module("highlight.js") @scope("default")
external highlightAuto: string => {"value": string} = "highlightAuto"

type hjs
type language

@module("highlight.js") external hjs: hjs = "default"
@module("reason-highlightjs") external reason: language = "default"
@module("./rescript-highlightjs.cjs") external rescript: language = "default"

@send
external registerLanguage: (hjs, string, language) => unit = "registerLanguage"

hjs->registerLanguage("reason", reason)
hjs->registerLanguage("rescript", rescript)

type emotionServer
type emotionCache
@module("@emotion/server/create-instance/dist/emotion-server-create-instance.cjs.js")
@scope("default")
external createEmotionServer: emotionCache => emotionServer = "default"
@get external getEmotionCache: Pages.emotion => emotionCache = "cache"

@send
external renderStylesToString: (emotionServer, string) => string = "renderStylesToString"

let remarkable = remarkable(
  "full",
  {
    "html": true,
    "xhtmlOut": true,
    "langPrefix": "hljs language-",
    "highlight": (code, lang) => {
      if lang == Nullable.undefined {
        code
      } else {
        try {highlight(~lang, code)["value"]} catch {
        | _ => highlightAuto(code)["value"]
        }
      }
    },
  },
)
remarkable->use(linkify)

let getCollectionItem = (slug, path) => {
  let file = readFileSync(path)
  let parsed = frontMatter(file)
  let meta: Dict.t<JSON.t> = parsed["attributes"]
  let truncationIndex = parsed["body"]->String.indexOf("<!--truncate-->")
  let truncationIndex = truncationIndex == -1 ? 250 : truncationIndex
  let body = render(remarkable, parsed["body"])
  let summary = render(remarkable, parsed["body"]->String.slice(~start=0, ~end=truncationIndex))
  let item = {
    slug: meta
    ->Dict.get("slug")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr(slug),
    filename: slug,
    title: meta
    ->Dict.get("title")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("Untitled"),
    date: meta
    ->Dict.get("date")
    ->Option.map(String.make)
    ->Option.map(Date.fromString)
    ->Option.map(Date.toUTCString),
    draft: meta
    ->Dict.get("draft")
    ->Option.flatMap(JSON.Decode.bool)
    ->Option.getOr(false),
    meta,
    body,
  }
  let listItem = {
    slug: meta
    ->Dict.get("slug")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr(slug),
    filename: slug,
    title: meta
    ->Dict.get("title")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("Untitled"),
    date: meta
    ->Dict.get("date")
    ->Option.map(String.make)
    ->Option.map(Date.fromString)
    ->Option.map(Date.toUTCString),
    draft: meta
    ->Dict.get("draft")
    ->Option.flatMap(JSON.Decode.bool)
    ->Option.getOr(false),
    meta,
    summary,
  }
  (item, listItem)
}

let getCollectionItems = path => {
  readdirSync(path, {"withFileTypes": true})
  ->Array.filter(isFile)
  ->Array.filter(item => extname(item->name) == ".md")
  ->Array.map(item => {
    let slug = basename(item->name, ".md")
    (slug, getCollectionItem(slug, join(path, item->name)))
  })
  ->Belt.Map.String.fromArray
}

let getCollections = config => {
  readdirSync(join(cwd(), config.contentDirectory), {"withFileTypes": true})
  ->Array.filter(isDirectory)
  ->Array.map(item => (
    item->name,
    getCollectionItems(join3(cwd(), config.contentDirectory, item->name)),
  ))
  ->Belt.Map.String.fromArray
}

let paginate = (array, paginateBy) => {
  let chunkTotal =
    array->Array.length / paginateBy + (mod(array->Array.length, paginateBy) > 0 ? 1 : 0)
  Belt.Array.range(1, chunkTotal)->Array.reduce(Belt.Map.Int.empty, (acc, chunkIndex) => {
    acc->Belt.Map.Int.set(
      chunkIndex,
      {
        hasPreviousPage: chunkIndex > 1,
        hasNextPage: chunkIndex < chunkTotal,
        totalCount: array->Array.length,
        items: array->Array.slice(
          ~start=(chunkIndex - 1) * paginateBy,
          ~end=(chunkIndex - 1) * paginateBy - paginateBy,
        ),
      },
    )
  })
}

let all = array => {
  {
    hasPreviousPage: false,
    hasNextPage: false,
    totalCount: array->Array.length,
    items: array,
  }
}

type values = {
  lists: Belt.Map.String.t<Belt.Map.String.t<Belt.Map.Int.t<paginated<listItem>>>>,
  items: Belt.Map.String.t<Belt.Map.String.t<item>>,
}

module Store = {
  let getAll = (store: values, collection) => {
    store.items
    ->Belt.Map.String.get(collection)
    ->Option.map(x => Belt.Map.String.keysToArray(x))
    ->Option.getOr([])
  }
  let getAllItems = (store: values, collection) => {
    store.items
    ->Belt.Map.String.get(collection)
    ->Option.map(x => Belt.Map.String.valuesToArray(x))
    ->Option.getOr([])
  }
  let getPages = (store: values, collection) => {
    store.lists
    ->Belt.Map.String.get(collection)
    ->Option.flatMap(items => items->Belt.Map.String.get(#desc->directionAsString))
    ->Option.map(x => Belt.Map.Int.keysToArray(x))
    ->Option.map(array => array->Array.sliceToEnd(~start=1))
    ->Option.getOr([])
  }
}

@module("react-helmet") @scope("Helmet")
external renderStatic: unit => {
  "base": string,
  "bodyAttributes": string,
  "htmlAttributes": string,
  "link": string,
  "meta": string,
  "noscript": string,
  "script": string,
  "style": string,
  "title": string,
} = "renderStatic"

let joinUrl = (s1, s2) =>
  `${s1}/${s2}`
  ->String.replaceRegExp(%re("/:\/\//g"), "__PROTOCOL__")
  ->String.replaceRegExp(%re("/\/+/g"), "/")
  ->String.replaceRegExp(%re("/__PROTOCOL__/g"), "://")

let renderRssItem = (config, variant, item: listItem, url) => {
  let link = switch variant.subdirectory {
  | Some(subdir) => joinUrl(config.baseUrl, join(subdir, url))
  | None => joinUrl(config.baseUrl, url)
  }
  let date = item.date->Option.map(date => `\n      <pubDate>${date}</pubDate>`)->Option.getOr("")
  `<item>
      <title><![CDATA[${item.title}]]></title>
      <link>${link}</link>
      <guid isPermaLink="false">${item.slug}</guid>${date}
   </item>`
}

let wrapRssFeed = (config, feedUrl, items) => {
  `<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
  <channel>
    <title><![CDATA[${config.siteTitle}]]></title>
    <description><![CDATA[${config.siteDescription}]]></description>
    <link>${config.baseUrl}</link>
    <lastBuildDate>${Date.make()->Date.toUTCString}</lastBuildDate>
    <atom:link href="${joinUrl(config.baseUrl, feedUrl)}" rel="self" type="application/rss+xml"/>
    ${items}
  </channel>
</rss>`
}

let sitemap = urls => {
  let urls = urls->Array.map(url => `<url><loc>${url}</loc></url>`)->Array.join("\n  ")
  `<?xml version="1.0" encoding="utf-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">
  ${urls}
</urlset>`
}

type url = {pathname: string}
@new external nodeUrl: string => url = "URL"

type processEnv
@val external processEnv: processEnv = "process.env"
@set external setPagesPath: (processEnv, string) => unit = "PAGES_PATH"
@set external setPagesRoot: (processEnv, string) => unit = "PAGES_ROOT"

@val external importJs: string => Promise.t<'a> = "import"

let getFiles = (config, readFileSync, mode) => {
  config.variants
  ->Array.reduce(Promise.resolve((Belt.Map.String.empty, Belt.Set.String.empty)), (
    promise,
    variant,
  ) => {
    promise->Promise.then(((map, set)) => {
      let directory = join(
        cwd(),
        switch variant.subdirectory {
        | Some(subdirectory) => join(config.distDirectory, subdirectory)
        | None => config.distDirectory
        },
      )
      let webpackHtml = switch config.mode {
      | SPA => readFileSync(join(directory, "_source.html"), "utf8")
      | Static => ""
      }
      setPagesPath(
        processEnv,
        switch variant.subdirectory {
        | Some(subdir) => join(nodeUrl(config.baseUrl).pathname, subdir)
        | None => nodeUrl(config.baseUrl).pathname
        },
      )
      setPagesRoot(processEnv, nodeUrl(config.baseUrl).pathname)
      importJs(join(directory, "_entry.mjs?") ++ Date.now()->Float.toString)->Promise.then(
        value => {
          switch value["default"]["exports"]["default"] {
          | Some({app, provider, container, emotion}) =>
            let server = createEmotionServer(emotion->getEmotionCache)
            let collections = getCollections(variant)
            let now = Date.now()
            let collections = switch mode {
            | #development => collections
            | #production =>
              collections->Belt.Map.String.map(
                values => {
                  values
                  ->Belt.Map.String.toArray
                  ->Array.filter(
                    ((_key, (item, _))) =>
                      switch item {
                      | {draft: true} => false
                      | {date: Some(date)} => Date.fromString(date)->Date.getTime < now
                      | _ => true
                      },
                  )
                  ->Belt.Map.String.fromArray
                },
              )
            }
            let store =
              collections
              ->Belt.Map.String.toArray
              ->Array.reduce(
                {lists: Belt.Map.String.empty, items: Belt.Map.String.empty},
                (acc, (collection, collectionItems)) => {
                  let items =
                    collectionItems
                    ->Belt.Map.String.map(((item, _listItem)) => item)
                    ->Belt.Map.String.valuesToArray
                    ->Array.map(item => (item.slug, item))
                    ->Belt.Map.String.fromArray
                  let listItems =
                    collectionItems
                    ->Belt.Map.String.valuesToArray
                    ->Array.map(((_item, listItem)) => listItem)
                  let descendendingListItems = listItems
                  descendendingListItems->Array.reverse
                  let ascending =
                    paginate(listItems, config.paginateBy)->Belt.Map.Int.set(0, all(listItems))
                  let decending =
                    paginate(descendendingListItems, config.paginateBy)->Belt.Map.Int.set(
                      0,
                      all(descendendingListItems),
                    )

                  {
                    lists: acc.lists->Belt.Map.String.set(
                      collection,
                      Belt.Map.String.fromArray([
                        (#asc->directionAsString, ascending),
                        (#desc->directionAsString, decending),
                      ]),
                    ),
                    items: acc.items->Belt.Map.String.set(collection, items),
                  }
                },
              )

            let itemUsageMap = Belt.MutableMap.String.make()
            let prerenderedPages =
              variant.getUrlsToPrerender({
                getAll: collection => Store.getAll(store, collection),
                getAllItems: collection => Store.getAllItems(store, collection),
                getPages: collection => Store.getPages(store, collection),
              })
              ->Array.map(
                url => (
                  switch variant.subdirectory {
                  | Some(subdir) => join3(nodeUrl(config.baseUrl).pathname, subdir, url)
                  | None => join(nodeUrl(config.baseUrl).pathname, url)
                  },
                  switch variant.subdirectory {
                  | Some(subdir) => join(subdir, url)
                  | None => url
                  },
                ),
              )
              ->Array.map(
                ((serverUrl, filePath)) => {
                  let context: Context.t = {
                    lists: store.lists->Belt.Map.String.map(
                      collection =>
                        collection->Belt.Map.String.map(
                          sortedCollection =>
                            sortedCollection->Belt.Map.Int.map(items => AsyncData.Done(Ok(items))),
                        ),
                    ),
                    items: store.items->Belt.Map.String.map(
                      collection =>
                        collection->Belt.Map.String.map(items => AsyncData.Done(Ok(items))),
                    ),
                    listsRequests: Belt.MutableMap.String.make(),
                    itemsRequests: Belt.MutableMap.String.make(),
                  }
                  let path = switch serverUrl {
                  | "" | "/" => list{}

                  | _ =>
                    let serverUrl =
                      serverUrl->String.startsWith("/")
                        ? serverUrl->String.sliceToEnd(~start=1)
                        : serverUrl

                    let serverUrl = switch String.get(serverUrl, String.length(serverUrl) - 1) {
                    | Some("/") => String.slice(~start=0, ~end=-1, serverUrl)
                    | _ => serverUrl
                    }
                    serverUrl->String.split("/")->List.fromArray
                  }
                  let url: RescriptReactRouter.url = {
                    path,
                    hash: "",
                    search: "",
                  }
                  let html = renderStylesToString(
                    server,
                    ReactDOMServer.renderToString({
                      React.createElement(
                        provider,
                        {
                          value: Some(context),
                          serverUrl: url,
                          config,
                          children: React.createElement(container, {app, config}),
                        },
                      )
                    }),
                  )

                  let initialData: Context.t = {
                    lists: context.listsRequests
                    ->Belt.MutableMap.String.toArray
                    ->Array.reduce(
                      Belt.Map.String.empty,
                      (acc, (collectionKey, collectionDirections)) =>
                        acc->Belt.Map.String.update(
                          collectionKey,
                          _ => Some(
                            collectionDirections
                            ->Belt.Map.String.toArray
                            ->Array.reduce(
                              Belt.Map.String.empty,
                              (acc, (direction, pagesToRender)) =>
                                acc->Belt.Map.String.update(
                                  direction,
                                  _ =>
                                    context.lists
                                    ->Belt.Map.String.get(collectionKey)
                                    ->Option.flatMap(value => value->Belt.Map.String.get(direction))
                                    ->Option.flatMap(
                                      pages => Some(
                                        pagesToRender->Belt.Set.Int.reduce(
                                          Belt.Map.Int.empty,
                                          (acc, key) =>
                                            acc->Belt.Map.Int.update(
                                              key,
                                              _ => pages->Belt.Map.Int.get(key),
                                            ),
                                        ),
                                      ),
                                    ),
                                ),
                            ),
                          ),
                        ),
                    ),
                    items: context.itemsRequests
                    ->Belt.MutableMap.String.toArray
                    ->Array.reduce(
                      Belt.Map.String.empty,
                      (acc, (collectionKey, idsToRender)) =>
                        acc->Belt.Map.String.update(
                          collectionKey,
                          _ =>
                            context.items
                            ->Belt.Map.String.get(collectionKey)
                            ->Option.flatMap(
                              pages => Some(
                                idsToRender->Belt.Set.String.reduce(
                                  Belt.Map.String.empty,
                                  (acc, key) => {
                                    itemUsageMap->Belt.MutableMap.String.set(
                                      serverUrl,
                                      (collectionKey, key),
                                    )
                                    acc->Belt.Map.String.update(
                                      key,
                                      _ => pages->Belt.Map.String.get(key),
                                    )
                                  },
                                ),
                              ),
                            ),
                        ),
                    ),
                    listsRequests: Belt.MutableMap.String.make(),
                    itemsRequests: Belt.MutableMap.String.make(),
                  }
                  let initialData =
                    initialData
                    ->Js.Json.serializeExn
                    ->(Js.String.replaceByRe(%re("/</g"), `\\u003c`, _))
                  let helmet = renderStatic()
                  let errorPageMarker =
                    filePath === "404.html" || filePath->Js.String2.endsWith("/404.html")
                      ? `<script>window.PAGES_BOOT_MODE="render";</script>`
                      : `<script>window.PAGES_BOOT_MODE="hydrate";</script>`
                  (
                    filePath,
                    `<!DOCTYPE html><html ${helmet["htmlAttributes"]}><head>${helmet["title"]}${helmet["base"]}${helmet["meta"]}${helmet["link"]}${helmet["style"]}${helmet["script"]}${errorPageMarker}</head><div id="root">${html}</div><script id="initialData" type="text/data">${initialData}</script>${webpackHtml}</html>`,
                  )
                },
              )
              ->Belt.Map.String.fromArray

            let redirects =
              switch variant.getRedirectMap {
              | Some(getRedirectMap) =>
                getRedirectMap({
                  getAll: collection => Store.getAll(store, collection),
                  getAllItems: collection => Store.getAllItems(store, collection),
                  getPages: collection => Store.getPages(store, collection),
                })
              | None => Js.Dict.empty()
              }
              ->Js.Dict.entries
              ->Array.map(
                ((fromUrl, toUrl)) => (
                  switch variant.subdirectory {
                  | Some(subdir) => join(subdir, fromUrl)
                  | None => fromUrl
                  },
                  switch variant.subdirectory {
                  | Some(subdir) => join(subdir, toUrl)
                  | None => toUrl
                  },
                ),
              )
              ->Array.map(
                ((fromUrl, toUrl)) => {
                  let html = ReactDOMServer.renderToStaticMarkup(<Redirect url=toUrl />)
                  let helmet = renderStatic()
                  (
                    fromUrl,
                    `<!DOCTYPE html><html ${helmet["htmlAttributes"]}><head>${helmet["title"]}${helmet["base"]}${helmet["meta"]}${helmet["link"]}${helmet["style"]}${helmet["script"]}</head><div id="root">${html}</div></html>`,
                  )
                },
              )
              ->Belt.Map.String.fromArray

            let lists =
              store.lists
              ->Belt.Map.String.toArray
              ->Array.reduce(
                Belt.Map.String.empty,
                (acc, (collectionName, collection)) =>
                  collection
                  ->Belt.Map.String.toArray
                  ->Array.reduce(
                    acc,
                    (acc, (direction, sortedCollection)) =>
                      sortedCollection
                      ->Belt.Map.Int.toArray
                      ->Array.reduce(
                        acc,
                        (acc, (page, items)) =>
                          acc->Belt.Map.String.set(
                            switch variant.subdirectory {
                            | Some(subdirectory) =>
                              `/${subdirectory}/api/${collectionName}/pages/${direction}/${page->Int.toString}.json`
                            | None =>
                              `/api/${collectionName}/pages/${direction}/${page->Int.toString}.json`
                            },
                            items->Js.Json.serializeExn,
                          ),
                      ),
                  ),
              )
            let feeds =
              store.lists
              ->Belt.Map.String.toArray
              ->Array.reduce(
                Belt.Map.String.empty,
                (acc, (collectionName, collection)) =>
                  collection
                  ->Belt.Map.String.toArray
                  ->Array.reduce(
                    acc,
                    (acc, (direction, sortedCollection)) =>
                      sortedCollection
                      ->Belt.Map.Int.get(0)
                      ->Option.map(
                        page => {
                          let url = switch variant.subdirectory {
                          | Some(subdirectory) =>
                            `/${subdirectory}/api/${collectionName}/feeds/${direction}/feed.xml`
                          | None => `/api/${collectionName}/feeds/${direction}/feed.xml`
                          }
                          acc->Belt.Map.String.set(
                            url,
                            {
                              let items =
                                page.items
                                ->Array.filterMap(
                                  item => {
                                    itemUsageMap
                                    ->Belt.MutableMap.String.toArray
                                    ->Array.find(
                                      ((_, (collection, key))) => {
                                        collection == collectionName && key == item.slug
                                      },
                                    )
                                    ->Option.map(
                                      ((url, _)) => renderRssItem(config, variant, item, url),
                                    )
                                  },
                                )
                                ->Js.Array2.joinWith("\n    ")
                              wrapRssFeed(config, url, items)
                            },
                          )
                        },
                      )
                      ->Option.getOr(acc),
                  ),
              )
            let items =
              store.items
              ->Belt.Map.String.toArray
              ->Array.reduce(
                Belt.Map.String.empty,
                (acc, (collectionName, collection)) =>
                  collection
                  ->Belt.Map.String.toArray
                  ->Array.reduce(
                    acc,
                    (acc, (id, item)) =>
                      acc->Belt.Map.String.set(
                        switch variant.subdirectory {
                        | Some(subdirectory) =>
                          `/${subdirectory}/api/${collectionName}/items/${id}.json`
                        | None => `/api/${collectionName}/items/${id}.json`
                        },
                        item->Js.Json.serializeExn,
                      ),
                  ),
              )

            Promise.resolve((
              map->Belt.Map.String.merge(
                prerenderedPages->Belt.Map.String.mergeMany(
                  Array.concatMany(
                    [],
                    [
                      lists->Belt.Map.String.toArray,
                      items->Belt.Map.String.toArray,
                      feeds->Belt.Map.String.toArray,
                      redirects->Belt.Map.String.toArray,
                    ],
                  ),
                ),
                (_, a, b) =>
                  switch (a, b) {
                  | (_, Some(b)) => Some(b)
                  | (Some(a), _) => Some(a)
                  | (None, None) => None
                  },
              ),
              set->Belt.Set.String.union(
                prerenderedPages
                ->Belt.Map.String.keysToArray
                ->Array.map(url => joinUrl(config.baseUrl, url))
                ->Belt.Set.String.fromArray,
              ),
            ))
          | None => Promise.resolve((map, set))
          }
        },
      )
    })
  })
  ->Promise.then(((files, pages)) => {
    Promise.resolve(
      files
      ->Belt.Map.String.set(`/sitemap.xml`, sitemap(pages->Belt.Set.String.toArray))
      ->Belt.Map.String.toArray
      ->Array.map(((filePath, value)) => {
        let filePath = join(config.distDirectory, filePath)
        let filePath =
          filePath->String.startsWith("/") ? filePath->String.sliceToEnd(~start=1) : filePath
        let filePath =
          extname(filePath) != ""
            ? filePath
            : filePath ++ (filePath->String.endsWith("/") ? "" : "/") ++ "index.html"
        (filePath, value)
      }),
    )
  })
}

type plugin
@new @module("html-webpack-plugin") external htmlPlugin: {..} => plugin = "default"
@new @module("script-ext-html-webpack-plugin") external scriptPlugin: {..} => plugin = "default"
@new @module("inline-translations-webpack-plugin")
external inlineTranslationPlugin: Js.Null.t<Js.Json.t> => plugin = "default"
@new @module("copy-webpack-plugin") external copyPlugin: {..} => plugin = "default"
@new @module("webpack") @scope("default") external definePlugin: {..} => plugin = "DefinePlugin"
@new @module("webpack") @scope("default") external bannerPlugin: {..} => plugin = "BannerPlugin"

type mode = [#development | #production]

@module("path") external dirname: string => string = "dirname"
@module("url") external fileURLToPath: url => string = "fileURLToPath"
@val external importMetaUrl: url = "import.meta.url"

let dirname = dirname(fileURLToPath(importMetaUrl))

let getWebpackConfig = (config, mode: mode, entry) => {
  config.variants->Array.reduce([], (acc, variant) => {
    acc->Array.concat([
      {
        "entry": entry,
        "mode": mode,
        "devtool": false,
        "target": "node",
        "resolve": {
          "modules": [resolve(dirname, "../node_modules"), join(cwd(), "node_modules")],
          "alias": Js.Dict.fromArray([("@emotion/css$", join(dirname, "emotion.mjs"))]),
        },
        "experiments": {
          "outputModule": false,
        },
        "output": {
          "libraryTarget": Nullable.make("commonjs"),
          "path": switch variant.subdirectory {
          | Some(subdir) => join3(cwd(), config.distDirectory, subdir)
          | None => join(cwd(), config.distDirectory)
          },
          "publicPath": switch variant.subdirectory {
          | Some(subdir) => join(nodeUrl(config.baseUrl).pathname, subdir)
          | None => nodeUrl(config.baseUrl).pathname
          },
          "filename": `_entry.mjs`,
          "chunkFilename": `public/chunks/[contenthash].js`,
        },
        "plugins": [
          definePlugin({
            "process.env.PAGES_PATH": switch variant.subdirectory {
            | Some(subdir) => `"${join(nodeUrl(config.baseUrl).pathname, subdir)}"`
            | None => `"${nodeUrl(config.baseUrl).pathname}"`
            },
            "process.env.PAGES_ROOT": `"${nodeUrl(config.baseUrl).pathname}"`,
          }),
          inlineTranslationPlugin(
            variant.localeFile
            ->Option.map(readFileSync)
            ->Option.map(x => JSON.parseExn(x))
            ->Js.Null.fromOption,
          ),
          bannerPlugin({
            "banner": `import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let module = {exports: {}};
let exports = module.exports;
export default module;`,
            "raw": true,
          }),
        ],
        "externals": Js.Dict.fromArray([
          ("react", "commonjs react"),
          ("react-dom", "commonjs react-dom"),
          ("react-dom-server", "commonjs react-dom-server"),
          ("react-helmet", `commonjs react-helmet`),
          ("bs-platform", "commonjs bs-platform"),
        ]),
      },
      {
        "entry": entry,
        "mode": mode,
        "devtool": false,
        "target": "web",
        "resolve": {
          "modules": [resolve(dirname, "../node_modules"), join(cwd(), "node_modules")],
          "alias": Js.Dict.fromArray([("@emotion/css$", join(dirname, "emotion.mjs"))]),
        },
        "experiments": {
          "outputModule": false,
        },
        "output": {
          "libraryTarget": Nullable.undefined,
          "path": switch variant.subdirectory {
          | Some(subdir) => join3(cwd(), config.distDirectory, subdir)
          | None => join(cwd(), config.distDirectory)
          },
          "publicPath": switch variant.subdirectory {
          | Some(subdir) => join(nodeUrl(config.baseUrl).pathname, subdir)
          | None => nodeUrl(config.baseUrl).pathname
          },
          "filename": `public/[name].[fullhash].js`,
          "chunkFilename": `public/chunks/[contenthash].js`,
        },
        "externals": Js.Dict.empty(),
        "plugins": [
          htmlPlugin({
            "filename": `_source.html`,
            "templateContent": "",
          }),
          definePlugin({
            "process.env.PAGES_PATH": switch variant.subdirectory {
            | Some(subdir) => `"${join(nodeUrl(config.baseUrl).pathname, subdir)}"`
            | None => `"${nodeUrl(config.baseUrl).pathname}"`
            },
            "process.env.PAGES_ROOT": `"${nodeUrl(config.baseUrl).pathname}"`,
          }),
          scriptPlugin({
            "defaultAttribute": "defer",
          }),
          inlineTranslationPlugin(
            variant.localeFile
            ->Option.map(readFileSync)
            ->Option.map(x => JSON.parseExn(x))
            ->Js.Null.fromOption,
          ),
        ]->Array.concat(
          switch config.staticsDirectory {
          | Some(staticsDirectory) => [
              copyPlugin({
                "patterns": [{"from": "**/*", "to": "", "context": join(cwd(), staticsDirectory)}],
              }),
            ]
          | None => []
          },
        ),
      },
    ])
  })
}
