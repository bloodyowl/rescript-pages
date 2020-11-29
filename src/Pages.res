open Belt

type listItem = {
  slug: string,
  filename: string,
  title: string,
  date: option<string>,
  draft: bool,
  meta: Js.Dict.t<Js.Json.t>,
  summary: string,
}

type item = {
  slug: string,
  filename: string,
  title: string,
  date: option<string>,
  draft: bool,
  meta: Js.Dict.t<Js.Json.t>,
  body: string,
}

type urlStore = {
  getAll: string => array<string>,
  getAllItems: string => array<item>,
  getPages: string => array<int>,
}

type variant = {
  subdirectory: option<string>,
  localeFile: option<string>,
  contentDirectory: string,
  getUrlsToPrerender: urlStore => array<string>,
  getRedirectMap: option<urlStore => Js.Dict.t<string>>,
}

type mode = SPA | Static

type config = {
  mode: mode,
  siteTitle: string,
  siteDescription: string,
  distDirectory: string,
  baseUrl: string,
  staticsDirectory: option<string>,
  paginateBy: int,
  variants: array<variant>,
}

type error =
  | EmptyResponse
  | Timeout
  | NetworkRequestFailed

let mapError = error =>
  switch error {
  | #NetworkRequestFailed => NetworkRequestFailed
  | #Timeout => Timeout
  }

type paginated<'a> = {
  hasPreviousPage: bool,
  hasNextPage: bool,
  totalCount: int,
  items: array<'a>,
}

