open Belt

module Styles = {
  open CssJs
  let title = style(.[textAlign(center), padding(40->px), fontSize(40->px)])
}
module Home = {
  @react.component
  let make = () => {
    <div>
      <Pages.Link href="/post/foo"> {"View my super post >"->React.string} </Pages.Link>
      <br />
      <Pages.Link href="/posts"> {"View post list >"->React.string} </Pages.Link>
    </div>
  }
}

module PostList = {
  @react.component
  let make = (~page=1) => {
    let posts = Pages.useCollection("posts", ~page)
    <>
      {switch posts {
      | NotAsked | Loading => "Loading..."->React.string
      | Done(Error(_)) => "Error"->React.string
      | Done(Ok({items, hasPreviousPage, hasNextPage})) => <>
          <h1>
            <Pages.Head>
              <title> {(`Posts, page ${page->Int.toString} - my website`)->React.string} </title>
            </Pages.Head>
          </h1>
          <ul> {items->Array.map(item => {
              <li key=item.slug>
                <Pages.Link href={`/post/${item.slug}`}> {item.title->React.string} </Pages.Link>
              </li>
            })->React.array} </ul>
          {hasPreviousPage
            ? <Pages.Link href={`/posts/${(page - 1)->Int.toString}`}>
                {"Previous page"->React.string}
              </Pages.Link>
            : React.null}
          {hasNextPage
            ? <Pages.Link href={`/posts/${(page + 1)->Int.toString}`}>
                {"Next page"->React.string}
              </Pages.Link>
            : React.null}
        </>
      }}
    </>
  }
}

module Page = {
  @react.component
  let make = (~page) => {
    let _posts = Pages.useItem("pages", ~id=page)
    <div />
  }
}

module Post = {
  @react.component
  let make = (~post) => {
    let post = Pages.useItem("posts", ~id=post)
    <div>
      <Pages.Link href="/"> {"< Go back to the homepage"->React.string} </Pages.Link>
      {switch post {
      | NotAsked | Loading => "Loading..."->React.string
      | Done(Error(_)) => "Error"->React.string
      | Done(Ok(post)) => <>
          <h1>
            <Pages.Head>
              <title> {(`${post.title} - my website`)->React.string} </title>
              <meta name="description" value={post.title} />
            </Pages.Head>
            {post.title->React.string}
          </h1>
          {"Contents:"->React.string}
          <div dangerouslySetInnerHTML={{"__html": post.body}} />
        </>
      }}
    </div>
  }
}

module App = {
  @react.component
  let make = (~serverUrl=?) => {
    let {path} = ReasonReactRouter.useUrl(~serverUrl?, ())
    let (prefix, path) = switch path {
    | list{"en", ...rest} => ("/en/", rest)
    | rest => ("/", rest)
    }
    <>
      <Pages.Head> <style> {"html { font-family: sans-serif }"->React.string} </style> </Pages.Head>
      <Pages.Link href=prefix>
        <h1 className=Styles.title> {"ReScript Pages"->React.string} </h1>
      </Pages.Link>
      {switch path {
      | list{} => <Home />
      | list{"post", post} => <Post post />
      | list{"posts"} => <PostList />
      | list{"posts", page} => <PostList page={Int.fromString(page)->Option.getWithDefault(1)} />
      | list{"404.html"} => <div> {"Page not found..."->React.string} </div>
      | list{page} => <Page page />
      | _ => <div> {"Page not found..."->React.string} </div>
      }}
    </>
  }
}

let getUrlsToPrerender = ({Pages.getAll: getAll, getPages}) =>
  Array.concatMany([
    ["/"],
    getAll("pages")->Array.map(slug => `/${slug}`),
    getAll("posts")->Array.map(slug => `/post/${slug}`),
    ["/posts"],
    getPages("posts")->Array.map(page => `/posts/${page->Int.toString}`),
    ["404.html"],
  ])

let default = Pages.make(
  <App />,
  {
    siteTitle: "bloodyowl",
    siteDescription: "My site",
    distDirectory: "dist",
    baseUrl: "https://bloodyowl.io",
    staticsDirectory: Some("public"),
    paginateBy: 2,
    variants: [
      {
        subdirectory: None,
        localeFile: None,
        contentDirectory: "contents",
        getUrlsToPrerender: getUrlsToPrerender,
      },
      {
        subdirectory: Some("en"),
        localeFile: None,
        contentDirectory: "contents",
        getUrlsToPrerender: getUrlsToPrerender,
      },
    ],
  },
)
