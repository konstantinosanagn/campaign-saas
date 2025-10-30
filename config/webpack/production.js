process.env.NODE_ENV = process.env.NODE_ENV || 'production'

const environment = require('./environment')

// Configure webpack to use legacy OpenSSL provider
const config = environment.toWebpackConfig()

// Override the hash function to use a supported algorithm for Webpack 4
config.output = config.output || {}
config.output.hashFunction = 'sha256'

module.exports = config
