// Use Rspack's built-in asset modules instead of file-loader
module.exports = {
  test: /\.(bmp|gif|jpe?g|png|tiff|ico|avif|webp|svg|eot|otf|ttf|woff|woff2)$/,
  type: "asset/resource",
  generator: {
    filename: "media/[name]-[hash][ext]"
  }
}