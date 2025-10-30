module.exports = {
  test: /\.tsx?$/,
  use: [{ loader: 'babel-loader' }], // uses repo-level babel.config.js
  exclude: /node_modules/,
};


