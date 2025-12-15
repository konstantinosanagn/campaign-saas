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

// webpack-dev-server v4+ blocks unknown Host/Origin by default.
// Ensure local development works on Windows across localhost/127.0.0.1 without
// "Invalid Host/Origin header" errors.
if (process.env.NODE_ENV === 'development' && config.devServer) {
  // Allow any Host header (local dev only).
  config.devServer.allowedHosts = 'all'

  // Bind to all interfaces to avoid hostname mismatches in Windows/proxy setups.
  config.devServer.host = '0.0.0.0'

  // Force the websocket URL the browser uses, so Origin/Host mismatches don't
  // break live reload (Rails may be opened as localhost or 127.0.0.1).
  config.devServer.client = config.devServer.client || {}
  config.devServer.client.webSocketURL = 'ws://localhost:3035/ws'
}

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
