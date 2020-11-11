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

StaticWebsite.make(
  ~contentDirectory="contents",
  ~getUrlsToPrerender=({getAll, getPages}) =>
    Array.concatMany([
      ["/"],
      getAll("pages")->Array.map(slug => `/${slug}`),
      getAll("posts")->Array.map(slug => `/post/${slug}`),
      getPages("posts")->Array.map(page => `/posts/${page->Int.toString}`),
    ]),
  ~cname="bloodyowl.io",
  <App />,
)
