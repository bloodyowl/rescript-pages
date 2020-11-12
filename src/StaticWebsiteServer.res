open Belt
open StaticWebsite

type dirent
@bs.send external isDirectory: dirent => bool = "isDirectory"
@bs.send external isFile: dirent => bool = "isFile"
@bs.get external name: dirent => string = "name"
@bs.module("fs") external readdirSync: (string, {..}) => array<dirent> = "readdirSync"
@bs.module("fs") external readFileSync: (string, @bs.as("utf8") _) => string = "readFileSync"
@bs.val external cwd: unit => string = "process.cwd"
@bs.module("path") external join: (string, string) => string = "join"
@bs.module("path") external join3: (string, string, string) => string = "join"
@bs.module("path") external basename: (string, string) => string = "basename"
@bs.module("path") external extname: string => string = "extname"
@bs.module external frontMatter: string => {"attributes": 'a, "body": string} = "front-matter"
type config = {"highlight": (string, string) => string}

type remarkable

@bs.new @bs.module("remarkable")
external remarkable: (string, config) => remarkable = "Remarkable"
@bs.send external render: (remarkable, string) => string = "render"

@bs.module("highlight.js")
external highlightAuto: string => {"value": string} = "highlightAuto"

@bs.module("highlight.js")
external highlight: (~lang: string, string) => {"value": string} = "highlight"

type hjs
type language

@bs.module external hjs: hjs = "highlight.js"
@bs.module external reason: language = "reason-highlightjs"

@bs.send
external registerLanguage: (hjs, string, language) => unit = "registerLanguage"

hjs->registerLanguage("reason", reason)

@bs.module("emotion-server")
external renderStylesToString: string => string = "renderStylesToString"

let remarkable = remarkable(
  "full",
  {
    "highlight": (code, lang) => {
      try {highlight(~lang, code)["value"]} catch {
      | _ => ""
      }
    },
  },
)

let getCollectionItem = (slug, path) => {
  let file = readFileSync(path)
  let parsed = frontMatter(file)
  let meta = parsed["attributes"]
  let item = {
    slug: slug,
    title: meta->Js.Dict.get("title")->Option.getWithDefault("Untitled"),
    date: meta->Js.Dict.get("date"),
    meta: meta,
    body: render(remarkable, parsed["body"]),
  }
  let listItem = {
    slug: slug,
    title: meta->Js.Dict.get("title")->Option.getWithDefault("Untitled"),
    date: meta->Js.Dict.get("date"),
    meta: meta,
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
  ->Array.map(item => (item->name, getCollectionItems(join3(cwd(), "contents", item->name))))
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
        items: array->Array.slice(~offset=(chunkIndex - 1) * paginateBy, ~len=paginateBy),
      },
    )
  })
}

