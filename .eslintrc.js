module.exports = {
  extends: ['airbnb', 'prettier'],
  rules: {
    'comma-dangle': ['error', 'never'],
    'import/no-unresolved': 'off',
    'import/no-extraneous-dependencies': 'off',
    'import/extensions': 'off',
    "indent": ["error", 2],
    semi: ['error', 'never']
  },
  env: {
    browser: true,
    node: true
  }
}
