type mode = [#development | #production]
type plugin

let getWebpackConfig: (
  Pages.config,
  mode,
  string,
) => array<{
  "devtool": bool,
  "entry": string,
  "externals": Js.Dict.t<string>,
  "mode": mode,
  "output": {
    "chunkFilename": string,
    "filename": string,
    "jsonpFunction": string,
    "libraryTarget": Js.Undefined.t<string>,
    "path": string,
    "publicPath": string,
  },
  "plugins": array<plugin>,
  "target": string,
}>

let getFiles: (Pages.config, (. string, string) => string, mode) => array<(string, string)>
