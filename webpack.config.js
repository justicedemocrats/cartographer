const path = require("path");

module.exports = {
  entry: {
    app: ["./web/static/js/app.js", "./web/static/stylus/app.styl"]
  },

  output: {
    path: path.resolve(__dirname, "priv/static"),
    filename: "js/[name].js"
  },

  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader"
        }
      },
      {
        test: /\.styl$/,
        use: ["style-loader", "css-loader", { loader: "stylus-loader" }]
      }
    ]
  }
};
