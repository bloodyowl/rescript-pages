type mode = [#development | #production]
type plugin

let getWebpackConfig: (
  Pages.config,
  mode,
  string,
) => array<{
  "devtool": bool,
  "entry": string,
  "externals": Dict.t<string>,
  "mode": mode,
  "resolve": {"modules": array<string>, "alias": Dict.t<string>},
  "experiments": {"outputModule": bool},
  "output": {
    "chunkFilename": string,
    "filename": string,
    "libraryTarget": Nullable.t<string>,
    "path": string,
    "publicPath": string,
  },
  "plugins": array<plugin>,
  "target": string,
}>

let getFiles: (Pages.config, (string, string) => string, mode) => Promise.t<array<(string, string)>>
