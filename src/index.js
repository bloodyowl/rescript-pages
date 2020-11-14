let fs = require("fs");
let path = require("path");
let webpack = require("webpack");
let StaticWebsiteServer = require("./StaticWebsiteServer.bs");
let chalk = require("chalk");

let args = process.argv.slice(2)
let command = args[0]
let entry = args[1]

global.__ = localeKey => localeKey

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

function prerenderForConfig(config) {
  StaticWebsiteServer.getFiles(config, fs.readFileSync)
    .forEach(([filePath, value]) => {
      fs.mkdirSync(path.dirname(path.join(process.cwd(), config.distDirectory, filePath)), { recursive: true });
      fs.writeFileSync(path.join(process.cwd(), config.distDirectory, filePath), value, "utf8")
    })
}

let { default: { config } } = require(path.join(process.cwd(), entry))

async function start() {
  let express = require("express")
  let getPort = require("get-port")
  let app = express();
  let { createFsFromVolume, Volume } = require("memfs");
  let volume = new Volume();
  let outputFileSystem = createFsFromVolume(volume);
  // rewrite `fs` from now on
  fs = outputFileSystem
  outputFileSystem.join = path.join.bind(path);

  let compiler = webpack(StaticWebsiteServer.getWebpackConfig(config, "development", entry))
  // patch web compilers to write on memory
  compiler.compilers.forEach(compiler => {
    if (compiler.options.target == "web") {
      compiler.outputFileSystem = outputFileSystem;
    }
  })

  let port = await getPort()
  let ws = createWebsocketServer(port)

  let suffix = `<script>new WebSocket("ws://localhost:${port}").onmessage = function() {location.reload(true)}</script>`

  let isFirstRun = true

  console.log("Bundling assets")
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
          let entryExports = requireFresh(path.join(process.cwd(), entry))
          if (entryExports.default == undefined) {
            // multiple build occuring, wait for the next one
            return
          }
          config = entryExports.default.config
          prerenderForConfig(config)
          if (!isFirstRun) {
            ws.send("change")
          }
          isFirstRun = false
        }
      }
    })
  )

  let chokidar = require("chokidar");

  let watcher = chokidar.watch(path.join(process.cwd()), {
    ignored: /^\./, persistent: true,
    ignoreInitial: true,
  });

  watcher
    .on("all", function (_) {
      console.log("Content changed")
      prerenderForConfig(config)
      ws.send("change")
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
            let wsSuffix = (pathToTry.endsWith(".html") ? suffix : "");
            fs.readFile(pathToTry, (err, data) => {
              if (err) { } else {
                res.status(200).end(data + wsSuffix);
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
  console.log("Dev server running at: http://localhost:8094")
}

async function build() {
  console.log("1/2 Bundling assets")
  await Promise.all(
    configs.map(config => {
      return new Promise((resolve, reject) => {
        let compiler = webpack(StaticWebsiteServer.getWebpackConfig(config, "production", entry))
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
  console.log("2/2 Prerendering pages")
  prerenderForConfig(config)
  console.log("Done!")
}


console.log(chalk.blue("ReScript Static Website"))
if (command == "start") {
  start()
} else {
  build()
}
