open Belt

module Emotion = {
  @module("@emotion/css") external css: {..} => string = "css"
  @module("@emotion/css") external keyframes: {..} => string = "keyframes"
  @module("@emotion/css") external cx: array<string> => string = "cx"

  @module("@emotion/css") external injectGlobal: string => unit = "injectGlobal"
}

Emotion.injectGlobal(`body {
  margin: 0;
  padding: 0;
  font-family: -apple-system, BlinkMacSystemFont, SF Pro Display, Segoe UI,
    Roboto, Oxygen, Ubuntu, Cantarell, Fira Sans, Droid Sans, Helvetica Neue,
    sans-serif;
  -webkit-font-smoothing: antialiased;
}
#root {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
`)

module WidthContainer = {
  module Styles = {
    open Emotion
    let container = css({
      "width": "100%",
      "maxWidth": 1000,
      "marginLeft": "auto",
      "marginRight": "auto",
      "flexGrow": 1,
      "display": "flex",
      "flexDirection": "column",
    })
  }
  @react.component
  let make = (~children) => {
    <div className=Styles.container> children </div>
  }
}

module MarkdownBody = {
  module Styles = {
    open Emotion
    let text = css({
      "pre": {
        "padding": "10px 20px",
        "backgroundColor": "#F4F7F8",
        "overflowX": "auto",
        "WebkitOverflowScrolling": "touch",
        "fontSize": 16,
        "borderRadius": 8,
      },
      "code": {
        "fontFamily": `SFMono-Regular, Consolas, "Liberation Mono", Menlo, Courier, monospace`,
        "fontSize": "0.85em",
        "lineHeight": 1.0,
      },
      ".hljs-keyword": {"color": "#DA6BB5"},
      ".hljs-constructor": {"color": "#DD792B"},
      ".hljs-identifier": {"color": "#1E9EA7"},
      ".hljs-module-identifier": {"color": "#C84682"},
      ".hljs-string": {"color": "#3BA1C8"},
      ".hljs-comment": {"color": "#aaa"},
      ".hljs-operator": {"color": "#DA6BB5"},
      ".hljs-attribute": {"color": "#4CB877"},
      "blockquote": {
        "opacity": 0.6,
        "borderLeft": `4px solid #333`,
        "margin": 0,
        "padding": "20px 0",
      },
    })
  }
  @react.component
  let make = (~body, ~additionalStyle=?) =>
    <div
      className={switch additionalStyle {
      | Some(additionalStyle) => Emotion.cx([Styles.text, additionalStyle])
      | None => Styles.text
      }}
      dangerouslySetInnerHTML={{"__html": body}}
    />
}

module FeatureBlock = {
  module Styles = {
    open Emotion
    let container = css({
      "padding": 20,
      "flexGrow": 1,
      "display": "flex",
      "flexDirection": "column",
    })
    let title = css({"fontSize": 18, "fontWeight": "normal", "fontWeight": "700"})
    let text = css({
      "fontSize": 14,
      "fontWeight": "normal",
      "flexGrow": 1,
      "display": "flex",
      "flexDirection": "column",
    })
    let additionalStyle = css({
      "flexGrow": 1,
      "display": "flex",
      "flexDirection": "column",
      "pre": {"flexGrow": 1},
    })
  }
  @react.component
  let make = (~title, ~text) => {
    <div className=Styles.container>
      <h2 className=Styles.title> {title->React.string} </h2>
      <div className=Styles.text>
        <MarkdownBody body=text additionalStyle=Styles.additionalStyle />
      </div>
    </div>
  }
}

