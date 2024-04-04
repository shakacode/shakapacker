const webpack = require("webpack");
const MemoryFS = require("memory-fs");
const thenify = require("thenify");
const path = require("path");

const createTrackLoader = () => {
  const filesTracked = {};
  return [
    filesTracked,
    (source) => {
      filesTracked[source.resource] = true;
      return source;
    },
  ];
};

const node_modules = path.resolve("node_modules");
const node_modules_included = path.resolve("node_modules/included");
const app_javascript = path.resolve("app/javascript");

const createInMemoryFs = () => {
  const fs = new MemoryFS();

  fs.mkdirpSync(node_modules);
  fs.mkdirpSync(node_modules_included);
  fs.mkdirpSync(app_javascript);

  return fs;
};

const createTestCompiler = (config, fs = createInMemoryFs()) => {
  Object.values(config.entry).forEach((file) => {
    fs.writeFileSync(file, "console.log(1);");
  });

  const compiler = webpack(config);
  compiler.run = thenify(compiler.run);
  compiler.inputFileSystem = fs;
  compiler.outputFileSystem = fs;
  return compiler;
};

module.exports = {
  createTrackLoader,
  node_modules,
  node_modules_included,
  app_javascript,
  createInMemoryFs,
  createTestCompiler,
};
