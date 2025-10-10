import devServer from "../dev_server"

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runningWebpackDevServer } = require("../env")

// This logic is tied to lib/shakapacker/instance.rb
const inliningCss: boolean =
  runningWebpackDevServer && !!devServer.hmr && devServer.inline_css !== false

export default inliningCss
