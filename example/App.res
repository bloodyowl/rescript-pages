open Belt
open StaticWebsite

module Home = {
  @react.component
  let make = () => {
    <div />
  }
}

module PostList = {
  @react.component
  let make = (~page) => {
    let _posts = useCollection("posts", ~page)
    <div />
  }
}

module Page = {
  @react.component
  let make = (~page) => {
    let _posts = useItem("pages", ~id=page)
    <div />
  }
}

module Post = {
  @react.component
  let make = (~post) => {
    let post = useItem("posts", ~id=post)
    <div>
      {switch post {
      | NotAsked | Loading => "Loading..."->React.string
      | Done(Error(_)) => "Error"->React.string
      | Done(Ok(post)) => <h1> <Title title=post.title /> {post.title->React.string} </h1>
      }}
    </div>
  }
}

module App = {
  @react.component
  let make = (~serverUrl=?) => {
    let {path} = ReasonReactRouter.useUrl(~serverUrl?, ())

    <>
      <Meta name="description" value="My website" />
      {switch path {
      | list{} => <Home />
      | list{"post", post} => <Post post />
      | list{"posts"} => <PostList page={1} />
      | list{"posts", page} => <PostList page={Int.fromString(page)->Option.getWithDefault(1)} />
      | list{page} => <Page page />
      | _ => React.null
      }}
    </>
  }
}

// client
// StaticWebsite.start(<App />)

// server

StaticWebsiteServer.prerender(<App />, store =>
  Array.concatMany([
    ["/"],
    store.items
    ->Map.String.get("pages")
    ->Option.map(Map.String.keysToArray)
    ->Option.getWithDefault([])
    ->Array.map(slug => `/${slug}`),
    store.items
    ->Map.String.get("posts")
    ->Option.map(Map.String.keysToArray)
    ->Option.getWithDefault([])
    ->Array.map(slug => `/post/${slug}`),
    store.lists
    ->Map.String.get("posts")
    ->Option.flatMap(posts => posts->Map.get(#desc))
    ->Option.map(Map.Int.keysToArray)
    ->Option.getWithDefault([])
    ->Array.sliceToEnd(1)
    ->Array.map(page => `/posts/${page->Int.toString}`),
  ])
)->Js.log
