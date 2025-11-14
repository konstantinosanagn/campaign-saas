const path = require('path')
const { generateWebpackConfig, merge } = require('shakapacker')

const customConfig = {
  resolve: {
    alias: {
      react: path.resolve(__dirname, '../../node_modules/react'),
      'react-dom': path.resolve(__dirname, '../../node_modules/react-dom'),
      '@': path.resolve(__dirname, '..', '..', 'app', 'javascript')
    },
    extensions: ['.ts', '.tsx', '.js', '.jsx', '.css']
  }
}

const config = merge(generateWebpackConfig(), customConfig)

// Fix PostCSS loader configuration
const cssRule = config.module.rules.find(
  (rule) => rule.test && rule.test.toString().includes('css')
)

if (cssRule && Array.isArray(cssRule.use)) {
  const postcssLoader = cssRule.use.find(
    (loader) => loader.loader && loader.loader.includes('postcss-loader')
  )

  if (postcssLoader) {
    postcssLoader.options = {
      postcssOptions: {
        plugins: [require('tailwindcss'), require('autoprefixer')]
      },
      sourceMap: true
    }
  }
}

module.exports = config
