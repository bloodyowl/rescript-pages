type listItem = {
  slug: string,
  filename: string,
  title: string,
  date: option<string>,
  draft: bool,
  meta: Dict.t<JSON.t>,
  summary: string,
}

type item = {
  slug: string,
  filename: string,
  title: string,
  date: option<string>,
  draft: bool,
  meta: Dict.t<JSON.t>,
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
  getRedirectMap: option<urlStore => Dict.t<string>>,
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
    let make = context->React.Context.provider
  }
}

// copied from RescriptReactRouter
let pathParse = str =>
  switch str {
  | "" | "/" => list{}
  | raw =>
    /* remove the preceeding /, which every pathname seems to have */
    let raw = String.sliceToEnd(~start=1, raw)
    /* remove the trailing /, which some pathnames might have. Ugh */
    let raw = switch String.get(raw, String.length(raw) - 1) {
    | Some("/") => String.slice(~start=0, ~end=-1, raw)
    | _ => raw
    }
    /* remove search portion if present in string */
    let raw = switch String.splitAtMost("?", ~limit=2, raw) {
    | [path, _] => path
    | _ => raw
    }

    List.fromArray(raw->String.split("/")->Array.filter(item => String.length(item) != 0))
  }

@val external variantBasePath: string = "process.env.PAGES_PATH"
@val external basePath: string = "process.env.PAGES_ROOT"

let rec stripInitialPath = (path, sourcePath) => {
  switch (path, sourcePath) {
  | (list{a1, ...a2}, list{b1, ...b2}) if a1 === b1 => stripInitialPath(a2, b2)
  | (path, _) => path
  }
}

let useUrl = () => {
  let serverUrl = React.useContext(ServerUrlContext.context)
  let {path} as url = RescriptReactRouter.useUrl(~serverUrl?, ())
  {...url, path: stripInitialPath(path, pathParse(variantBasePath))}
}

let join = (s1, s2) =>
  `${s1}/${s2}`
  ->String.replaceRegExp(%re("/:\/\//g"), "__PROTOCOL__")
  ->String.replaceRegExp(%re("/\/+/g"), "/")
  ->String.replaceRegExp(%re("/__PROTOCOL__/g"), "://")

@val external t: string => string = "__"
@val external tr: string => React.element = "__"

let makeVariantUrl = value => join(variantBasePath, value)
let makeBaseUrl = value => join(basePath, value)

module Emotion = {
  @module("@emotion/css") external css: {..} => string = "css"
  @module("@emotion/css") external cx: array<string> => string = "cx"
}

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
    let path = "/" ++ url.path->List.toArray->Array.join("/")
    let compareHref = matchHref->Option.getOr(href)
    let isActive = matchSubroutes
      ? (path ++ "/")->String.startsWith(compareHref) || path->String.startsWith(compareHref)
      : path === compareHref || path ++ "/" === compareHref
    let href = makeVariantUrl(href)
    <a
      href
      ?title
      className={Emotion.cx(
        [className, isActive ? activeClassName : None]->Array.filterMap(x => x),
      )}
      style=?{switch (style, isActive ? activeStyle : None) {
      | (Some(a), Some(b)) => Some(ReactDOM.Style.combine(a, b))
      | (Some(a), None) => Some(a)
      | (None, Some(b)) => Some(b)
      | (None, None) => None
      }}
      onClick={event => {
        switch (ReactEvent.Mouse.metaKey(event), ReactEvent.Mouse.ctrlKey(event)) {
        | (false, false) =>
          event->ReactEvent.Mouse.preventDefault
          RescriptReactRouter.push(href)
        | _ => ()
        }
      }}>
      children
    </a>
  }
}

module Head = {
  @react.component @module("react-helmet")
  external make: (~children: React.element) => React.element = "Helmet"
}

