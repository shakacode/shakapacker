import { runningWebpackDevServer } from "../env"
import devServer from "../dev_server"

// This logic is tied to lib/shakapacker/instance.rb
const inliningCss: boolean =
  runningWebpackDevServer && !!devServer.hmr && devServer.inline_css !== false

export default inliningCss
