type urlStore = {
  getAll: string => array<string>,
  getPages: string => array<int>,
}

type variant = {
  subdirectory: option<string>,
  localeFile: option<string>,
  contentDirectory: string,
  getUrlsToPrerender: urlStore => array<string>,
}

type config = {
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

type listItem = {
  slug: string,
  title: string,
  date: option<string>,
  draft: bool,
  meta: Js.Dict.t<string>,
}

type item = {
  slug: string,
  title: string,
  date: option<string>,
  draft: bool,
  meta: Js.Dict.t<string>,
  body: string,
}

type paginated<'a> = {
  hasPreviousPage: bool,
  hasNextPage: bool,
  items: array<'a>,
}

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
}

module Link: {
  @react.component
  let make: (
    ~href: string,
    ~className: string=?,
    ~style: ReactDOM.Style.t=?,
    ~activeClassName: string=?,
    ~activeStyle: ReactDOM.Style.t=?,
    ~matchSubroutes: bool=?,
    ~children: React.element,
  ) => React.element
}

module Head: {
  @react.component
  let make: (~children: React.element) => React.element
}

let useCollection: (
  ~page: int=?,
  ~direction: direction=?,
  string,
) => AsyncData.t<result<paginated<listItem>, error>>

let useItem: (string, ~id: string) => AsyncData.t<result<item, error>>

module App: {
  @react.component
  let make: (
    ~config: config,
    ~app: React.component<{"config": config, "url": ReasonReactRouter.url}>,
  ) => React.element
}

type app = {
  app: React.component<{"config": config, "url": ReasonReactRouter.url}>,
  config: config,
  provider: React.component<{
    "value": option<Context.t>,
    "serverUrl": option<ReasonReactRouter.url>,
    "config": config,
    "render": unit => React.element,
  }>,
}

let make: (React.component<{"config": config, "url": ReasonReactRouter.url}>, config) => app
