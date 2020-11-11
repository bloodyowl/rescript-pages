let path = require("path");
let webpack = require("webpack");
let HtmlWebpackPlugin = require("html-webpack-plugin");
let CopyWebpackPlugin = require("copy-webpack-plugin");
let InlineTranslationPlugin = require("inline-translations-webpack-plugin");

let args = process.argv.slice(2)
let command = args[0]
let entry = args[1]

global.__ = localeKey => localeKey

let createWebpackConfig = (config) => {
  return {
    entry: entry,
    mode: command == "build" ? "production" : "development",
    devtool: false,
    output: {
      path: path.join(process.cwd(), config.distDirectory),
      publicPath: config.publicPath,
      filename: `public/[name].[hash].js`,
      chunkFilename: `public/chunks/[contenthash].js`,
      globalObject: "this",
      jsonpFunction: "staticWebsite__d"
    },
    plugins: [
      new HtmlWebpackPlugin({
        filename: `_source.html`,
        templateContents: "",
      }),
      new InlineTranslationPlugin(config.localeFile ? require(config.localeFile) : null)
    ]
      .concat(
        config.publicDirectory ? [new CopyWebpackPlugin([
          { from: "**/*", to: `public`, context: config.publicDirectory },
        ])] : []
      )
  }
}

let { default: [_app, configs] } = require(entry)
let webpackConfigs = configs.map(createWebpackConfig);
let compilers = webpackConfigs.map(webpack)

if (command == "start") {
  let app = express();
  let { createFsFromVolume, Volume } = require("memfs");
  let volume = new Volume();
  let outputFileSystem = createFsFromVolume(volume);
  outputFileSystem.join = path.join.bind(path);
  compilers.forEach(compiler => {
    compiler.outputFileSystem = outputFileSystem;
    compiler.run((error, stats) => {
      if (error) {
        reject(error);
      } else {
        if (stats.hasErrors()) {
          let errors = stats.toJson().errors.join("\n");
          reject(errors);
        } else {
          resolve()
        }
      }
    })
  })
} else {
  compilers.forEach(compiler => {
    compiler.run((error, stats) => {
      if (error) {
        reject(error);
      } else {
        if (stats.hasErrors()) {
          let errors = stats.toJson().errors.join("\n");
          reject(errors);
        } else {
          resolve()
        }
      }
    })
  })
}
