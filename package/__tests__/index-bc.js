const index = require('../index')

describe('index', () => {
  describe('webpackConfig', () => {
    test('is a global object', () => {
      const { webpackConfig, globalMutableWebpackConfig } = require('../index')

      expect(webpackConfig).toBe(globalMutableWebpackConfig)
    })

    test('Shows warning with deprecation message', () => {
      const consoleSpy = jest.spyOn(console, "warn");
  
      const { webpackConfig } = require('../index')
      
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringMatching(/The 'webpackConfig' is deprecated/)
      )
      consoleSpy.mockRestore();
    })
  })
})
