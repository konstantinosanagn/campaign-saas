process.env.NODE_ENV = process.env.NODE_ENV || 'production'

const environment = require('./environment')

// Configure webpack to use legacy OpenSSL provider
const config = environment.toWebpackConfig()

// Override the hash function to use legacy algorithm
config.optimization = config.optimization || {}
config.optimization.hashFunction = 'xxhash64'

module.exports = config
