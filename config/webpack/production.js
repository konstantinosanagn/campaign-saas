process.env.NODE_ENV = process.env.NODE_ENV || 'production'

// Set legacy OpenSSL provider for Node.js 17+
process.env.NODE_OPTIONS = '--legacy-openssl-provider'

const environment = require('./environment')

module.exports = environment.toWebpackConfig()
