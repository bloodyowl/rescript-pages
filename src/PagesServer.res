open! Belt
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
  "highlight": (string, Js.Undefined.t<string>) => string,
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
external highlight: (~lang: Js.Undefined.t<string>, string) => {"value": string} = "highlight"
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
      if lang == Js.undefined {
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
  let meta: Js.Dict.t<Js.Json.t> = parsed["attributes"]
  let truncationIndex = parsed["body"]->Js.String2.indexOf("<!--truncate-->")
  let truncationIndex = truncationIndex == -1 ? 250 : truncationIndex
  let body = render(remarkable, parsed["body"])
  let summary = render(remarkable, parsed["body"]->Js.String2.slice(~from=0, ~to_=truncationIndex))
  let item = {
    slug: meta
    ->Js.Dict.get("slug")
    ->Option.flatMap(Js.Json.decodeString)
    ->Option.getWithDefault(slug),
    filename: slug,
    title: meta
    ->Js.Dict.get("title")
    ->Option.flatMap(Js.Json.decodeString)
    ->Option.getWithDefault("Untitled"),
    date: meta
    ->Js.Dict.get("date")
    ->Option.map(Js.String.make)
    ->Option.map(Js.Date.fromString)
    ->Option.map(Js.Date.toUTCString),
    draft: meta
    ->Js.Dict.get("draft")
    ->Option.flatMap(Js.Json.decodeBoolean)
    ->Option.getWithDefault(false),
    meta,
    body,
  }
  let listItem = {
    slug: meta
    ->Js.Dict.get("slug")
    ->Option.flatMap(Js.Json.decodeString)
    ->Option.getWithDefault(slug),
    filename: slug,
    title: meta
    ->Js.Dict.get("title")
    ->Option.flatMap(Js.Json.decodeString)
    ->Option.getWithDefault("Untitled"),
    date: meta
    ->Js.Dict.get("date")
    ->Option.map(Js.String.make)
    ->Option.map(Js.Date.fromString)
    ->Option.map(Js.Date.toUTCString),
    draft: meta
    ->Js.Dict.get("draft")
    ->Option.flatMap(Js.Json.decodeBoolean)
    ->Option.getWithDefault(false),
    meta,
    summary,
  }
  (item, listItem)
}

let getCollectionItems = path => {
  readdirSync(path, {"withFileTypes": true})
  ->Array.keep(isFile)
  ->Array.keep(item => extname(item->name) == ".md")
  ->Array.map(item => {
    let slug = basename(item->name, ".md")
    (slug, getCollectionItem(slug, join(path, item->name)))
  })
  ->Map.String.fromArray
}

let getCollections = config => {
  readdirSync(join(cwd(), config.contentDirectory), {"withFileTypes": true})
  ->Array.keep(isDirectory)
  ->Array.map(item => (
    item->name,
    getCollectionItems(join3(cwd(), config.contentDirectory, item->name)),
  ))
  ->Map.String.fromArray
}

