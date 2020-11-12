let fs = require("fs");
let path = require("path");
let webpack = require("webpack");
let HtmlWebpackPlugin = require("html-webpack-plugin");
let CopyWebpackPlugin = require("copy-webpack-plugin");
let InlineTranslationPlugin = require("inline-translations-webpack-plugin");
let StaticWebsiteServer = require("./StaticWebsiteServer.bs");

let args = process.argv.slice(2)
let command = args[0]
let entry = args[1]

global.__ = localeKey => localeKey

let createWebpackConfig = (config) => {
  return {
    entry: path.join(process.cwd(), entry),
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
        templateContent: "",
      }),
      new InlineTranslationPlugin(config.localeFile ? require(path.join(process.cwd(), config.localeFile)) : null)
    ]
      .concat(
        config.publicDirectory ? [new CopyWebpackPlugin({
          patterns: [
            { from: "**/*", to: `public`, context: path.join(process.cwd(), config.publicDirectory) },
          ]
        })] : []
      )
  }
}

let { default: [reactApp, configs] } = require(path.join(process.cwd(), entry))

if (command == "start") {
  let express = require("express")
  let app = express();
  let { createFsFromVolume, Volume } = require("memfs");
  let volume = new Volume();
  let outputFileSystem = createFsFromVolume(volume);
  fs = outputFileSystem
  outputFileSystem.join = path.join.bind(path);
  Promise.all(
    configs.map(config => {
      return new Promise((resolve, reject) => {
        let compiler = webpack(createWebpackConfig(config))
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
        .then(() => {
          StaticWebsiteServer.getFiles(
            reactApp,
            config,
            fs.readFileSync(path.join(process.cwd(), "dist/_source.html"), "utf8")
          )
            .forEach(([filePath, value]) => {
              filePath = filePath.startsWith("/") ? filePath.slice(1) : filePath
              filePath = filePath.startsWith("api/") || filePath.endsWith(".html") ? filePath : filePath + (filePath.endsWith("/") ? "" : "/") + "index.html"
              fs.mkdirSync(path.dirname(path.join(process.cwd(), config.distDirectory, filePath)), { recursive: true });
              fs.writeFileSync(path.join(process.cwd(), config.distDirectory, filePath), value, "utf8")
            })
        })
    })

  )
    .catch(err => console.error(err))
    .then(() => {
      app.use((req, res, next) => {
        let url = req.path;
        let filePath = url.startsWith("/") ? url.slice(1) : url;
        let normalizedFilePath = path.join(process.cwd(), "dist", filePath);
        let pathsToTry = [normalizedFilePath, normalizedFilePath + "/index.html"]
        let returned = false
        for (pathToTry of pathsToTry) {
          if (!returned) {
            let stat = fs.statSync(pathToTry)
            if (stat.isFile()) {
              returned = true
              fs.readFile(pathToTry, (err, data) => {
                if (err) { } else {
                  res.status(200).end(data);
                }
              })
            }
          }
        }
        if (!returned) {
          next()
        }
      });
      app.listen(8094)
      console.log("http://localhost:8094")
    })
    .catch(err => console.error(err))

} else {
  Promise.all(
    configs.map(config => {
      return new Promise((resolve, reject) => {
        let compiler = webpack(createWebpackConfig(config))
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
      }).then(() => {
        StaticWebsiteServer.getFiles(
          reactApp,
          config,
          fs.readFileSync(path.join(process.cwd(), "dist/_source.html"), "utf8")
        )
          .forEach(([filePath, value]) => {
            filePath = filePath.startsWith("/") ? filePath.slice(1) : filePath
            filePath = filePath.startsWith("api/") || filePath.endsWith(".html") ? filePath : filePath + (filePath.endsWith("/") ? "" : "/") + "index.html"
            fs.mkdirSync(path.dirname(path.join(process.cwd(), config.distDirectory, filePath)), { recursive: true });
            fs.writeFileSync(path.join(process.cwd(), config.distDirectory, filePath), value, "utf8")
          })
      })
    })
  )
    .catch(err => console.error(err))

}
