let fs = require("fs");
let path = require("path");
let webpack = require("webpack");
let chalk = require("chalk");
let mime = require("mime");
let PagesServer = require("./PagesServer.bs");

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

function prerenderForConfig(config, mode) {
  PagesServer.getFiles(config, fs.readFileSync, mode)
    .forEach(([filePath, value]) => {
      fs.mkdirSync(path.dirname(path.join(process.cwd(), config.distDirectory, filePath)), { recursive: true });
      fs.writeFileSync(path.join(process.cwd(), config.distDirectory, filePath), value, "utf8")
    })
}

async function start(entry) {
  let { default: { config } } = require(entry)
  let express = require("express")
  let getPort = require("get-port")
  let app = express();
  let { createFsFromVolume, Volume } = require("memfs");
  let volume = new Volume();
  let outputFileSystem = createFsFromVolume(volume);
  // rewrite `fs` from now on
  fs = outputFileSystem
  outputFileSystem.join = path.join.bind(path);
  let chokidar = require("chokidar");
  let watchedDirectories = new Set();

  function onContentChange(_) {
    console.log("Content changed")
    prerenderForConfig(config, "development")
    ws.send("change")
  }

  let watchDirectories = () => {
    watchedDirectories.forEach(watcher => watcher.off("all", onContentChange))
    watchedDirectories = new Set()
    config.variants.forEach(item => {
      let watcher = chokidar.watch(path.join(process.cwd(), item.contentDirectory), {
        ignored: /^\./, persistent: true,
        ignoreInitial: true,
      });
      watcher.on("all", onContentChange)
      watchedDirectories.add(watcher)
    })
  }

  let compiler = webpack(PagesServer.getWebpackConfig(config, "development", entry))
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
          let entryExports = requireFresh(entry)
          if (entryExports.default == undefined) {
            // multiple build occuring, wait for the next one
            return
          }
          config = entryExports.default.config
          prerenderForConfig(config, "development")
          watchDirectories()
          if (!isFirstRun) {
            ws.send("change")
          }
          isFirstRun = false
        }
      }
    })
  )

  watchDirectories()

  function setMime(path, res) {
    if (res.getHeader("Content-Type")) {
      return
    }
    let type = mime.getType(path)
    if (!type) {
      return
    }
    res.setHeader("Content-Type", type);
  }

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
            let currentPath = pathToTry
            fs.readFile(currentPath, (err, data) => {
              if (err) { } else {
                setMime(currentPath, res)
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
  let serverPort = await getPort()
  app.listen(serverPort)
  console.log(`Dev server running at: ${chalk.green(`http://localhost:${serverPort}`)}`)
}

async function build(entry) {
  let { default: { config } } = require(entry)
  console.log("1/2 Bundling assets")
  await new Promise((resolve, reject) => {
    let compiler = webpack(PagesServer.getWebpackConfig(config, "production", entry))
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
  console.log("2/2 Prerendering pages")
  prerenderForConfig(config, "production")
  console.log("Done!")
}

exports.start = start
exports.build = build
