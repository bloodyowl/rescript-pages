open Belt
include CssReset

module WidthContainer = {
  module Styles = {
    open Emotion
    let container = css({
      "width": "100%",
      "maxWidth": 1000,
      "margin": "0 auto",
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
        "overflowX": "auto",
        "fontSize": 16,
        "borderRadius": 8,
      },
      "code": {
        "fontFamily": `SFMono-Regular, Consolas, "Liberation Mono", Menlo, Courier, monospace`,
        "fontSize": "0.85em",
        "lineHeight": 1.0,
      },
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

module BlockGrid = {
  module Styles = {
    open Emotion
    let blocks = css({
      "display": "flex",
      "flexDirection": "row",
      "alignItems": "stretch",
      "flexWrap": "wrap",
      "@media (max-width: 600px)": {"flexDirection": "column"},
    })
    let contentsAppear = keyframes({"from": {"opacity": 0.0, "transform": "translateY(10px)"}})
    let block = css({
      "display": "flex",
      "flexDirection": "column",
      "animation": `300ms ease-out ${contentsAppear} backwards`,
      "@media (max-width: 600px)": {"width": "100%"},
    })
  }
  @react.component
  let make = (~children, ~width) => {
    <div className=Styles.blocks>
      {children->React.Children.mapWithIndex((item, index) =>
        <div
          key={index->Int.toString}
          style={ReactDOM.Style.make(~animationDelay=`${(index * 200)->Int.toString}ms`, ())}
          className={Emotion.cx([Styles.block, Emotion.css({"width": width})])}>
          {item}
        </div>
      )}
    </div>
  }
}

module Home = {
  module Styles = {
    open Emotion
    let title = css({
      "fontSize": 50,
      "textAlign": "center",
      "padding": "100px 0",
      "position": "relative",
      "background": "#eee",
      "color": "#222",
    })
    let logo = css({
      "height": "auto",
      "display": "block",
      "margin": "0 auto",
    })
    let container = css({"flexGrow": 1})
  }
  @react.component
  let make = () => {
    let blocks = Pages.useCollection("features", ~direction=#asc)
    <div className=Styles.container>
      <div className=Styles.title>
        <img
          src={Pages.makeVariantUrl("Logo.png")} width="256" height="256" className=Styles.logo
        />
        {"A dead-simple static website generator"->React.string}
      </div>
      {switch blocks {
      | NotAsked | Loading => <Pages.ActivityIndicator />
      | Done(Error(_)) => <Pages.ErrorIndicator />
      | Done(Ok({items})) =>
        <WidthContainer>
          <BlockGrid width="33.3333%">
            {items
            ->Array.map(block => <FeatureBlock title=block.title text=block.summary />)
            ->React.array}
          </BlockGrid>
        </WidthContainer>
      }}
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
    let loader = css({
      "display": "flex",
      "flexGrow": 1,
      "alignItems": "center",
      "justifyContent": "center",
      "padding": "50px 20px",
    })
    let contentsAppear = keyframes({"from": {"opacity": 0.0, "transform": "translateY(10px)"}})
    let contents = css({"animation": `300ms ease-out ${contentsAppear}`})
    let body = css({
      "width": 1,
      "flexGrow": 1,
      "flexShrink": 1,
      "display": "flex",
      "flexDirection": "column",
      "alignSelf": "stretch",
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
          | NotAsked | Loading =>
            <div className=Styles.loader>
              <Pages.ActivityIndicator />
            </div>
          | Done(Error(_)) => <Pages.ErrorIndicator />
          | Done(Ok({items})) =>
            <>
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
          | NotAsked | Loading =>
            <div className=Styles.loader>
              <Pages.ActivityIndicator />
            </div>
          | Done(Error(_)) => <Pages.ErrorIndicator />
          | Done(Ok(item)) =>
            <div className=Styles.contents>
              <h1> {item.title->React.string} </h1>
              <MarkdownBody body=item.body />
            </div>
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
    let link = cx([resetLink, css({"padding": "10px"})])
    let activeLink = css({"fontWeight": "bold"})
    let header = css({
      "paddingTop": 10,
      "paddingBottom": 10,
      "margin": 0,
      "backgroundColor": "rgba(0, 0, 0, 0.03)",
      "position": "relative",
    })
    let headerContents = css({
      "display": "flex",
      "flexDirection": "row",
      "alignItems": "center",
      "justifyContent": "space-between",
      "flexWrap": "wrap",
      "@media(max-width: 600px)": {
        "flexDirection": "column",
      },
    })
    let title = css({
      "fontSize": 18,
      "textAlign": "center",
      "padding": "0 10px",
      "display": "flex",
      "flexDirection": "row",
      "alignItems": "center",
    })
    let navigation = css({
      "display": "flex",
      "flexDirection": "row",
      "justifyContent": "center",
      "alignItems": "center",
    })
  }
  let links = [
    (Pages.tr("Home"), "/", None),
    (Pages.tr("Showcase"), "/showcase", None),
    (Pages.tr("Docs"), "/docs/getting-started", Some("/docs")),
  ]
  @react.component
  let make = () => {
    <div className=Styles.header>
      <WidthContainer>
        <div className=Styles.headerContents>
          <Pages.Link href="/" className=Styles.resetLink>
            <h1 className=Styles.title>
              <img src={Pages.makeVariantUrl("Logo.png")} width="64" height="64" />
              <span> {Pages.tr("ReScript Pages")} </span>
            </h1>
          </Pages.Link>
          <Spacer width="100px" />
          <div className=Styles.navigation>
            {links
            ->Array.map(((text, href, matchHref)) =>
              <React.Fragment key=href>
                <Pages.Link
                  href
                  ?matchHref
                  className=Styles.link
                  activeClassName=Styles.activeLink
                  matchSubroutes={matchHref->Option.isSome}>
                  {text}
                </Pages.Link>
              </React.Fragment>
            )
            ->React.array}
            <a href="https://github.com/bloodyowl/rescript-pages" className=Styles.link>
              {Pages.tr("GitHub")}
            </a>
          </div>
        </div>
      </WidthContainer>
    </div>
  }
}

module ShowcaseWebsite = {
  module Styles = {
    open Emotion
    let container = css({
      "padding": 20,
      "flexGrow": 1,
      "display": "flex",
      "flexDirection": "column",
      "color": "inherit",
      "textDecoration": "none",
    })
    let title = css({
      "fontSize": 18,
      "fontWeight": "normal",
      "fontWeight": "700",
      "textAlign": "center",
    })
    let imageContainer = css({
      "overflow": "hidden",
      "position": "relative",
      "paddingBottom": {
        let ratio = 9.0 /. 16.0 *. 100.0
        `${ratio->Float.toString}%`
      },
      "borderRadius": 15,
      "boxShadow": "0 0 0 1px rgba(0, 0, 0, 0.1), 0 15px 20px rgba(0, 0, 0, 0.1)",
      "transform": "translateZ(0)",
    })
    let imageContents = css({
      "position": "absolute",
      "top": "-100%",
      "left": 0,
      "right": 0,
      "bottom": 0,
      "transition": "5000ms ease-out transform",
      "transform": "translateZ(0)",
      "@media (hover: hover)": {
        ":hover": {"transform": "translateZ(0) translateY(50%)"},
      },
    })
    let image = css({
      "position": "absolute",
      "top": "50%",
      "left": 0,
      "width": "100%",
      "height": "auto",
      "transition": "300ms ease-out opacity, 5000ms ease-out transform",
      "opacity": 0.0,
      "transform": "translateZ(0)",
      "@media (hover: hover)": {
        ":hover": {"transform": "translateZ(0) translateY(-100%)"},
      },
    })
    let loadedImage = cx([image, css({"opacity": 1.0})])
  }

  external elementAsObject: Dom.element => {..} = "%identity"

  @react.component
  let make = (~title, ~url, ~image) => {
    let imageRef = React.useRef(Js.Nullable.null)
    let (imageRatio, setImageRatio) = React.useState(() => None)

    React.useEffect0(() => {
      switch imageRef.current->Js.Nullable.toOption {
      | Some(image) =>
        let image = image->elementAsObject
        Js.log(image["complete"])
        if image["complete"] {
          setImageRatio(_ => Some(image["naturalHeight"] /. image["naturalWidth"]))
        }
      | _ => ()
      }
      None
    })

    <a href=url className=Styles.container target="_blank">
      <h2 className=Styles.title> {title->React.string} </h2>
      <div className=Styles.imageContainer>
        <div
          className=Styles.imageContents
          style=?{imageRatio->Option.map(ratio =>
            ReactDOM.Style.make(~transitionDuration={Float.toString(ratio *. 2000.) ++ "ms"}, ())
          )}>
          <img
            ref={ReactDOM.Ref.domRef(imageRef)}
            className={imageRatio->Option.isSome ? Styles.loadedImage : Styles.image}
            onLoad={event => {
              let target = event->ReactEvent.Image.target
              setImageRatio(_ => Some(target["naturalHeight"] /. target["naturalWidth"]))
            }}
            style=?{imageRatio->Option.map(ratio =>
              ReactDOM.Style.make(
                ~transitionDuration={"300ms, " ++ Float.toString(ratio *. 2000.) ++ "ms"},
                (),
              )
            )}
            alt=""
            src=image
          />
        </div>
      </div>
    </a>
  }
}

module Showcase = {
  module Styles = {
    open Emotion
    let container = css({
      "display": "flex",
      "flexDirection": "column",
      "flexGrow": 1,
    })
    let title = css({
      "fontSize": 40,
      "textAlign": "center",
      "padding": "30px 0",
    })
  }

  @react.component
  let make = () => {
    <WidthContainer>
      <div className=Styles.container>
        <div className=Styles.title> {"Showcase"->React.string} </div>
        <BlockGrid width="50%">
          {ShowcaseWebsiteList.websites
          ->Array.map(website => {
            <ShowcaseWebsite title=website.title url=website.url image=website.image />
          })
          ->React.array}
        </BlockGrid>
      </div>
    </WidthContainer>
  }
}

module App = {
  module Styles = {
    open Emotion
    let container = css({"display": "flex", "flexDirection": "column", "flexGrow": 1})
    let footer = css({
      "backgroundColor": "#222",
      "color": "#fff",
      "textAlign": "center",
      "padding": 20,
      "fontSize": 14,
    })
  }
  @react.component(: Pages.ProvidedApp.props<RescriptReactRouter.url, Pages.config>)
  let make = (~url as {RescriptReactRouter.path: path}, ~config as _) => {
    <div className=Styles.container>
      <Pages.Head>
        <meta content="width=device-width, initial-scale=1, shrink-to-fit=no" name="viewport" />
      </Pages.Head>
      <Header />
      {switch path {
      | list{} =>
        <>
          <Home />
        </>
      | list{"showcase"} =>
        <>
          <Showcase />
        </>
      | list{"docs", slug} =>
        <>
          <Docs slug />
        </>
      | list{"404.html"} => <div> {"Page not found..."->React.string} </div>
      | _ => <div> {"Page not found..."->React.string} </div>
      }}
      <div className=Styles.footer> {"Copyright 2021 - Matthias Le Brun"->React.string} </div>
    </div>
  }
}

let getUrlsToPrerender = ({Pages.getAll: getAll}) =>
  Array.concatMany([
    ["/", "showcase"],
    getAll("docs")->Array.map(slug => `/docs/${slug}`),
    ["404.html"],
  ])

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
        getUrlsToPrerender,
        getRedirectMap: Some(
          _ => {
            Js.Dict.fromArray([("old_url", "new_url")])
          },
        ),
      },
    ],
  },
)
