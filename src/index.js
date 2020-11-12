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

function createWebpackConfig(config) {
  let clientConfig = {
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
  };
  return [
    clientConfig,
    {
      entry: path.join(process.cwd(), entry),
      mode: "development",
      devtool: false,
      target: "node",
      output: {
        libraryTarget: "commonjs2",
        path: path.join(process.cwd(), config.distDirectory),
        publicPath: config.publicPath,
        filename: `_entry.js`,
        chunkFilename: `public/chunks/[contenthash].js`,
      },
      externals: {
        'react': 'commonjs2 react',
        'react-dom': 'commonjs2 react-dom',
        'react-dom-server': 'commonjs2 react-dom-server',
        'react-helmet': 'commonjs2 react-helmet',
        'bs-platform': 'commonjs2 bs-platform',
        'emotion': 'commonjs2 emotion',
      }
    },
  ]
}

function createWebsocketServer(port) {
  let WebSocket = require("ws");
  let server = new WebSocket.Server({
    port: port,
  })
  let openedConnections = [];
  server.on("connection", ws => {
    openedConnections.push(ws)
    ws.on("close", () => {
      openedConnections = openedConnections.filter(item => item != ws)
    })
  })
  return {
    send: (message) => {
      openedConnections.forEach(ws => ws.send(message))
    }
  }
}

function requireFresh(path) {
  delete require.cache[path]
  return require(path)
}

function prerenderForConfig(config, html) {
  let entry = requireFresh(path.join(process.cwd(), config.distDirectory, "_entry.js"))
  if (entry.default == undefined) {
    // multiple build occuring, wait for the next one
    return
  }
  let reactApp = entry.default[0]
  let Context = entry.default[2]

  StaticWebsiteServer.getFiles(
    reactApp,
    Context,
    config,
    html
  )
    .forEach(([filePath, value]) => {
      filePath = filePath.startsWith("/") ? filePath.slice(1) : filePath
      filePath = filePath.startsWith("api/") || filePath.endsWith(".html") ? filePath : filePath + (filePath.endsWith("/") ? "" : "/") + "index.html"
      fs.mkdirSync(path.dirname(path.join(process.cwd(), config.distDirectory, filePath)), { recursive: true });
      fs.writeFileSync(path.join(process.cwd(), config.distDirectory, filePath), value, "utf8")
    })
}

let { default: [_, configs] } = require(path.join(process.cwd(), entry))

async function start() {
  let express = require("express")
  let getPort = require("get-port")
  let app = express();
  let { createFsFromVolume, Volume } = require("memfs");
  let volume = new Volume();
  let outputFileSystem = createFsFromVolume(volume);
  fs = outputFileSystem
  outputFileSystem.join = path.join.bind(path);

  let compiler = webpack(configs.reduce((acc, config) => {
    acc.push(...createWebpackConfig(config))
    return acc
  }, []))
  compiler.compilers.forEach(compiler => {
    if (compiler.options.output.filename != "_entry.js") {
      compiler.outputFileSystem = outputFileSystem;
    }
  })

  let port = await getPort()
  let ws = createWebsocketServer(port)

  let suffix = `<script>new WebSocket("ws://localhost:${port}").onmessage = function() {location.reload(true)}</script>`

  let isFirstRun = true

  await new Promise((resolve, reject) =>
    compiler.watch({
      aggregateTimeout: 300,
      poll: undefined
    }, (error, stats) => {
      if (error) {
        reject(error);
      } else {
        if (stats.hasErrors()) {
          let errors = stats.toJson().errors.join("\n");
          reject(errors);
        } else {
          resolve()
          // reload config
          let entry = requireFresh(path.join(process.cwd(), configs[0].distDirectory, "_entry.js"))
          if (entry.default == undefined) {
            // multiple build occuring, wait for the next one
            return
          }
          let htmlSources = stats.stats.map(item => item.compilation.assets["_source.html"] ? item.compilation.assets["_source.html"].source() : null).filter(x => x)
          configs = entry.default[1]
          configs.forEach((config, index) => {
            prerenderForConfig(
              config,
              (htmlSources[index] || fs.readFileSync(path.join(process.cwd(), "dist/_source.html"), "utf8")) + suffix
            )
          })
          if (!isFirstRun) {
            ws.send("change")
          }
          isFirstRun = false
        }
      }
    })
  )

  let chokidar = require("chokidar");

  configs.forEach(config => {
    let watcher = chokidar.watch(path.join(process.cwd(), config.contentDirectory), {
      ignored: /^\./, persistent: true,
      ignoreInitial: true,
    });

    watcher
      .on("all", function (_) {
        prerenderForConfig(
          config,
          fs.readFileSync(path.join(process.cwd(), "dist/_source.html"), "utf8") + suffix
        )
        ws.send("change")
      })
  })

  app.use((req, res, next) => {
    let url = req.path;
    let filePath = url.startsWith("/") ? url.slice(1) : url;
    let normalizedFilePath = path.join(process.cwd(), "dist", filePath);
    let pathsToTry = [normalizedFilePath, normalizedFilePath + "/index.html"]
    let returned = false
    for (pathToTry of pathsToTry) {
      if (!returned) {
        try {
          let stat = fs.statSync(pathToTry)
          if (stat.isFile()) {
            returned = true
            fs.readFile(pathToTry, (err, data) => {
              if (err) { } else {
                res.status(200).end(data);
              }
            })
          }
        } catch (_) { }
      }
    }
    if (!returned) {
      res.status(404).end(null)
    }
  });
  app.listen(8094)
  console.log("http://localhost:8094")
}

async function build() {
  await Promise.all(
    configs.map(config => {
      return new Promise((resolve, reject) => {
        let compiler = webpack(configs.reduce((acc, config) => {
          acc.push(...createWebpackConfig(config))
          return acc
        }, []))
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
    })
  )

  configs.forEach(config =>
    prerenderForConfig(
      config,
      fs.readFileSync(path.join(process.cwd(), "dist/_source.html"), "utf8")
    ))

}

if (command == "start") {
  start()
} else {
  build()
}