type direction = [#asc | #desc]
external directionAsString: direction => string = "%identity"

module ServerUrlContext = {
  let context = React.createContext(None)

  module Provider = {
    @bs.obj
    external makeProps: (
      ~value: option<ReasonReactRouter.url>,
      ~children: React.element,
      ~key: string=?,
      unit,
    ) => {"value": option<ReasonReactRouter.url>, "children": React.element} = ""
    let make = context->React.Context.provider
  }
}

// copied from ReasonReactRouter
let pathParse = str =>
  switch str {
  | "" | "/" => list{}
  | raw =>
    /* remove the preceeding /, which every pathname seems to have */
    let raw = Js.String.sliceToEnd(~from=1, raw)
    /* remove the trailing /, which some pathnames might have. Ugh */
    let raw = switch Js.String.get(raw, Js.String.length(raw) - 1) {
    | "/" => Js.String.slice(~from=0, ~to_=-1, raw)
    | _ => raw
    }
    /* remove search portion if present in string */
    let raw = switch raw |> Js.String.splitAtMost("?", ~limit=2) {
    | [path, _] => path
    | _ => raw
    }

    raw
    |> Js.String.split("/")
    |> Js.Array.filter(item => String.length(item) != 0)
    |> List.fromArray
  }

@bs.val external variantBasePath: string = "process.env.PAGES_PATH"
@bs.val external basePath: string = "process.env.PAGES_ROOT"

let rec stripInitialPath = (path, sourcePath) => {
  switch (path, sourcePath) {
  | (list{a1, ...a2}, list{b1, ...b2}) when a1 === b1 => stripInitialPath(a2, b2)
  | (path, _) => path
  }
}

let useUrl = () => {
  let serverUrl = React.useContext(ServerUrlContext.context)
  let {path} as url = ReasonReactRouter.useUrl(~serverUrl?, ())
  {...url, path: stripInitialPath(path, pathParse(variantBasePath))}
}

let join = (s1, s2) =>
  (`${s1}/${s2}`)
  ->Js.String2.replaceByRe(%re("/:\/\//g"), "__PROTOCOL__")
  ->Js.String2.replaceByRe(%re("/\/+/g"), "/")
  ->Js.String2.replaceByRe(%re("/__PROTOCOL__/g"), "://")

@bs.val external t: string => string = "__"
@bs.val external tr: string => React.element = "__"

let makeVariantUrl = join(variantBasePath)
let makeBaseUrl = join(basePath)

module Link = {
  @react.component
  let make = (
    ~href,
    ~matchHref=?,
    ~className=?,
    ~style=?,
    ~activeClassName=?,
    ~activeStyle=?,
    ~matchSubroutes=false,
    ~title=?,
    ~children,
  ) => {
    let url = useUrl()
    let path = "/" ++ String.concat("/", url.path)
    let compareHref = matchHref->Option.getWithDefault(href)
    let isActive = matchSubroutes
      ? Js.String.startsWith(compareHref, path ++ "/") || Js.String.startsWith(compareHref, path)
      : path === compareHref || path ++ "/" === compareHref
    let href = makeVariantUrl(href)
    <a
      href
      ?title
      className={CssJs.merge(.
        [className, isActive ? activeClassName : None]->Array.keepMap(x => x),
      )}
      style=?{switch (style, isActive ? activeStyle : None) {
      | (Some(a), Some(b)) => Some(ReactDOM.Style.combine(a, b))
      | (Some(a), None) => Some(a)
      | (None, Some(b)) => Some(b)
      | (None, None) => None
      }}
      onClick={event => {
        event->ReactEvent.Mouse.preventDefault
        ReasonReactRouter.push(href)
      }}>
      children
    </a>
  }
}

module Head = {
  @react.component @bs.module("react-helmet")
  external make: (~children: React.element) => React.element = "Helmet"
}

module ActivityIndicator = {
  module Styles = {
    open CssJs
    let container = style(.[display(flexBox), margin(auto)])
  }

  @react.component
  let make = (~color="currentColor", ~size=32, ~strokeWidth=2, ()) => {
    <div className=Styles.container>
      <svg
        width={Int.toString(size)}
        height={Int.toString(size)}
        viewBox="0 0 38 38"
        xmlns="http://www.w3.org/2000/svg"
        xmlnsXlink="http://www.w3.org/1999/xlink"
        stroke=color
        style={ReactDOM.Style.make(~overflow="visible", ())}
        ariaLabel="Loading"
        role="alert"
        ariaBusy=true>
        <g fill="none" fillRule="evenodd">
          <g transform="translate(1 1)" strokeWidth={strokeWidth->Int.toString}>
            <circle strokeOpacity=".5" cx="18" cy="18" r="18" />
            <path d="M36 18c0-9.94-8.06-18-18-18">
              <animateTransform
                attributeName="transform"
                type_="rotate"
                from="0 18 18"
                to_="360 18 18"
                dur="1s"
                repeatCount="indefinite"
              />
            </path>
          </g>
        </g>
      </svg>
    </div>
  }
}

module ErrorIndicator = {
  module Styles = {
    open CssJs
    let container = style(.[
      display(flexBox),
      alignItems(center),
      justifyContent(center),
      margin(auto),
    ])
    let text = style(.[fontSize(22->px), fontWeight(bold), textAlign(center)])
  }

  @react.component
  let make = () => {
    <div className=Styles.container>
      <div className=Styles.text> {tr(`An error occured 😕`)} </div>
    </div>
  }
}

module Redirect = {
  @react.component
  let make = (~url) => {
    <Head> <meta httpEquiv="refresh" content={`0;URL=${url}`} /> </Head>
  }
}

module Context = {
  type t = {
    lists: Map.String.t<Map.String.t<Map.Int.t<AsyncData.t<result<paginated<listItem>, error>>>>>,
    items: Map.String.t<Map.String.t<AsyncData.t<result<item, error>>>>,
    mutable listsRequests: MutableMap.String.t<Map.String.t<Set.Int.t>>,
    mutable itemsRequests: MutableMap.String.t<Set.String.t>,
  }
  type context = (t, (t => t) => unit)
  let default = {
    lists: Map.String.empty,
    items: Map.String.empty,
    listsRequests: MutableMap.String.make(),
    itemsRequests: MutableMap.String.make(),
  }
  let defaultSetState: (t => t) => unit = _ => ()
  let context = React.createContext((default, defaultSetState))

  module Provider = {
    @bs.obj
    external makeProps: (
      ~value: context,
      ~children: React.element,
      unit,
    ) => {"value": context, "children": React.element} = ""
    let make = context->React.Context.provider
  }

  @react.component
  let make = (~value: option<t>=?, ~serverUrl=?, ~config, ~children) => {
    let (value, setValue) = React.useState(() => value->Option.getWithDefault(default))

    <ServerUrlContext.Provider value=serverUrl>
      <Head>
        <meta charSet="UTF-8" />
        <title> {config.siteTitle->React.string} </title>
        <meta name="description" value=config.siteDescription />
      </Head>
      <Provider value={(value, setValue)}> {children} </Provider>
    </ServerUrlContext.Provider>
  }
}

let useCollection = (~page=0, ~direction=#desc, collection): AsyncData.t<
  result<paginated<listItem>, error>,
> => {
  let direction = direction->directionAsString
  let ({lists, listsRequests}: Context.t, setContext) = React.useContext(Context.context)
  listsRequests->MutableMap.String.update(collection, collection => Some(
    collection
    ->Option.getWithDefault(Map.String.empty)
    ->Map.String.update(direction, requests => Some(
      requests->Option.getWithDefault(Set.Int.empty)->Set.Int.add(page),
    )),
  ))

  React.useEffect1(() => {
    switch lists
    ->Map.String.get(collection)
    ->Option.flatMap(collection => collection->Map.String.get(direction))
    ->Option.flatMap(sortedCollection => sortedCollection->Map.Int.get(page)) {
    | Some(_) => None
    | None =>
      let status = AsyncData.Loading
      setContext(context => {
        ...context,
        lists: context.lists->Map.String.update(collection, collection => Some(
          collection
          ->Option.getWithDefault(Map.String.empty)
          ->Map.String.update(direction, sortedCollection => Some(
            sortedCollection->Option.getWithDefault(Map.Int.empty)->Map.Int.set(page, status),
          )),
        )),
      })
      let url = makeVariantUrl(`api/${collection}/pages/${direction}/${page->Int.toString}.json`)
      let future =
        Request.make(~url, ~responseType=Text, ())
        ->Future.mapError(~propagateCancel=true, mapError)
        ->Future.mapResult(~propagateCancel=true, response =>
          switch response {
          | {ok: true, response: Some(value)} => Ok(Js.Json.deserializeUnsafe(value))
          | _ => Error(EmptyResponse)
          }
        )

      future->Future.get(result => {
        setContext(context => {
          ...context,
          lists: context.lists->Map.String.update(collection, collection => Some(
            collection
            ->Option.getWithDefault(Map.String.empty)
            ->Map.String.update(direction, sortedCollection => Some(
              sortedCollection
              ->Option.getWithDefault(Map.Int.empty)
              ->Map.Int.set(page, Done(result)),
            )),
          )),
        })
      })

      Some(() => future->Future.cancel)
    }
  }, [page])

  lists
  ->Map.String.get(collection)
  ->Option.flatMap(collection => collection->Map.String.get(direction))
  ->Option.flatMap(collection => collection->Map.Int.get(page))
  ->Option.getWithDefault(NotAsked)
}

let useItem = (collection, ~id): AsyncData.t<result<item, error>> => {
  let ({items, itemsRequests}: Context.t, setContext) = React.useContext(Context.context)
  itemsRequests->MutableMap.String.update(collection, items => Some(
    items->Option.getWithDefault(Set.String.empty)->Set.String.add(id),
  ))

  React.useEffect1(() => {
    switch items
    ->Map.String.get(collection)
    ->Option.flatMap(collection => collection->Map.String.get(id)) {
    | Some(_) => None
    | None =>
      let status = AsyncData.Loading
      setContext(context => {
        ...context,
        items: context.items->Map.String.update(collection, collection => Some(
          collection->Option.getWithDefault(Map.String.empty)->Map.String.set(id, status),
        )),
      })
      let url = makeVariantUrl(`/api/${collection}/items/${id}.json`)
      let future =
        Request.make(~url, ~responseType=Text, ())
        ->Future.mapError(~propagateCancel=true, mapError)
        ->Future.mapResult(~propagateCancel=true, response =>
          switch response {
          | {ok: true, response: Some(value)} => Ok(Js.Json.deserializeUnsafe(value))
          | _ => Error(EmptyResponse)
          }
        )

      future->Future.get(result => {
        setContext(context => {
          ...context,
          items: context.items->Map.String.update(collection, collection => Some(
            collection->Option.getWithDefault(Map.String.empty)->Map.String.set(id, Done(result)),
          )),
        })
      })

      Some(() => future->Future.cancel)
    }
  }, [id])

  items
  ->Map.String.get(collection)
  ->Option.flatMap(collection => collection->Map.String.get(id))
  ->Option.getWithDefault(NotAsked)
}

@bs.get external textContent: Dom.element => string = "textContent"

module App = {
  @react.component
  let make = (~config, ~app) => {
    let url = useUrl()
    React.createElement(app, {"url": url, "config": config})
  }
}

type bootMode = [#hydrate | #render]
@bs.val external pagesBootMode: bootMode = "window.PAGES_BOOT_MODE"

let start = (app, config) => {
  let root = ReactDOM.querySelector("#root")
  let initialData =
    ReactDOM.querySelector("#initialData")
    ->Option.map(textContent)
    ->Option.map(Js.Json.deserializeUnsafe)
  switch (root, initialData, pagesBootMode) {
  | (Some(root), Some(initialData), #hydrate) =>
    ReactDOM.hydrate(<Context config value=initialData> <App app config /> </Context>, root)
  | (Some(root), None, #hydrate | #render) | (Some(root), Some(_), #render) =>
    ReactDOM.render(<Context config> <App app config /> </Context>, root)
  | (None, _, _) => Js.Console.error(`Can't find the app's root container`)
  }
}

@bs.val external window: {..} = "window"
type emotion
@bs.module external emotion: emotion = "emotion"

type app = {
  app: React.component<{"config": config, "url": ReasonReactRouter.url}>,
  container: React.component<{
    "config": config,
    "app": React.component<{
      "config": config,
      "url": ReasonReactRouter.url,
    }>,
  }>,
  config: config,
  provider: React.component<{
    "config": config,
    "serverUrl": option<ReasonReactRouter.url>,
    "value": option<Context.t>,
    "children": React.element,
  }>,
  emotion: emotion,
}

let make = (app, config) => {
  if Js.typeof(window) != "undefined" {
    start(app, config)
  }
  {app: app, container: App.make, config: config, provider: Context.make, emotion: emotion}
}
