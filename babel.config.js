module.exports = function (api) {
  api.cache(true)
  return {
    presets: [
      // Shakapacker usually has preset-env, but we include a safe config:
      ['@babel/preset-env', { 
        modules: false, 
        useBuiltIns: 'entry', 
        corejs: 3,
        targets: {
          browsers: ['> 1%', 'last 2 versions', 'not ie <= 11']
        }
      }],
      ['@babel/preset-react', { runtime: 'automatic' }], // enables JSX
      ['@babel/preset-typescript', { isTSX: true, allExtensions: true }]
    ],
    plugins: [
      '@babel/plugin-proposal-optional-chaining',
      '@babel/plugin-proposal-nullish-coalescing-operator',
      '@babel/plugin-transform-class-properties'
    ]
  }
}
