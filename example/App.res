open Belt

let smallViewport = CssJs.media("(max-width: 600px)")

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
  global(. "#root", [minHeight(100.0->vh), display(flexBox), flexDirection(column)])
}

module WidthContainer = {
  module Styles = {
    open CssJs
    let container = style(.[
      width(100.0->pct),
      maxWidth(1000->px),
      marginLeft(auto),
      marginRight(auto),
      flexGrow(1.0),
    ])
  }
  @react.component
  let make = (~children) => {
    <div className=Styles.container> children </div>
  }
}

module MarkdownBody = {
  module Styles = {
    open CssJs
    let text = style(.[
      selector(
        "pre",
        [
          padding2(~v=10->px, ~h=20->px),
          backgroundColor("F4F7F8"->hex),
          overflowX(auto),
          unsafe("WebkitOverflowScrolling", "touch"),
          fontSize(16->px),
          borderLeftWidth(2->px),
          borderLeftColor("46515B"->hex),
          borderLeftStyle(solid),
        ],
      ),
      selector(
        "code",
        [
          fontFamilies([
            #custom("SFMono-Regular"),
            #custom("Consolas"),
            #custom("Liberation Mono"),
            #custom("Menlo"),
            #custom("Courier"),
            #custom("monospace"),
          ]),
          fontSize(0.85->em),
          lineHeight(#abs(1.)),
        ],
      ),
      selector(".hljs-keyword", [color("DA6BB5"->hex)]),
      selector(".hljs-constructor", [color("DD792B"->hex)]),
      selector(".hljs-identifier", [color("1E9EA7"->hex)]),
      selector(".hljs-module-identifier", [color("C84682"->hex)]),
      selector(".hljs-string", [color("3BA1C8"->hex)]),
      selector(".hljs-comment", [color("aaa"->hex)]),
      selector(".hljs-operator", [color("DA6BB5"->hex)]),
      selector(".hljs-attribute", [color("4CB877"->hex)]),
      selector("table", [width(100.->pct), textAlign(center)]),
      selector("table thead th", [backgroundColor("E4EBEE"->hex), padding2(~v=10->px, ~h=zero)]),
      selector(
        "blockquote",
        [
          opacity(0.6),
          borderLeft(4->px, solid, "46515B"->hex),
          margin(zero),
          padding2(~h=20->px, ~v=zero),
        ],
      ),
    ])
  }
  @react.component
  let make = (~body) => <div className=Styles.text dangerouslySetInnerHTML={{"__html": body}} />
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
      <div className=Styles.text> <MarkdownBody body=text /> </div>
    </div>
  }
}

