const path = require("path");
const {
  app_javascript,
  node_modules,
  node_modules_included,
  createTestCompiler,
  createTrackLoader,
} = require("./__utils__/webpack");
const esbuildConfig = require("../esbuild");

jest.mock("../../config", () => {
  const original = jest.requireActual("../../config");
  return {
    ...original,
    webpack_loader: "esbuild",
    additional_paths: [...original.additional_paths, "node_modules/included"],
  };
});

const createWebpackConfig = (file, use) => {
  return {
    entry: { file },
    module: {
      rules: [
        {
          ...esbuildConfig,
          use,
        },
      ],
    },
    output: {
      path: "/",
      filename: "scripts-bundled.js",
    },
  };
};

describe("swc", () => {
  test("process source path", async () => {
    const normalPath = `${app_javascript}/a.js`;
    const [tracked, loader] = createTrackLoader();
    const compiler = createTestCompiler(
      createWebpackConfig(normalPath, loader)
    );
    await compiler.run();
    expect(tracked[normalPath]).toBeTruthy();
  });

  test("exclude node_modules", async () => {
    const ignored = `${node_modules}/a.js`;
    const [tracked, loader] = createTrackLoader();
    const compiler = createTestCompiler(createWebpackConfig(ignored, loader));
    await compiler.run();
    expect(tracked[ignored]).toBeUndefined();
  });

  test("explicitly included node_modules should be transpiled", async () => {
    const included = `${node_modules_included}/a.js`;
    const [tracked, loader] = createTrackLoader();
    const compiler = createTestCompiler(createWebpackConfig(included, loader));
    await compiler.run();
    expect(tracked[included]).toBeTruthy();
  });
});
