process.env.NODE_ENV = process.env.NODE_ENV || 'production'

const environment = require('./environment')

// Configure webpack to use legacy OpenSSL provider
const config = environment.toWebpackConfig()

// Override the hash function to use legacy algorithm for Webpack 4
config.output = config.output || {}
config.output.hashFunction = 'xxhash64'

module.exports = config
