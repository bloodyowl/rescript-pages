open Belt

type error =
  | EmptyResponse
  | Timeout
  | NetworkRequestFailed

let mapError = error =>
  switch error {
  | #NetworkRequestFailed => NetworkRequestFailed
  | #Timeout => Timeout
  }

type listItem = {slug: string, title: string, date: option<string>, meta: Js.Dict.t<string>}

type item = {
  slug: string,
  title: string,
  date: option<string>,
  meta: Js.Dict.t<string>,
  body: string,
}

type paginated<'a> = {
  hasPreviousPage: bool,
  hasNextPage: bool,
  items: array<'a>,
}

type direction = [#asc | #desc]
external directionAsString: direction => string = "%identity"
let cmp = (a, b) =>
  switch (a, b) {
  | (#asc, #desc) => 1
  | (#desc, #asc) => -1
  | _ => 0
  }
module DirectionComparable = Id.MakeComparable({
  type t = direction
  let cmp = cmp
})

module Link = {
  @react.component
  let make = (~href, ~className=?, ~style=?, ~children) => {
    <a
      href
      ?className
      ?style
      onClick={event => {
        event->ReactEvent.Mouse.preventDefault
        ReasonReactRouter.push(href)
      }}>
      children
    </a>
  }
}

@bs.get external getElementType: React.element => string = "type"
@bs.get external getElementProps: React.element => Js.Dict.t<string> = "props"

module Context = {
  type t = {
    lists: Map.String.t<
      Map.t<
        DirectionComparable.t,
        Map.Int.t<AsyncData.t<result<paginated<listItem>, error>>>,
        DirectionComparable.identity,
      >,
    >,
    items: Map.String.t<Map.String.t<AsyncData.t<result<item, error>>>>,
    mutable listsRequests: Map.String.t<
      Map.t<DirectionComparable.t, Set.Int.t, DirectionComparable.identity>,
    >,
    mutable itemsRequests: Map.String.t<Set.String.t>,
  }
  type context = (t, (t => t) => unit)
  let default = {
    lists: Map.String.empty,
    items: Map.String.empty,
    listsRequests: Map.String.empty,
    itemsRequests: Map.String.empty,
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

  @bs.val external document: {..} = "document"

  @react.component
  let make = (~value: option<t>=?, ~children: React.element) => {
    let (value, setValue) = React.useState(() => value->Option.getWithDefault(default))

    <Provider value={(value, setValue)}> children </Provider>
  }
}

let elementToIdentifier = element =>
  switch element->getElementType {
  | "title" => Some("title")
  | "meta" =>
    Some(
      "meta:" ++
      element->getElementProps->Js.Dict.get("name")->Option.getWithDefault("") ++
      element->getElementProps->Js.Dict.get("property")->Option.getWithDefault("") ++
      element->getElementProps->Js.Dict.get("charset")->Option.getWithDefault(""),
    )
  | "link" =>
    Some("link:" ++ element->getElementProps->Js.Dict.get("rel")->Option.getWithDefault(""))
  | _ => None
  }

module Head = {
  @react.component @bs.module("react-helmet")
  external make: (~children: React.element) => React.element = "Helmet"
}

let useCollection = (~page=0, ~direction=#desc, collection): AsyncData.t<
  result<paginated<listItem>, error>,
> => {
  let ({lists, listsRequests} as context: Context.t, setContext) = React.useContext(Context.context)
  context.listsRequests =
    listsRequests->Map.String.update(collection, collection => Some(
      collection
      ->Option.getWithDefault(Map.make(~id=module(DirectionComparable)))
      ->Map.update(direction, requests => Some(
        requests->Option.getWithDefault(Set.Int.empty)->Set.Int.add(page),
      )),
    ))

  React.useEffect1(() => {
    switch lists
    ->Map.String.get(collection)
    ->Option.flatMap(collection => collection->Map.get(direction))
    ->Option.flatMap(sortedCollection => sortedCollection->Map.Int.get(page)) {
    | Some(_) => None
    | None =>
      let status = AsyncData.Loading
      setContext(context => {
        ...context,
        lists: context.lists->Map.String.update(collection, collection => Some(
          collection
          ->Option.getWithDefault(Map.make(~id=module(DirectionComparable)))
          ->Map.update(direction, sortedCollection => Some(
            sortedCollection->Option.getWithDefault(Map.Int.empty)->Map.Int.set(page, status),
          )),
        )),
      })
      let url =
        `/api/${collection}/pages/${direction->directionAsString}/${page->Int.toString}.json`
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
            ->Option.getWithDefault(Map.make(~id=module(DirectionComparable)))
            ->Map.update(direction, sortedCollection => Some(
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
  ->Option.flatMap(collection => collection->Map.get(direction))
  ->Option.flatMap(collection => collection->Map.Int.get(page))
  ->Option.getWithDefault(NotAsked)
}

let useItem = (collection, ~id): AsyncData.t<result<item, error>> => {
  let ({items, itemsRequests} as context: Context.t, setContext) = React.useContext(Context.context)
  context.itemsRequests =
    itemsRequests->Map.String.update(collection, items => Some(
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
      let url = `/api/${collection}/items/${id}.json`
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

type urlStore = {
  getAll: string => array<string>,
  getPages: string => array<int>,
}

type config = {
  contentDirectory: string,
  distDirectory: string,
  publicPath: string,
  localeFile: option<string>,
  publicDirectory: option<string>,
  getUrlsToPrerender: urlStore => array<string>,
  cname: option<string>,
}

let start = app => {
  let root = ReactDOM.querySelector("#root")
  let initialData =
    ReactDOM.querySelector("#data")->Option.map(textContent)->Option.map(Js.Json.deserializeUnsafe)
  switch (root, initialData) {
  | (Some(root), Some(initialData)) =>
    ReactDOM.hydrate(<Context value=initialData> app </Context>, root)
  | (Some(root), None) => ReactDOM.render(<Context> app </Context>, root)
  | (None, _) => Js.Console.error(`Can't find the app's root container`)
  }
}

@bs.val external window: {..} = "window"

let make = (app, configs) => {
  if Js.typeof(window) != "undefined" {
    start(app)
  }
  (app, configs)
}