module Home = {
  module Styles = {
    open CssJs
    let blocks = style(.[
      display(flexBox),
      flexDirection(row),
      flexWrap(wrap),
      smallViewport([flexDirection(column)]),
    ])
    let block = style(.[width(33.333->pct), smallViewport([width(100.0->pct)])])
    let container = style(.[flexGrow(1.0)])
  }
  @react.component
  let make = () => {
    let blocks = Pages.useCollection("features", ~direction=#asc)
    <div className=Styles.container>
      <WidthContainer>
        <div className=Styles.blocks>
          {switch blocks {
          | NotAsked | Loading => <Pages.ActivityIndicator />
          | Done(Error(_)) => <Pages.ErrorIndicator />
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
    </div>
  }
}

module Docs = {
  module Styles = {
    open CssJs
    let container = style(.[
      display(flexBox),
      flexDirection(row),
      alignItems(stretch),
      flexGrow(1.0),
      smallViewport([flexDirection(columnReverse)]),
    ])
    let body = style(.[
      flexGrow(1.0),
      flexShrink(1.0),
      display(flexBox),
      flexDirection(column),
      padding(10->px),
    ])

    let column = style(.[
      width(250->px),
      boxSizing(borderBox),
      padding2(~v=20->px, ~h=10->px),
      flexGrow(0.0),
      flexShrink(0.0),
      display(flexBox),
      flexDirection(column),
    ])
    let link = style(.[color(currentColor), textDecoration(none), display(block), padding(10->px)])
    let activeLink = style(.[fontWeight(bold)])
  }
  @react.component
  let make = (~slug) => {
    let item = Pages.useItem("docs", ~id=slug)
    let list = Pages.useCollection("docs", ~direction=#asc)
    <WidthContainer>
      <div className=Styles.container>
        <div className=Styles.column>
          {switch list {
          | NotAsked | Loading => <Pages.ActivityIndicator />
          | Done(Error(_)) => <Pages.ErrorIndicator />
          | Done(Ok({items})) => <>
              {items
              ->Array.map(item =>
                <Pages.Link
                  href={`/docs/${item.slug}`}
                  className=Styles.link
                  activeClassName=Styles.activeLink
                  key={item.slug}>
                  {item.title->React.string}
                </Pages.Link>
              )
              ->React.array}
            </>
          }}
        </div>
        <div className=Styles.body>
          {switch item {
          | NotAsked | Loading => <Pages.ActivityIndicator />
          | Done(Error(_)) => <Pages.ErrorIndicator />
          | Done(Ok(item)) => <>
              <h1> {item.title->React.string} </h1> <MarkdownBody body=item.body />
            </>
          }}
        </div>
      </div>
    </WidthContainer>
  }
}

module Spacer = {
  @react.component
  let make = (~width="10px", ~height="10px") =>
    <div style={ReactDOM.Style.make(~width, ~height, ~flexShrink="0", ~flexGrow="0", ())} />
}

module Header = {
  module Styles = {
    open CssJs
    let resetLink = style(.[color(currentColor), textDecoration(none)])
    let activeLink = style(.[fontWeight(bold)])
    let header = style(.[
      padding(40->px),
      paddingTop(20->px),
      paddingBottom(20->px),
      margin(zero),
      display(flexBox),
      flexDirection(row),
      alignItems(center),
      justifyContent(spaceBetween),
      color("fff"->hex),
      backgroundColor("0A296A"->hex),
    ])
    let title = style(.[fontSize(50->px), smallViewport([fontSize(18->px)])])
    let navigation = style(.[display(flexBox), flexDirection(row), alignItems(center)])
  }
  @react.component
  let make = () => {
    <div className=Styles.header>
      <Pages.Link href="/" className=Styles.resetLink>
        <h1 className=Styles.title> {Pages.tr("ReScript Pages")} </h1>
      </Pages.Link>
      <div className=Styles.navigation>
        <Pages.Link href="/" className=Styles.resetLink activeClassName=Styles.activeLink>
          {Pages.tr("Home")}
        </Pages.Link>
        <Spacer width="20px" />
        <Pages.Link
          href="/docs/getting-started"
          matchHref="/docs"
          className=Styles.resetLink
          activeClassName=Styles.activeLink
          matchSubroutes=true>
          {Pages.tr("Docs")}
        </Pages.Link>
        <Spacer width="20px" />
        <a href="https://github.com/bloodyowl/rescript-pages" className=Styles.resetLink>
          {Pages.tr("GitHub")}
        </a>
      </div>
    </div>
  }
}

module Footer = {
  module Styles = {
    open CssJs
    let container = style(.[
      backgroundColor("222"->hex),
      color("fff"->hex),
      textAlign(center),
      padding(20->px),
      fontSize(14->px),
    ])
  }

  @react.component
  let make = () => {
    <div className=Styles.container>
      {"Copyright 2020 - Matthias Le Brun"->ReasonReact.string}
    </div>
  }
}

module App = {
  module Styles = {
    open CssJs
    let container = style(.[display(flexBox), flexDirection(column), flexGrow(1.0)])
  }
  @react.component
  let make = (~url as {ReasonReact.Router.path: path}, ~config as _) => {
    <div className=Styles.container>
      <Pages.Head>
        <meta content="width=device-width, initial-scale=1, shrink-to-fit=no" name="viewport" />
        <style> {"html { font-family: sans-serif }"->React.string} </style>
      </Pages.Head>
      <Header />
      {switch path {
      | list{} => <> <Home /> </>
      | list{"docs", slug} => <> <Docs slug /> </>
      | list{"404.html"} => <div> {"Page not found..."->React.string} </div>
      | _ => <div> {"Page not found..."->React.string} </div>
      }}
      <Footer />
    </div>
  }
}

let getUrlsToPrerender = ({Pages.getAll: getAll}) =>
  Array.concatMany([["/"], getAll("docs")->Array.map(slug => `/docs/${slug}`), ["404.html"]])

let default = Pages.make(
  App.make,
  {
    siteTitle: "ReScript Pages",
    mode: SPA,
    siteDescription: "A static website generator",
    distDirectory: "dist",
    baseUrl: "https://bloodyowl.github.io/rescript-pages",
    staticsDirectory: Some("statics"),
    paginateBy: 2,
    variants: [
      {
        subdirectory: None,
        localeFile: None,
        contentDirectory: "contents",
        getUrlsToPrerender: getUrlsToPrerender,
        getRedirectMap: Some(
          _ => {
            Js.Dict.fromArray([("old_url", "new_url")])
          },
        ),
      },
    ],
  },
)
