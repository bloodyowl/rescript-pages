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

type page = {
  mutable title: option<string>,
  meta: MutableMap.String.t<string>,
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
    page: page,
  }
  type context = (t, (t => t) => unit)
  let default = {
    lists: Map.String.empty,
    items: Map.String.empty,
    listsRequests: Map.String.empty,
    itemsRequests: Map.String.empty,
    page: {title: None, meta: MutableMap.String.make()},
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
  let make = (~value: option<t>=?, ~children: React.element) => {
    let (value, setValue) = React.useState(() => value->Option.getWithDefault(default))
    <Provider value={(value, setValue)}> children </Provider>
  }
}

@bs.val external document: {..} = "document"

let useTitle = (title: string) => {
  let ({page}: Context.t, _) = React.useContext(Context.context)
  page.title = Some(title)
  React.useEffect1(() => {
    document["title"] = title
    None
  }, [title])
}

module Title = {
  @react.component
  let make = (~title) => {
    useTitle(title)
    React.null
  }
}

let useMeta = (~attribute="name", name: string, value: string) => {
  let ({page}: Context.t, _) = React.useContext(Context.context)
  page.meta->MutableMap.String.set(`${attribute}="${name}"`, value)
  React.useEffect1(() => {
    let meta = switch document["querySelector"](
      `meta[${attribute}="${name}"]`,
    )->Js.Nullable.toOption {
    | Some(meta) => meta
    | None =>
      let meta = document["createElement"]("meta")
      let _ = meta["setAttribute"](attribute, name)
      meta
    }
    meta["value"] = value
    let _ = document["head"]["appendChild"](meta)
    None
  }, [attribute, name, value])
}

module Meta = {
  @react.component
  let make = (~name, ~attribute=?, ~value) => {
    useMeta(~attribute?, name, value)
    React.null
  }
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
      let url = `/api/${collection}/pages/${direction->directionAsString}/${page->Int.toString}`
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
      let url = `/api/${collection}/items/${id}`
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
