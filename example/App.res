open Belt
open StaticWebsite

module Home = {
  @react.component
  let make = () => {
    <div>
      {"Welcome to the home"->React.string}
      <Link href="/post/foo"> {"View post"->React.string} </Link>
    </div>
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
      | Done(Ok(post)) =>
        <h1>
          <Head>
            <title> {post.title->React.string} </title>
            <meta name="description" value={post.title} />
          </Head>
          {post.title->React.string}
        </h1>
      }}
    </div>
  }
}

module App = {
  @react.component
  let make = (~serverUrl=?) => {
    let {path} = ReasonReactRouter.useUrl(~serverUrl?, ())
    <>
      <Head>
        <title> {"My fancy website"->React.string} </title>
        <meta name="description" value="My website" />
      </Head>
      {switch path {
      | list{} => <Home />
      | list{"post", post} => <Post post />
      | list{"posts"} => <PostList page={1} />
      | list{"posts", page} => <PostList page={Int.fromString(page)->Option.getWithDefault(1)} />
      | list{"404.html"} => <div> {"Page not found..."->React.string} </div>
      | list{page} => <Page page />
      | _ => <div> {"Page not found..."->React.string} </div>
      }}
    </>
  }
}

let default = StaticWebsite.make(
  <App />,
  [
    {
      contentDirectory: "contents",
      distDirectory: "dist",
      publicPath: "/",
      publicDirectory: None,
      localeFile: None,
      getUrlsToPrerender: ({getAll, getPages}) =>
        Array.concatMany([
          ["/"],
          getAll("pages")->Array.map(slug => `/${slug}`),
          getAll("posts")->Array.map(slug => `/post/${slug}`),
          getPages("posts")->Array.map(page => `/posts/${page->Int.toString}`),
          ["404.html"],
        ]),
      cname: None,
    },
  ],
)
