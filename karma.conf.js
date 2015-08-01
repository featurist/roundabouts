module.exports = function(config) {
  config.set({
    basePath: '',
    frameworks: ['browserify', 'mocha'],
    files: [
      'public/client.css',
      'test/**/*Spec.pogo'
    ],
    exclude: [
      'test/**/*.sw?'
    ],
    preprocessors: {
      'test/**/*Spec.pogo': ['browserify']
    },
    browserify: {
      debug: true,
      transform: ['html2js-browserify', 'pogoify'],
      extensions: ['.js', '.pogo']
    },
    proxies: {},
    urlRoot: '/',
    browserNoActivityTimeout: 180000,
    reporters: ['mocha'],
    port: 9876,
    colors: true,
    logLevel: config.LOG_INFO,
    autoWatch: true,
    browsers: ['Chrome'],
    singleRun: false
  });
};
