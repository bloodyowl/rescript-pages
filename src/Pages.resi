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

type paginated<'a> = {
  hasPreviousPage: bool,
  hasNextPage: bool,
  totalCount: int,
  items: array<'a>,
}

@val external variantBasePath: string = "process.env.PAGES_PATH"
@val external basePath: string = "process.env.PAGES_ROOT"

@val external t: string => string = "__"
@val external tr: string => React.element = "__"

let makeVariantUrl: string => string
let makeBaseUrl: string => string

type direction = [#asc | #desc]

module Context: {
  type t = {
    lists: Belt.Map.String.t<
      Belt.Map.String.t<Belt.Map.Int.t<AsyncData.t<result<paginated<listItem>, error>>>>,
    >,
    items: Belt.Map.String.t<Belt.Map.String.t<AsyncData.t<result<item, error>>>>,
    mutable listsRequests: Belt.MutableMap.String.t<Belt.Map.String.t<Belt.Set.Int.t>>,
    mutable itemsRequests: Belt.MutableMap.String.t<Belt.Set.String.t>,
  }
  type context = (t, (t => t) => unit)

  @react.component
  let make: (
    ~value: t=?,
    ~serverUrl: RescriptReactRouter.url=?,
    ~config: config,
    ~children: React.element,
  ) => React.element
}

module Link: {
  @react.component
  let make: (
    ~href: string,
    ~matchHref: string=?,
    ~className: string=?,
    ~style: ReactDOM.Style.t=?,
    ~activeClassName: string=?,
    ~activeStyle: ReactDOM.Style.t=?,
    ~matchSubroutes: bool=?,
    ~title: string=?,
    ~children: React.element,
  ) => React.element
}

module Head: {
  @react.component
  let make: (~children: React.element) => React.element
}

module ActivityIndicator: {
  @react.component
  let make: (~color: string=?, ~size: int=?, ~strokeWidth: int=?, unit) => React.element
}

module ErrorIndicator: {
  @react.component
  let make: unit => React.element
}

module Redirect: {
  @react.component
  let make: (~url: string) => React.element
}

let useCollection: (
  ~page: int=?,
  ~direction: direction=?,
  string,
) => AsyncData.t<result<paginated<listItem>, error>>

let useItem: (string, ~id: string) => AsyncData.t<result<item, error>>

module ProvidedApp: {
  type props<'url, 'config> = {url: 'url, config: 'config}
}

module App: {
  @react.component
  let make: (
    ~config: config,
    ~app: React.component<ProvidedApp.props<RescriptReactRouter.url, config>>,
  ) => React.element
}

type emotion

type app = {
  app: React.component<ProvidedApp.props<RescriptReactRouter.url, config>>,
  container: React.component<
    App.props<config, React.component<ProvidedApp.props<RescriptReactRouter.url, config>>>,
  >,
  config: config,
  provider: React.component<
    Context.props<Context.t, RescriptReactRouter.url, config, React.element>,
  >,
  emotion: emotion,
}

let make: (React.component<ProvidedApp.props<RescriptReactRouter.url, config>>, config) => app
