open StaticWebsite
open Belt

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
