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
    ~children: React.element,
  ) => React.element
}

module Head: {
  @react.component @bs.module("react-helmet")
  external make: (~children: React.element) => React.element = "Helmet"
}

let useCollection: (
  ~page: int=?,
  ~direction: direction=?,
  string,
) => AsyncData.t<result<paginated<listItem>, error>>

let useItem: (string, ~id: string) => AsyncData.t<result<item, error>>

type app = {
  app: React.element,
  config: config,
  provider: React.component<{
    "value": option<Context.t>,
    "config": config,
    "children": React.element,
  }>,
}

let make: (React.element, config) => app
