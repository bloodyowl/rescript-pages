open Belt
open StaticWebsite

module Styles = {
  open Css
  let title = style(list{color(blue)})
}
module Home = {
  @react.component
  let make = () => {
    <div>
      <h1 className=Styles.title> {"Welcome to the home page"->React.string} </h1>
      <br />
      <Link href="/post/foo"> {"View my super post >"->React.string} </Link>
      <br />
      <Link href="/posts"> {"View post list >"->React.string} </Link>
    </div>
  }
}

module PostList = {
  @react.component
  let make = (~page=1) => {
    let posts = useCollection("posts", ~page)
    <>
      {switch posts {
      | NotAsked | Loading => "Loading..."->React.string
      | Done(Error(_)) => "Error"->React.string
      | Done(Ok({items, hasPreviousPage, hasNextPage})) => <>
          <h1>
            <Head>
              <title> {(`Posts, page ${page->Int.toString} - my website`)->React.string} </title>
            </Head>
          </h1>
          <ul> {items->Array.map(item => {
              <li key=item.slug>
                <Link href={`/post/${item.slug}`}> {item.title->React.string} </Link>
              </li>
            })->React.array} </ul>
          {hasPreviousPage
            ? <Link href={`/posts/${(page - 1)->Int.toString}`}>
                {"Previous page"->React.string}
              </Link>
            : React.null}
          {hasNextPage
            ? <Link href={`/posts/${(page + 1)->Int.toString}`}> {"Next page"->React.string} </Link>
            : React.null}
        </>
      }}
    </>
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
      <Link href="/"> {"< Go back to the homepage"->React.string} </Link>
      {switch post {
      | NotAsked | Loading => "Loading..."->React.string
      | Done(Error(_)) => "Error"->React.string
      | Done(Ok(post)) => <>
          <h1>
            <Head>
              <title> {(`${post.title} - my website`)->React.string} </title>
              <meta name="description" value={post.title} />
            </Head>
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
    <>
      <Head>
        <title> {"My fancy website"->React.string} </title>
        <meta name="description" value="My website" />
        <style> {"html { font-family: sans-serif }"->React.string} </style>
      </Head>
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
          ["/posts"],
          getPages("posts")->Array.map(page => `/posts/${page->Int.toString}`),
          ["404.html"],
        ]),
      cname: None,
      paginateBy: 2,
    },
    {
      contentDirectory: "contents",
      distDirectory: "dist/en",
      publicPath: "/en",
      publicDirectory: None,
      localeFile: None,
      getUrlsToPrerender: ({getAll, getPages}) =>
        Array.concatMany([
          ["/"],
          getAll("pages")->Array.map(slug => `/${slug}`),
          getAll("posts")->Array.map(slug => `/post/${slug}`),
          ["/posts"],
          getPages("posts")->Array.map(page => `/posts/${page->Int.toString}`),
          ["404.html"],
        ]),
      cname: None,
      paginateBy: 2,
    },
  ],
)
