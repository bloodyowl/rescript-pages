open Belt
open StaticWebsite

let paginateBy = 20

let paginate = array => {
  let chunkTotal =
    array->Array.length / paginateBy + (mod(array->Array.length, paginateBy) > 0 ? 1 : 0)
  Array.range(1, chunkTotal)->Array.reduce(Map.Int.empty, (acc, chunkIndex) => {
    acc->Map.Int.set(
      chunkIndex,
      {
        hasPreviousPage: chunkIndex > 1,
        hasNextPage: chunkIndex < chunkTotal - 1,
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
  lists: Map.String.t<
    Map.t<DirectionComparable.t, Map.Int.t<paginated<listItem>>, DirectionComparable.identity>,
  >,
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
    ->Option.flatMap(items => items->Map.get(#desc))
    ->Option.map(Map.Int.keysToArray)
    ->Option.map(array => array->Array.sliceToEnd(1))
    ->Option.getWithDefault([])
  }
}

let getFiles = (App(app, config), getUrls: values => array<string>) => {
  let collections = Collections.getCollections(config)

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
      let ascending = paginate(listItems)->Map.Int.set(0, all(listItems))
      let decending = paginate(descendendingListItems)->Map.Int.set(0, all(descendendingListItems))

      {
        lists: acc.lists->Map.String.set(
          collection,
          Map.fromArray(~id=module(DirectionComparable), [(#asc, ascending), (#desc, decending)]),
        ),
        items: acc.items->Map.String.set(collection, items),
      }
    })

  let prerenderedPages = getUrls(store)->Array.map(serverUrl => {
    let context: Context.t = {
      lists: store.lists->Map.String.map(collection =>
        collection->Map.map(sortedCollection =>
          sortedCollection->Map.Int.map(items => AsyncData.Done(Ok(items)))
        )
      ),
      items: store.items->Map.String.map(collection =>
        collection->Map.String.map(items => AsyncData.Done(Ok(items)))
      ),
      listsRequests: Map.String.empty,
      itemsRequests: Map.String.empty,
      page: {
        title: None,
        meta: MutableMap.String.make(),
      },
    }
    let html = ReactDOMServer.renderToString(
      <Context.Provider value={(context, _ => ())}>
        {React.cloneElement(
          app,
          {
            "serverUrl": {
              let path = switch serverUrl {
              | "" | "/" => list{}
              /* remove the preceeding /, which every pathname seems to have */
              | _ =>
                let serverUrl = Js.String.sliceToEnd(~from=1, serverUrl)
                /* remove the trailing /, which some pathnames might have. Ugh */
                let serverUrl = switch Js.String.get(serverUrl, Js.String.length(serverUrl) - 1) {
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
        )}
      </Context.Provider>,
    )
    let initialData: Context.t = {
      lists: context.listsRequests
      ->Map.String.toArray
      ->Array.reduce(Map.String.empty, (acc, (collectionKey, collectionDirections)) =>
        acc->Map.String.update(collectionKey, _ => Some(
          collectionDirections
          ->Map.toArray
          ->Array.reduce(Map.make(~id=module(DirectionComparable)), (acc, (
            direction,
            pagesToRender,
          )) =>
            acc->Map.update(direction, _ =>
              context.lists
              ->Map.String.get(collectionKey)
              ->Option.flatMap(value => value->Map.get(direction))
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
      ->Map.String.toArray
      ->Array.reduce(Map.String.empty, (acc, (collectionKey, idsToRender)) =>
        acc->Map.String.update(collectionKey, _ =>
          context.items
          ->Map.String.get(collectionKey)
          ->Option.flatMap(pages => Some(
            idsToRender->Set.String.reduce(Map.String.empty, (acc, key) =>
              acc->Map.String.update(key, _ => pages->Map.String.get(key))
            ),
          ))
        )
      ),
      listsRequests: Map.String.empty,
      itemsRequests: Map.String.empty,
      page: {
        title: None,
        meta: MutableMap.String.make(),
      },
    }
    (
      serverUrl,
      `<!DOCTYPE html>
      <title>${context.page.title->Option.getWithDefault(
        "",
      )}</title>
      ${context.page.meta
      ->MutableMap.String.toArray
      ->Array.map(((name, value)) => `<meta ${name} value="${value}" />`)
      ->Array.reduce("", (acc, item) =>
        acc ++ item
      )}
      <div id="root">${html}</div><script id="initialData">${initialData
      ->Js.Json.serializeExn
      ->Js.String.replaceByRe(%re("/</g"), `\\u003c`, _)}</script>
      `,
    )
  })->Map.String.fromArray

  let lists =
    store.lists
    ->Map.String.toArray
    ->Array.reduce(Map.String.empty, (acc, (collectionName, collection)) =>
      collection
      ->Map.toArray
      ->Array.reduce(acc, (acc, (direction, sortedCollection)) =>
        sortedCollection
        ->Map.Int.toArray
        ->Array.reduce(acc, (acc, (page, items)) =>
          acc->Map.String.set(
            `api/${collectionName}/pages/${direction->directionAsString}/${page->Int.toString}.json`,
            items->Js.Json.serializeExn,
          )
        )
      )
    )
  let items =
    store.items
    ->Map.String.toArray
    ->Array.reduce(Map.String.empty, (acc, (collectionName, collection)) =>
      collection
      ->Map.String.toArray
      ->Array.reduce(acc, (acc, (id, item)) =>
        acc->Map.String.set(`api/${collectionName}/items/${id}.json`, item->Js.Json.serializeExn)
      )
    )

  prerenderedPages->Map.String.mergeMany(
    Array.concatMany([lists->Map.String.toArray, items->Map.String.toArray]),
  )
}

let prerender = (app, getUrls) => {
  getFiles(app, getUrls)->Js.log
}