let paginate = (array, paginateBy) => {
  let chunkTotal =
    array->Array.length / paginateBy + (mod(array->Array.length, paginateBy) > 0 ? 1 : 0)
  Array.range(1, chunkTotal)->Array.reduce(Map.Int.empty, (acc, chunkIndex) => {
    acc->Map.Int.set(
      chunkIndex,
      {
        hasPreviousPage: chunkIndex > 1,
        hasNextPage: chunkIndex < chunkTotal,
        totalCount: array->Array.length,
        items: array->Array.slice(~offset=(chunkIndex - 1) * paginateBy, ~len=paginateBy),
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
  lists: Map.String.t<Map.String.t<Map.Int.t<paginated<listItem>>>>,
  items: Map.String.t<Map.String.t<item>>,
}

module Store = {
  let getAll = (store: values, collection) => {
    store.items
    ->Map.String.get(collection)
    ->Option.map(Map.String.keysToArray)
    ->Option.getWithDefault([])
  }
  let getAllItems = (store: values, collection) => {
    store.items
    ->Map.String.get(collection)
    ->Option.map(Map.String.valuesToArray)
    ->Option.getWithDefault([])
  }
  let getPages = (store: values, collection) => {
    store.lists
    ->Map.String.get(collection)
    ->Option.flatMap(items => items->Map.String.get(#desc->directionAsString))
    ->Option.map(Map.Int.keysToArray)
    ->Option.map(array => array->Array.sliceToEnd(1))
    ->Option.getWithDefault([])
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
  ->Js.String2.replaceByRe(%re("/:\/\//g"), "__PROTOCOL__")
  ->Js.String2.replaceByRe(%re("/\/+/g"), "/")
  ->Js.String2.replaceByRe(%re("/__PROTOCOL__/g"), "://")

let renderRssItem = (config, variant, item: listItem, url) => {
  let link = switch variant.subdirectory {
  | Some(subdir) => joinUrl(config.baseUrl, join(subdir, url))
  | None => joinUrl(config.baseUrl, url)
  }
  let date =
    item.date->Option.map(date => `\n      <pubDate>${date}</pubDate>`)->Option.getWithDefault("")
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
    <lastBuildDate>${Js.Date.make()->Js.Date.toUTCString}</lastBuildDate>
    <atom:link href="${joinUrl(config.baseUrl, feedUrl)}" rel="self" type="application/rss+xml"/>
    ${items}
  </channel>
</rss>`
}

let sitemap = urls => {
  let urls = urls->Array.map(url => `<url><loc>${url}</loc></url>`)->Js.Array2.joinWith("\n  ")
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

@val external importJs: string => Js.Promise.t<'a> = "import"

let getFiles = (config, readFileSync, mode) => {
  config.variants
  ->Array.reduce(Js.Promise.resolve((Map.String.empty, Set.String.empty)), (promise, variant) => {
    promise->(Js.Promise.then_(((map, set)) => {
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
        importJs(join(directory, "_entry.mjs?") ++ Js.Date.now()->Js.Float.toString)->(
          Js.Promise.then_(
            value => {
              switch value["default"]["exports"]["default"] {
              | Some({app, provider, container, emotion}) =>
                let server = createEmotionServer(emotion->getEmotionCache)
                let collections = getCollections(variant)
                let now = Js.Date.now()
                let collections = switch mode {
                | #development => collections
                | #production =>
                  collections->Map.String.map(
                    values => {
                      values
                      ->Map.String.toArray
                      ->Array.keep(
                        ((_key, (item, _))) =>
                          switch item {
                          | {draft: true} => false
                          | {date: Some(date)} => Js.Date.fromString(date)->Js.Date.getTime < now
                          | _ => true
                          },
                      )
                      ->Map.String.fromArray
                    },
                  )
                }
                let store =
                  collections
                  ->Map.String.toArray
                  ->Array.reduce(
                    {lists: Map.String.empty, items: Map.String.empty},
                    (acc, (collection, collectionItems)) => {
                      let items =
                        collectionItems
                        ->Map.String.map(((item, _listItem)) => item)
                        ->Map.String.valuesToArray
                        ->Array.map(item => (item.slug, item))
                        ->Map.String.fromArray
                      let listItems =
                        collectionItems
                        ->Map.String.valuesToArray
                        ->Array.map(((_item, listItem)) => listItem)
                      let descendendingListItems = listItems->Array.reverse
                      let ascending =
                        paginate(listItems, config.paginateBy)->Map.Int.set(0, all(listItems))
                      let decending =
                        paginate(descendendingListItems, config.paginateBy)->Map.Int.set(
                          0,
                          all(descendendingListItems),
                        )

                      {
                        lists: acc.lists->Map.String.set(
                          collection,
                          Map.String.fromArray([
                            (#asc->directionAsString, ascending),
                            (#desc->directionAsString, decending),
                          ]),
                        ),
                        items: acc.items->Map.String.set(collection, items),
                      }
                    },
                  )

                let itemUsageMap = MutableMap.String.make()
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
                        lists: store.lists->Map.String.map(
                          collection =>
                            collection->Map.String.map(
                              sortedCollection =>
                                sortedCollection->Map.Int.map(items => AsyncData.Done(Ok(items))),
                            ),
                        ),
                        items: store.items->Map.String.map(
                          collection =>
                            collection->Map.String.map(items => AsyncData.Done(Ok(items))),
                        ),
                        listsRequests: MutableMap.String.make(),
                        itemsRequests: MutableMap.String.make(),
                      }
                      let path = switch serverUrl {
                      | "" | "/" => list{}

                      | _ =>
                        let serverUrl =
                          serverUrl->Js.String2.startsWith("/")
                            ? serverUrl->Js.String2.sliceToEnd(~from=1)
                            : serverUrl

                        let serverUrl = switch Js.String2.get(
                          serverUrl,
                          Js.String2.length(serverUrl) - 1,
                        ) {
                        | "/" => Js.String.slice(~from=0, ~to_=-1, serverUrl)
                        | _ => serverUrl
                        }
                        serverUrl->Js.String2.split("/")->List.fromArray
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
                        ->MutableMap.String.toArray
                        ->Array.reduce(
                          Map.String.empty,
                          (acc, (collectionKey, collectionDirections)) =>
                            acc->Map.String.update(
                              collectionKey,
                              _ => Some(
                                collectionDirections
                                ->Map.String.toArray
                                ->Array.reduce(
                                  Map.String.empty,
                                  (acc, (direction, pagesToRender)) =>
                                    acc->Map.String.update(
                                      direction,
                                      _ =>
                                        context.lists
                                        ->Map.String.get(collectionKey)
                                        ->Option.flatMap(value => value->Map.String.get(direction))
                                        ->Option.flatMap(
                                          pages => Some(
                                            pagesToRender->Set.Int.reduce(
                                              Map.Int.empty,
                                              (acc, key) =>
                                                acc->Map.Int.update(
                                                  key,
                                                  _ => pages->Map.Int.get(key),
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
                        ->MutableMap.String.toArray
                        ->Array.reduce(
                          Map.String.empty,
                          (acc, (collectionKey, idsToRender)) =>
                            acc->Map.String.update(
                              collectionKey,
                              _ =>
                                context.items
                                ->Map.String.get(collectionKey)
                                ->Option.flatMap(
                                  pages => Some(
                                    idsToRender->Set.String.reduce(
                                      Map.String.empty,
                                      (acc, key) => {
                                        itemUsageMap->MutableMap.String.set(
                                          serverUrl,
                                          (collectionKey, key),
                                        )
                                        acc->Map.String.update(key, _ => pages->Map.String.get(key))
                                      },
                                    ),
                                  ),
                                ),
                            ),
                        ),
                        listsRequests: MutableMap.String.make(),
                        itemsRequests: MutableMap.String.make(),
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
                  ->Map.String.fromArray

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
                  ->Map.String.fromArray

                let lists =
                  store.lists
                  ->Map.String.toArray
                  ->Array.reduce(
                    Map.String.empty,
                    (acc, (collectionName, collection)) =>
                      collection
                      ->Map.String.toArray
                      ->Array.reduce(
                        acc,
                        (acc, (direction, sortedCollection)) =>
                          sortedCollection
                          ->Map.Int.toArray
                          ->Array.reduce(
                            acc,
                            (acc, (page, items)) =>
                              acc->Map.String.set(
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
                  ->Map.String.toArray
                  ->Array.reduce(
                    Map.String.empty,
                    (acc, (collectionName, collection)) =>
                      collection
                      ->Map.String.toArray
                      ->Array.reduce(
                        acc,
                        (acc, (direction, sortedCollection)) =>
                          sortedCollection
                          ->Map.Int.get(0)
                          ->Option.map(
                            page => {
                              let url = switch variant.subdirectory {
                              | Some(subdirectory) =>
                                `/${subdirectory}/api/${collectionName}/feeds/${direction}/feed.xml`
                              | None => `/api/${collectionName}/feeds/${direction}/feed.xml`
                              }
                              acc->Map.String.set(
                                url,
                                {
                                  let items =
                                    page.items
                                    ->Array.keepMap(
                                      item => {
                                        itemUsageMap
                                        ->MutableMap.String.toArray
                                        ->Array.getBy(
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
                          ->Option.getWithDefault(acc),
                      ),
                  )
                let items =
                  store.items
                  ->Map.String.toArray
                  ->Array.reduce(
                    Map.String.empty,
                    (acc, (collectionName, collection)) =>
                      collection
                      ->Map.String.toArray
                      ->Array.reduce(
                        acc,
                        (acc, (id, item)) =>
                          acc->Map.String.set(
                            switch variant.subdirectory {
                            | Some(subdirectory) =>
                              `/${subdirectory}/api/${collectionName}/items/${id}.json`
                            | None => `/api/${collectionName}/items/${id}.json`
                            },
                            item->Js.Json.serializeExn,
                          ),
                      ),
                  )

                Js.Promise.resolve((
                  map->Map.String.merge(
                    prerenderedPages->Map.String.mergeMany(
                      Array.concatMany([
                        lists->Map.String.toArray,
                        items->Map.String.toArray,
                        feeds->Map.String.toArray,
                        redirects->Map.String.toArray,
                      ]),
                    ),
                    (_, a, b) =>
                      switch (a, b) {
                      | (_, Some(b)) => Some(b)
                      | (Some(a), _) => Some(a)
                      | (None, None) => None
                      },
                  ),
                  set->Set.String.union(
                    prerenderedPages
                    ->Map.String.keysToArray
                    ->Array.map(url => joinUrl(config.baseUrl, url))
                    ->Set.String.fromArray,
                  ),
                ))
              | None => Js.Promise.resolve((map, set))
              }
            },
            _,
          )
        )
      }, _))
  })
  ->(Js.Promise.then_(((files, pages)) => {
      Js.Promise.resolve(
        files
        ->Map.String.set(`/sitemap.xml`, sitemap(pages->Set.String.toArray))
        ->Map.String.toArray
        ->Array.map(((filePath, value)) => {
          let filePath = join(config.distDirectory, filePath)
          let filePath =
            filePath->Js.String2.startsWith("/")
              ? filePath->Js.String2.sliceToEnd(~from=1)
              : filePath
          let filePath =
            extname(filePath) != ""
              ? filePath
              : filePath ++ (filePath->Js.String2.endsWith("/") ? "" : "/") ++ "index.html"
          (filePath, value)
        }),
      )
    }, _))
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
          "libraryTarget": Js.Undefined.return("commonjs"),
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
            ->Option.map(Js.Json.parseExn)
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
          "libraryTarget": Js.Undefined.empty,
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
            ->Option.map(Js.Json.parseExn)
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