module ActivityIndicator = {
  module Styles = {
    open Emotion
    let container = css({"display": "flex", "margin": "auto"})
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
    open Emotion
    let container = css({
      "display": "flex",
      "alignItems": "center",
      "justifyContent": "center",
      "margin": "auto",
    })
    let text = css({"fontSize": 22, "fontWeight": "bold", "textAlign": "center"})
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
    <Head>
      <meta httpEquiv="refresh" content={`0;URL=${url}`} />
    </Head>
  }
}

module Context = {
  type t = {
    lists: Belt.Map.String.t<
      Belt.Map.String.t<Belt.Map.Int.t<AsyncData.t<result<paginated<listItem>, error>>>>,
    >,
    items: Belt.Map.String.t<Belt.Map.String.t<AsyncData.t<result<item, error>>>>,
    mutable listsRequests: Belt.MutableMap.String.t<Belt.Map.String.t<Belt.Set.Int.t>>,
    mutable itemsRequests: Belt.MutableMap.String.t<Belt.Set.String.t>,
  }
  type context = (t, (t => t) => unit)
  let default = {
    lists: Belt.Map.String.empty,
    items: Belt.Map.String.empty,
    listsRequests: Belt.MutableMap.String.make(),
    itemsRequests: Belt.MutableMap.String.make(),
  }
  let defaultSetState: (t => t) => unit = _ => ()
  let context = React.createContext((default, defaultSetState))

  module Provider = {
    let make = context->React.Context.provider
  }