let all = array => {
  {
    hasPreviousPage: false,
    hasNextPage: false,
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
  let getPages = (store: values, collection) => {
    store.lists
    ->Map.String.get(collection)
    ->Option.flatMap(items => items->Map.String.get(#desc->directionAsString))
    ->Option.map(Map.Int.keysToArray)
    ->Option.map(array => array->Array.sliceToEnd(1))
    ->Option.getWithDefault([])
  }
}

@bs.module("react-helmet") @bs.scope("Helmet")
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

let renderRssItem = (config, item: listItem, url) =>
  `<item>
  <title><![CDATA[${item.title}]]></title>
  <link>${join3(config.baseUrl, config.publicPath, url)}</link>
  <guid isPermalink="false">${item.slug}</guid>
  ${item.date
  ->Option.map(date => `<pubDate>${date}</pubDate>`)
  ->Option.getWithDefault("")}
</item>`

let getFiles = (app, contextComponent, config, webpackHtml) => {
  let collections = getCollections(config)
  let store =
    collections
    ->Map.String.toArray
    ->Array.reduce({lists: Map.String.empty, items: Map.String.empty}, (acc, (
      collection,
      collectionItems,
    )) => {
      let items = collectionItems->Map.String.map(((item, _listItem)) => item)

      let listItems =
        collectionItems->Map.String.valuesToArray->Array.map(((_item, listItem)) => listItem)
      let descendendingListItems = listItems->Array.reverse
      let ascending = paginate(listItems, config.paginateBy)->Map.Int.set(0, all(listItems))
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
    })

  let itemUsageMap = MutableMap.String.make()
  let prerenderedPages = config.getUrlsToPrerender({
    getAll: Store.getAll(store),
    getPages: Store.getPages(store),
  })
  ->Array.map(serverUrl => {
    let context: Context.t = {
      lists: store.lists->Map.String.map(collection =>
        collection->Map.String.map(sortedCollection =>
          sortedCollection->Map.Int.map(items => AsyncData.Done(Ok(items)))
        )
      ),
      items: store.items->Map.String.map(collection =>
        collection->Map.String.map(items => AsyncData.Done(Ok(items)))
      ),
      listsRequests: MutableMap.String.make(),
      itemsRequests: MutableMap.String.make(),
    }
    let html = renderStylesToString(
      ReactDOMServer.renderToString({
        React.createElement(
          contextComponent,
          {
            "value": (context, _ => ()),
            "children": React.cloneElement(
              app,
              {
                "serverUrl": {
                  let path = switch serverUrl {
                  | "" | "/" => list{}
                  /* remove the preceeding /, which every pathname seems to have */
                  | _ =>
                    let serverUrl =
                      serverUrl->Js.String2.startsWith("/")
                        ? serverUrl->Js.String2.sliceToEnd(~from=1)
                        : serverUrl
                    /* remove the trailing /, which some pathnames might have. Ugh */
                    let serverUrl = switch Js.String2.get(
                      serverUrl,
                      Js.String2.length(serverUrl) - 1,
                    ) {
                    | "/" => Js.String.slice(~from=0, ~to_=-1, serverUrl)
                    | _ => serverUrl
                    }
                    serverUrl->Js.String2.split("/")->List.fromArray
                  }
                  {
                    path: path,
                    hash: "",
                    search: "",
                  }
                },
              },
            ),
          },
        )
      }),
    )

    let initialData: Context.t = {
      lists: context.listsRequests
      ->MutableMap.String.toArray
      ->Array.reduce(Map.String.empty, (acc, (collectionKey, collectionDirections)) =>
        acc->Map.String.update(collectionKey, _ => Some(
          collectionDirections
          ->Map.String.toArray
          ->Array.reduce(Map.String.empty, (acc, (direction, pagesToRender)) =>
            acc->Map.String.update(direction, _ =>
              context.lists
              ->Map.String.get(collectionKey)
              ->Option.flatMap(value => value->Map.String.get(direction))
              ->Option.flatMap(pages => Some(
                pagesToRender->Set.Int.reduce(Map.Int.empty, (acc, key) =>
                  acc->Map.Int.update(key, _ => pages->Map.Int.get(key))
                ),
              ))
            )
          ),
        ))
      ),
      items: context.itemsRequests
      ->MutableMap.String.toArray
      ->Array.reduce(Map.String.empty, (acc, (collectionKey, idsToRender)) =>
        acc->Map.String.update(collectionKey, _ =>
          context.items
          ->Map.String.get(collectionKey)
          ->Option.flatMap(pages => Some(
            idsToRender->Set.String.reduce(Map.String.empty, (acc, key) => {
              itemUsageMap->MutableMap.String.set(serverUrl, (collectionKey, key))
              acc->Map.String.update(key, _ => pages->Map.String.get(key))
            }),
          ))
        )
      ),
      listsRequests: MutableMap.String.make(),
      itemsRequests: MutableMap.String.make(),
    }
    let initialData =
      initialData->Js.Json.serializeExn->Js.String.replaceByRe(%re("/</g"), `\\u003c`, _)
    let helmet = renderStatic()
    (
      serverUrl,
      `<!DOCTYPE html><html ${helmet["htmlAttributes"]}><head>${helmet["title"]}${helmet["base"]}${helmet["meta"]}${helmet["link"]}${helmet["style"]}</head><div id="root">${html}</div><script id="initialData" type="text/data">${initialData}</script>${webpackHtml}${helmet["script"]}</html>`,
    )
  })
  ->Map.String.fromArray

  let lists =
    store.lists
    ->Map.String.toArray
    ->Array.reduce(Map.String.empty, (acc, (collectionName, collection)) =>
      collection
      ->Map.String.toArray
      ->Array.reduce(acc, (acc, (direction, sortedCollection)) =>
        sortedCollection
        ->Map.Int.toArray
        ->Array.reduce(acc, (acc, (page, items)) =>
          acc->Map.String.set(
            `/api/${collectionName}/pages/${direction}/${page->Int.toString}.json`,
            items->Js.Json.serializeExn,
          )
        )
      )
    )
  let feeds =
    store.lists
    ->Map.String.toArray
    ->Array.reduce(Map.String.empty, (acc, (collectionName, collection)) =>
      collection
      ->Map.String.toArray
      ->Array.reduce(acc, (acc, (direction, sortedCollection)) =>
        sortedCollection->Map.Int.get(0)->Option.map(page => {
          acc->Map.String.set(
            `/api/${collectionName}/feeds/${direction}/feed.xml`,
            page.items->Array.keepMap(item => {
              itemUsageMap->MutableMap.String.toArray->Array.getBy(((_, (collection, key))) => {
                collection == collectionName && key == item.slug
              })->Option.map(((url, _)) => renderRssItem(config, item, url))
            })->Js.Array2.joinWith("\n"),
          )
        })->Option.getWithDefault(acc)
      )
    )
  let siteMap = [
    (
      "/sitemap.xml",
      `<?xml version="1.0" encoding="utf-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">
${prerenderedPages
      ->Map.String.keysToArray
      ->Array.map(url => `<url><loc>${join3(config.baseUrl, config.publicPath, url)}</loc></url>`)
      ->Js.Array2.joinWith("")}
</urlset>`,
    ),
  ]
  let items =
    store.items
    ->Map.String.toArray
    ->Array.reduce(Map.String.empty, (acc, (collectionName, collection)) =>
      collection
      ->Map.String.toArray
      ->Array.reduce(acc, (acc, (id, item)) =>
        acc->Map.String.set(`/api/${collectionName}/items/${id}.json`, item->Js.Json.serializeExn)
      )
    )

  prerenderedPages
  ->Map.String.mergeMany(
    Array.concatMany([
      lists->Map.String.toArray,
      items->Map.String.toArray,
      feeds->Map.String.toArray,
      siteMap,
    ]),
  )
  ->Map.String.toArray
}