module Home = {
  module Styles = {
    open Emotion
    let blocks = css({
      "display": "flex",
      "flexDirection": "row",
      "alignItems": "stretch",
      "flexWrap": "wrap",
      "@media (max-width: 600px)": {"flexDirection": "column"},
    })
    let title = css({
      "fontSize": 50,
      "textAlign": "center",
      "padding": "100px 0",
    })
    let block = css({
      "width": "33.3333%",
      "display": "flex",
      "flexDirection": "column",
      "@media (max-width: 600px)": {"width": "100%"},
    })
    let container = css({"flexGrow": 1})
  }
  @react.component
  let make = () => {
    let blocks = Pages.useCollection("features", ~direction=#asc)
    <div className=Styles.container>
      <WidthContainer>
        <div className=Styles.title> {"A dead-simple static website generator"->React.string} </div>
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
    open Emotion
    let container = css({
      "display": "flex",
      "flexDirection": "row",
      "alignItems": "flex-start",
      "flexGrow": 1,
      "position": "relative",
      "@media (max-width: 600px)": {"flexDirection": "column-reverse"},
    })
    let body = css({
      "width": 1,
      "flexGrow": 1,
      "flexShrink": 1,
      "display": "flex",
      "flexDirection": "column",
      "padding": 10,
      "boxSizing": "border-box",
      "@media (max-width: 600px)": {"width": "100%"},
    })

    let column = css({
      "width": 250,
      "boxSizing": "border-box",
      "padding": "20px 10px",
      "flexGrow": 0,
      "flexShrink": 0,
      "display": "flex",
      "flexDirection": "column",
      "position": "sticky",
      "top": 10,
    })
    let link = css({
      "color": "currentColor",
      "textDecoration": "none",
      "display": "block",
      "padding": 10,
    })
    let activeLink = css({"fontWeight": "bold"})
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
    open Emotion
    let resetLink = css({"color": "currentColor", "textDecoration": "none"})
    let activeLink = css({"fontWeight": "bold"})
    let header = css({
      "paddingTop": 10,
      "paddingBottom": 10,
      "margin": 0,
      "backgroundColor": "rgba(0, 0, 0, 0.03)",
    })
    let headerContents = css({
      "display": "flex",
      "flexDirection": "row",
      "alignItems": "center",
      "justifyContent": "space-between",
      "flexWrap": "wrap",
      "paddingLeft": 10,
      "paddingRight": 10,
      "@media(max-width: 400px)": {
        "flexDirection": "column",
      },
    })
    let title = css({"fontSize": 18, "textAlign": "center"})
    let navigation = css({"display": "flex", "flexDirection": "row", "alignItems": "center"})
  }
  @react.component
  let make = () => {
    <div className=Styles.header>
      <WidthContainer>
        <div className=Styles.headerContents>
          <Pages.Link href="/" className=Styles.resetLink>
            <h1 className=Styles.title> {Pages.tr("ReScript Pages")} </h1>
          </Pages.Link>
          <Spacer width="100px" />
          <div className=Styles.navigation>
            <Pages.Link href="/" className=Styles.resetLink activeClassName=Styles.activeLink>
              {Pages.tr("Home")}
            </Pages.Link>
            <Spacer width="40px" />
            <Pages.Link
              href="/docs/getting-started"
              matchHref="/docs"
              className=Styles.resetLink
              activeClassName=Styles.activeLink
              matchSubroutes=true>
              {Pages.tr("Docs")}
            </Pages.Link>
            <Spacer width="40px" />
            <a href="https://github.com/bloodyowl/rescript-pages" className=Styles.resetLink>
              {Pages.tr("GitHub")}
            </a>
          </div>
        </div>
      </WidthContainer>
    </div>
  }
}

module Footer = {
  module Styles = {
    open Emotion
    let container = css({
      "backgroundColor": "#222",
      "color": "#fff",
      "textAlign": "center",
      "padding": 20,
      "fontSize": 14,
    })
  }

  @react.component
  let make = () => {
    <div className=Styles.container> {"Copyright 2020 - Matthias Le Brun"->React.string} </div>
  }
}

module App = {
  module Styles = {
    open Emotion
    let container = css({"display": "flex", "flexDirection": "column", "flexGrow": 1})
  }
  @react.component
  let make = (~url as {RescriptReactRouter.path: path}, ~config as _) => {
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