  @react.component
  let make = (~value: option<t>, ~serverUrl=?, ~config, ~children) => {
    let (value, setValue) = React.useState(() => value->Option.getOr(default))

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

external asPaginated: JSON.t => paginated<listItem> = "%identity"

let useCollection = (~page=0, ~direction=#desc, collection): AsyncData.t<
  result<paginated<listItem>, error>,
> => {
  let direction = direction->directionAsString
  let ({lists, listsRequests}: Context.t, setContext) = React.useContext(Context.context)
  listsRequests->Belt.MutableMap.String.update(collection, collection => Some(
    collection
    ->Option.getOr(Belt.Map.String.empty)
    ->Belt.Map.String.update(direction, requests => Some(
      requests->Option.getOr(Belt.Set.Int.empty)->Belt.Set.Int.add(page),
    )),
  ))

  React.useEffect1(() => {
    switch lists
    ->Belt.Map.String.get(collection)
    ->Option.flatMap(collection => collection->Belt.Map.String.get(direction))
    ->Option.flatMap(sortedCollection => sortedCollection->Belt.Map.Int.get(page)) {
    | Some(_) => None
    | None =>
      let status = AsyncData.Loading
      setContext(context => {
        ...context,
        lists: context.lists->Belt.Map.String.update(
          collection,
          collection => Some(
            collection
            ->Option.getOr(Belt.Map.String.empty)
            ->Belt.Map.String.update(
              direction,
              sortedCollection => Some(
                sortedCollection
                ->Option.getOr(Belt.Map.Int.empty)
                ->Belt.Map.Int.set(page, status),
              ),
            ),
          ),
        ),
      })
      let url = makeVariantUrl(`api/${collection}/pages/${direction}/${page->Int.toString}.json`)
      let future =
        Request.make(~url, ~responseType=Text, ())
        ->Future.mapError(~propagateCancel=true, mapError)
        ->Future.mapResult(~propagateCancel=true, response =>
          switch response {
          | {ok: true, response: Some(value)} => Ok(JSON.parseExn(value)->asPaginated)
          | _ => Error(EmptyResponse)
          }
        )

      future->Future.get(result => {
        setContext(
          context => {
            ...context,
            lists: context.lists->Belt.Map.String.update(
              collection,
              collection => Some(
                collection
                ->Option.getOr(Belt.Map.String.empty)
                ->Belt.Map.String.update(
                  direction,
                  sortedCollection => Some(
                    sortedCollection
                    ->Option.getOr(Belt.Map.Int.empty)
                    ->Belt.Map.Int.set(page, Done(result)),
                  ),
                ),
              ),
            ),
          },
        )
      })

      Some(() => future->Future.cancel)
    }
  }, [page])

  lists
  ->Belt.Map.String.get(collection)
  ->Option.flatMap(collection => collection->Belt.Map.String.get(direction))
  ->Option.flatMap(collection => collection->Belt.Map.Int.get(page))
  ->Option.getOr(NotAsked)
}

external asItem: JSON.t => item = "%identity"

let useItem = (collection, ~id): AsyncData.t<result<item, error>> => {
  let ({items, itemsRequests}: Context.t, setContext) = React.useContext(Context.context)
  itemsRequests->Belt.MutableMap.String.update(collection, items => Some(
    items->Option.getOr(Belt.Set.String.empty)->Belt.Set.String.add(id),
  ))

  React.useEffect1(() => {
    switch items
    ->Belt.Map.String.get(collection)
    ->Option.flatMap(collection => collection->Belt.Map.String.get(id)) {
    | Some(_) => None
    | None =>
      let status = AsyncData.Loading
      setContext(context => {
        ...context,
        items: context.items->Belt.Map.String.update(
          collection,
          collection => Some(
            collection->Option.getOr(Belt.Map.String.empty)->Belt.Map.String.set(id, status),
          ),
        ),
      })
      let url = makeVariantUrl(`/api/${collection}/items/${id}.json`)
      let future =
        Request.make(~url, ~responseType=Text, ())
        ->Future.mapError(~propagateCancel=true, mapError)
        ->Future.mapResult(~propagateCancel=true, response =>
          switch response {
          | {ok: true, response: Some(value)} => Ok(JSON.parseExn(value)->asItem)
          | _ => Error(EmptyResponse)
          }
        )

      future->Future.get(result => {
        setContext(
          context => {
            ...context,
            items: context.items->Belt.Map.String.update(
              collection,
              collection => Some(
                collection
                ->Option.getOr(Belt.Map.String.empty)
                ->Belt.Map.String.set(id, Done(result)),
              ),
            ),
          },
        )
      })

      Some(() => future->Future.cancel)
    }
  }, [id])

  items
  ->Belt.Map.String.get(collection)
  ->Option.flatMap(collection => collection->Belt.Map.String.get(id))
  ->Option.getOr(NotAsked)
}

@get external textContent: Dom.element => string = "textContent"

module App = {
  type appProps = {
    url: RescriptReactRouter.url,
    config: config,
  }

  @react.component
  let make = (~config, ~app) => {
    let url = useUrl()
    React.createElement(app, {url, config})
  }
}

type bootMode = [#hydrate | #render]
@val external pagesBootMode: bootMode = "window.PAGES_BOOT_MODE"

external asContext: JSON.t => Context.t = "%identity"

let start = (app, config) => {
  let rootElement = ReactDOM.querySelector("#root")
  let initialData =
    ReactDOM.querySelector("#initialData")
    ->Option.map(textContent)
    ->Option.map(x => JSON.parseExn(x)->asContext)
  switch (rootElement, initialData, pagesBootMode) {
  | (Some(rootElement), Some(initialData), #hydrate) =>
    let _ = ReactDOM.Client.hydrateRoot(
      rootElement,
      <Context config value=Some(initialData)>
        <App app config />
      </Context>,
    )
  | (Some(root), None, #hydrate | #render) | (Some(root), Some(_), #render) =>
    ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(
      <Context config value=None>
        <App app config />
      </Context>,
    )
  | (None, _, _) => Console.error(`Can't find the app's root container`)
  }
}

@val external window: {..} = "window"
type emotion
@module external emotion: emotion = "@emotion/css"

type app = {
  app: React.component<App.appProps>,
  container: React.component<App.props<config, React.component<App.appProps>>>,
  config: config,
  provider: React.component<
    Context.props<option<Context.t>, RescriptReactRouter.url, config, React.element>,
  >,
  emotion: emotion,
}

let make = (app, config) => {
  if typeof(window) != #undefined {
    start(app, config)
  }
  {app, container: App.make, config, provider: Context.make, emotion}
}
