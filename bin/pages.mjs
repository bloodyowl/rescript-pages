#!/usr/bin/env node

import path from "path";
import chalk from "chalk";
import ghpages from "gh-pages";
import { start, build } from "../src/index.js";

let args = process.argv.slice(2);
let command = args[0];
let entry = args[1];
let portOrBranch = args[2];

console.log(chalk.blue("ReScript Pages"));

function help() {
  console.log("");
  console.log("Available commands:");
  console.log(
    "  - " +
      chalk.green("start") +
      " " +
      chalk.magenta("./MyEntry.bs.js") +
      " " +
      chalk.magenta("[port]") +
      ": starts a dev server"
  );
  console.log(
    "  - " +
      chalk.green("build") +
      " " +
      chalk.magenta("./MyEntry.bs.js") +
      ": builds the project"
  );
  console.log(
    "  - " +
      chalk.green("deploy") +
      " " +
      chalk.magenta("./MyEntry.bs.js") +
      " " +
      chalk.magenta("[branch]") +
      ": builds the project"
  );
}

switch (command) {
  case "start":
    if (typeof entry == "string") {
      start(path.join(process.cwd(), entry), portOrBranch);
    } else {
      help();
    }
    break;
  case "build":
    if (typeof entry == "string") {
      build(path.join(process.cwd(), entry));
    } else {
      help();
    }
    break;
  case "deploy":
    if (typeof entry == "string") {
      build(path.join(process.cwd(), entry)).then((config) => {
        return new Promise((resolve) => {
          let branch = portOrBranch || "gh-pages";
          ghpages.publish(
            path.join(process.cwd(), config.distDirectory),
            { branch: branch },
            resolve
          );
        });
      });
    } else {
      help();
    }
    break;
  case "help":
  default:
    help();
    break;
}
