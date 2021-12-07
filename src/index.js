import path from "path";
import webpack from "webpack";
import chalk from "chalk";
import mime from "mime";
import * as PagesServer from "./PagesServer.mjs";

global.__ = (localeKey) => localeKey;

let fs = await import("fs");

async function prerenderForConfig(config, mode) {
  try {
    let files = await PagesServer.getFiles(config, fs.readFileSync, mode);
    files.forEach(([filePath, value]) => {
      fs.mkdirSync(path.dirname(path.join(process.cwd(), filePath)), {
        recursive: true,
      });
      fs.writeFileSync(path.join(process.cwd(), filePath), value, "utf8");
    });
  } catch (err) {
    if (mode == "production") {
      throw err;
    } else {
      console.log(
        chalk.white(new Date().toJSON()) +
          " " +
          chalk.yellow("Contents") +
          " " +
          chalk.red("Error")
      );
      console.log(formatError(err));
    }
  }
}

function formatError(error) {
  if (Array.isArray(error)) {
    return error.map(formatError).join("\n\n");
  }
  return (
    "\n" +
    String(error)
      .split("\n")
      .filter((line) => line !== "")
      .map((line) => chalk.yellow(`    ${line}`))
      .join("\n") +
    "\n"
  );
}

async function start(entry, devServerPort) {
  let {
    default: { config },
  } = await import(entry);
  let { default: express } = await import("express");
  let { default: createRescriptDevserverTools } = await import(
    "rescript-devserver-tools"
  );
  let app = express();
  let chokidar = await import("chokidar");
  let watchedDirectories = new Set();

  let compilers = PagesServer.getWebpackConfig(
    config,
    "development",
    entry
  ).map((config) => webpack(config));

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

  let postWebpackBuild = async () => {
    let entryExports = await import(`${entry}?${Date.now()}`);
    // multiple build occuring, wait for the next one
    if (entryExports.default !== undefined) {
      config = entryExports.default.config;
    }
    await prerenderForConfig(config, "development");
    watchDirectories();
  };

  let { middleware, getLiveReloadAppendix, virtualFs, triggerLiveReload } =
    createRescriptDevserverTools(compilers, {
      postWebpackBuild,
    });

  fs = virtualFs;

  async function onContentChange(_) {
    console.log(
      chalk.white(new Date().toJSON()) +
        " " +
        chalk.yellow("Contents") +
        " update"
    );
    await prerenderForConfig(config, "development");
    triggerLiveReload();
  }

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

  app.use(middleware);

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
    for (let pathToTry of pathsToTry) {
      if (!returned) {
        try {
          let stat = fs.statSync(pathToTry);
          if (stat.isFile()) {
            returned = true;
            let liveReloadAppendix = getLiveReloadAppendix();
            let wsSuffix =
              pathToTry.endsWith(".html") && liveReloadAppendix
                ? liveReloadAppendix
                : "";
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
  let { default: getPort } = await import("get-port");
  let port = devServerPort || (await getPort());
  app.listen(port);

  console.log(`${chalk.cyan("Development server started")}`);
  console.log(``);
  console.log(`${chalk.magenta("URL")} -> http://localhost:${port}${pathname}`);
  console.log(``);
}

async function build(entry) {
  let {
    default: { config },
  } = await import(entry);
  console.log(
    chalk.white(new Date().toJSON()) + " " + chalk.grey("Bundle JS and assets")
  );
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
    console.log(
      chalk.white(new Date().toJSON()) +
        " " +
        chalk.grey("Bundle JS and assets") +
        " " +
        chalk.green("Done!")
    );
  } catch (err) {
    console.log(
      chalk.white(new Date().toJSON()) +
        " " +
        chalk.grey("Bundle JS and assets") +
        " " +
        chalk.red("Error")
    );
    console.error(formatError(err));
    process.exit(1);
  }
  console.log(
    chalk.white(new Date().toJSON()) + " " + chalk.grey("Pre-render pages")
  );
  try {
    await prerenderForConfig(config, "production");
  } catch (err) {
    console.log(
      chalk.white(new Date().toJSON()) +
        " " +
        chalk.grey("Pre-render pages") +
        " " +
        chalk.red("Error")
    );
    console.error(formatError(err));
    process.exit(1);
  }
  console.log(
    chalk.white(new Date().toJSON()) +
      " " +
      chalk.grey("Pre-render pages") +
      " " +
      chalk.green("Done!")
  );
  console.log(
    chalk.white(new Date().toJSON()) + " " + chalk.green("Build done!")
  );
  return config;
}

export { start, build };
