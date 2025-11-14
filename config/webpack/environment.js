const { environment } = require('shakapacker')
const path = require('path')

environment.config.merge({
  resolve: {
    alias: {
      react: path.resolve(__dirname, '../../node_modules/react'),
      'react-dom': path.resolve(__dirname, '../../node_modules/react-dom'),
      '@': path.resolve(__dirname, '..', '..', 'app', 'javascript')
    },
    extensions: ['.ts', '.tsx', '.js', '.jsx', '.css']
  },
})

// Fix PostCSS loader configuration
const css = environment.loaders.get('css');
if (css) {
  const use = css.use;
  const postcssIdx = use.findIndex(u => u.loader && u.loader.includes('postcss-loader'));
  if (postcssIdx >= 0) {
    use[postcssIdx].options = {
      postcssOptions: {
        plugins: [require('tailwindcss'), require('autoprefixer')]
      },
      sourceMap: true
    };
  }
}

module.exports = environment
