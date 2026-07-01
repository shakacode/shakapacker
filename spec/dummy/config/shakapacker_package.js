const supplementalEntryPoint =
  process.env.SHAKAPACKER_SUPPLEMENTAL_ENTRYPOINT === '1'

const requireShakapacker = () =>
  supplementalEntryPoint
    ? require('shakapacker-webpack')
    : require('shakapacker')

const requireShakapackerRspack = () =>
  supplementalEntryPoint
    ? require('shakapacker-rspack')
    : require('shakapacker/rspack')

module.exports = {
  requireShakapacker,
  requireShakapackerRspack
}
