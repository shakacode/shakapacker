describe("spec/dummy rspack config", () => {
  const loadConfig = () => {
    jest.resetModules()
    delete process.env.CLIENT_BUNDLE_ONLY
    delete process.env.SERVER_BUNDLE_ONLY

    function WebpackManifestPlugin() {}
    function CssExtractRspackPlugin() {}
    function EnvironmentPlugin() {}

    const generateRspackConfig = jest.fn(() => ({
      entry: {
        application: "app/javascript/packs/application.js",
        "hello-world-bundle": "app/javascript/packs/hello-world-bundle.js",
        "server-bundle": "app/javascript/packs/server-bundle.js"
      },
      module: {
        rules: [
          {
            test: /\.css$/,
            use: [
              CssExtractRspackPlugin.loader,
              {
                loader: "css-loader",
                options: { modules: true }
              }
            ]
          }
        ]
      },
      output: {},
      plugins: [
        new EnvironmentPlugin(),
        new WebpackManifestPlugin(),
        new CssExtractRspackPlugin()
      ]
    }))

    CssExtractRspackPlugin.loader = "css-extract-rspack-loader"

    jest.doMock(
      "shakapacker/rspack",
      () => ({
        generateRspackConfig
      }),
      { virtual: true }
    )

    const configFactory = require("../../../spec/dummy/config/rspack/rspack.config")

    return configFactory()
  }

  // jest.doMock registrations are global and persist across jest.resetModules /
  // jest.isolateModules boundaries, so clear the virtual "shakapacker/rspack"
  // mock after every test to keep this spec independent of execution order and
  // to avoid leaking the stub into other specs in the same worker.
  afterEach(() => {
    jest.dontMock("shakapacker/rspack")
  })

  test("server bundle does not write a manifest over the client manifest", () => {
    const log = jest.spyOn(console, "log").mockImplementation(() => {})

    try {
      const configs = loadConfig()
      const serverConfig = configs[1]
      const pluginNames = serverConfig.plugins.map(
        (plugin) => plugin.constructor.name
      )

      expect(pluginNames).not.toContain("WebpackManifestPlugin")
      expect(pluginNames).not.toContain("CssExtractRspackPlugin")
    } finally {
      log.mockRestore()
    }
  })
})
