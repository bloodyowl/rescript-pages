open Belt

module Styles = {
  open CssJs
  global(.
    "body",
    [
      margin(zero),
      padding(zero),
      fontFamilies([
        #custom("-apple-system"),
        #custom("BlinkMacSystemFont"),
        #custom("SF Pro Display"),
        #custom("Segoe UI"),
        #custom("Roboto"),
        #custom("Oxygen"),
        #custom("Ubuntu"),
        #custom("Cantarell"),
        #custom("Fira Sans"),
        #custom("Droid Sans"),
        #custom("Helvetica Neue"),
        #sansSerif,
      ]),
    ],
  )
}

module WidthContainer = {
  module Styles = {
    open CssJs
    let container = style(.[
      width(100.0->pct),
      maxWidth(1000->px),
      marginLeft(auto),
      marginRight(auto),
    ])
  }
  @react.component
  let make = (~children) => {
    <div className=Styles.container> children </div>
  }
}

module FeatureBlock = {
  module Styles = {
    open CssJs
    let container = style(.[padding(20->px)])
    let title = style(.[fontSize(18->px), fontWeight(normal)])
    let text = style(.[fontSize(14->px), fontWeight(normal)])
  }
  @react.component
  let make = (~title, ~text) => {
    <div className=Styles.container>
      <h2 className=Styles.title> {title->React.string} </h2>
      <div className=Styles.text dangerouslySetInnerHTML={{"__html": text}} />
    </div>
  }
}

module Home = {
  module Styles = {
    open CssJs
    let blocks = style(.[display(flexBox), flexDirection(row), flexWrap(wrap)])
    let block = style(.[width(33.333->pct)])
  }
  @react.component
  let make = () => {
    let blocks = Pages.useCollection("features", ~direction=#asc)
    <div>
      <WidthContainer>
        <div className=Styles.blocks>
          {switch blocks {
          | NotAsked | Loading | Done(Error(_)) => React.null
          | Done(Ok({items})) =>
            items
            ->Array.map(block =>
              <div className=Styles.block key=block.slug>
                <FeatureBlock title=block.title text=block.summary />
              </div>
            )
            ->React.array
          }}
        </div>
      </WidthContainer>
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

module Header = {
  module Styles = {
    open CssJs
    let titleLink = style(.[color(currentColor), textDecoration(none)])
    let header = style(.[
      textAlign(center),
      padding(40->px),
      paddingTop(150->px),
      paddingBottom(150->px),
      margin(zero),
      color("fff"->hex),
      backgroundColor("0A296A"->hex),
    ])
    let title = style(.[fontSize(50->px)])
  }
  @react.component
  let make = () => {
    <div className=Styles.header>
      <Pages.Link href="/" className=Styles.titleLink>
        <h1 className=Styles.title> {"ReScript Pages"->React.string} </h1>
      </Pages.Link>
    </div>
  }
}

module App = {
  @react.component
  let make = (~url as {ReasonReact.Router.path: path}, ~config as _) => {
    <div>
      <Pages.Head> <style> {"html { font-family: sans-serif }"->React.string} </style> </Pages.Head>
      <Header />
      {switch path {
      | list{} => <Home />
      | list{"post", post} => <Post post />
      | list{"posts"} => <PostList />
      | list{"posts", page} => <PostList page={Int.fromString(page)->Option.getWithDefault(1)} />
      | list{"404.html"} => <div> {"Page not found..."->React.string} </div>
      | list{page} => <Page page />
      | _ => <div> {"Page not found..."->React.string} </div>
      }}
    </div>
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
  App.make,
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
