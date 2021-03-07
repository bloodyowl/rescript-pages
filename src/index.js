import fs from "fs";
import path from "path";
import webpack from "webpack";
import chalk from "chalk";
import mime from "mime";
import * as PagesServer from "./PagesServer.mjs";

global.__ = (localeKey) => localeKey;

async function createWebsocketServer(port) {
  let WebSocket = await import("ws");
  let server = new WebSocket.Server({
    port: port,
  });
  let openedConnections = [];
  server.on("connection", (ws) => {
    openedConnections.push(ws);
    ws.on("close", () => {
      openedConnections = openedConnections.filter((item) => item != ws);
    });
  });
  return {
    send: (message) => {
      openedConnections.forEach((ws) => ws.send(message));
    },
  };
}

async function prerenderForConfig(config, mode) {
  let files = await PagesServer.getFiles(config, fs.readFileSync, mode);
  files.forEach(([filePath, value]) => {
    fs.mkdirSync(path.dirname(path.join(process.cwd(), filePath)), {
      recursive: true,
    });
    fs.writeFileSync(path.join(process.cwd(), filePath), value, "utf8");
  });
}

async function start(entry, devServerPort) {
  let {
    default: { config },
  } = await import(entry);
  let express = await import("express");
  let getPort = await import("get-port");
  let app = express();
  let { createFsFromVolume, Volume } = await import("memfs");
  let volume = new Volume();
  let outputFileSystem = createFsFromVolume(volume);
  // rewrite `fs` from now on
  fs = outputFileSystem;
  outputFileSystem.join = path.join.bind(path);
  let chokidar = await import("chokidar");
  let watchedDirectories = new Set();

  async function onContentChange(_) {
    console.log("Content changed");
    await prerenderForConfig(config, "development");
    ws.send("change");
  }

  let watchDirectories = () => {
    watchedDirectories.forEach((watcher) =>
      watcher.off("all", onContentChange)
    );
    watchedDirectories = new Set();
    config.variants.forEach((item) => {
      let watcher = chokidar.watch(
        path.join(process.cwd(), item.contentDirectory),
        {
          ignored: /^\./,
          persistent: true,
          ignoreInitial: true,
        }
      );
      watcher.on("all", onContentChange);
      watchedDirectories.add(watcher);
    });
  };

  let compiler = webpack(
    PagesServer.getWebpackConfig(config, "development", entry)
  );
  // patch web compilers to write on memory
  compiler.compilers.forEach((compiler) => {
    if (compiler.options.target == "web") {
      compiler.outputFileSystem = outputFileSystem;
    }
  });

  let port = await getPort();
  let ws = await createWebsocketServer(port);

  let suffix = `<script>new WebSocket("ws://localhost:${port}").onmessage = function() {location.reload(true)}</script>`;

  let isFirstRun = true;

  function debounce(func, timeout) {
    let timeoutId;
    return (...args) => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        func(...args);
      }, timeout);
    };
  }

  let onWebpackChange = debounce(async () => {
    await prerenderForConfig(config, "development");
    watchDirectories();
    if (!isFirstRun) {
      ws.send("change");
    }
    isFirstRun = false;
  }, 1000);

  console.log("Bundling assets");
  await new Promise((resolve, reject) =>
    compiler.watch(
      {
        aggregateTimeout: 300,
        poll: undefined,
      },
      async (error, stats) => {
        try {
          if (error) {
            reject(error);
          } else {
            if (stats.hasErrors()) {
              let errors = stats.toJson().errors.join("\n");
              reject(errors);
            } else {
              resolve();
              // reload config
              let entryExports = await import(`${entry}?${Date.now()}`);
              if (entryExports.default == undefined) {
                // multiple build occuring, wait for the next one
                return;
              }
              config = entryExports.default.config;
              onWebpackChange();
            }
          }
        } catch (err) {
          console.error(err);
        }
      }
    )
  );

  watchDirectories();

  function setMime(path, res) {
    if (res.getHeader("Content-Type")) {
      return;
    }
    let type = mime.getType(path);
    if (!type) {
      return;
    }
    res.setHeader("Content-Type", type);
  }

  let pathname = new URL(config.baseUrl).pathname;

  app.use(pathname, (req, res, next) => {
    let url = req.path;
    let filePath = url.startsWith("/") ? url.slice(1) : url;
    let normalizedFilePath = path.join(
      process.cwd(),
      config.distDirectory,
      filePath
    );
    let pathsToTry = [normalizedFilePath, normalizedFilePath + "/index.html"];
    let returned = false;
    for (pathToTry of pathsToTry) {
      if (!returned) {
        try {
          let stat = fs.statSync(pathToTry);
          if (stat.isFile()) {
            returned = true;
            let wsSuffix = pathToTry.endsWith(".html") ? suffix : "";
            let currentPath = pathToTry;
            fs.readFile(currentPath, (err, data) => {
              try {
                if (err) {
                } else {
                  setMime(currentPath, res);
                  res
                    .status(200)
                    .end(wsSuffix != "" ? String(data) + wsSuffix : data);
                }
              } catch (err) {
                console.error(err);
                res.status(500).end(null);
              }
            });
          }
        } catch (_) {}
      }
    }
    if (!returned) {
      let normalizedFilePath = path.join(
        process.cwd(),
        config.distDirectory,
        "404.html"
      );
      try {
        let stat = fs.statSync(normalizedFilePath);
        if (stat.isFile()) {
          let wsSuffix = pathToTry.endsWith(".html") ? suffix : "";
          fs.readFile(normalizedFilePath, (err, data) => {
            try {
              if (err) {
              } else {
                setMime(normalizedFilePath, res);
                res
                  .status(404)
                  .end(wsSuffix != "" ? String(data) + wsSuffix : data);
              }
            } catch (err) {
              console.error(err);
              res.status(500).end(null);
            }
          });
        } else {
          res.status(404).end(null);
        }
      } catch (err) {
        res.status(404).end(null);
      }
    }
  });
  let serverPort = await (devServerPort || getPort());
  app.listen(serverPort);
  console.log(
    `Dev server running at: ${chalk.green(
      `http://localhost:${serverPort}${pathname}`
    )}`
  );
}

async function build(entry) {
  let {
    default: { config },
  } = await import(entry);
  console.log("1/2 Bundling assets");
  try {
    await new Promise((resolve, reject) => {
      let compiler = webpack(
        PagesServer.getWebpackConfig(config, "production", entry)
      );
      compiler.run((error, stats) => {
        if (error) {
          reject(error);
        } else {
          if (stats.hasErrors()) {
            let errors = stats.toJson().errors;
            reject(errors);
          } else {
            resolve();
          }
        }
      });
    });
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
  console.log("2/2 Prerendering pages");
  await prerenderForConfig(config, "production");
  console.log("Done!");
  return config;
}

export { start, build };
