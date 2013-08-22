'use strict';

module.exports = function (config) {
    config.set({
        basePath: './',
        frameworks: ["jasmine"],
        files: [
            'js/angular.js',
            'js/angular-resource.js',
            'test/js/angular-mocks.js',
            /*'test/lib/angular/angular-mocks.js',*/
            'js/angularDataServiceModule.js',
            'test/unit/*.js'
        ],
        autoWatch: true,
        browsers: ['Chrome'],
        reporters:['progress','coverage'],
        junitReporter: {
            outputFile: 'test_out/unit.xml',
            suite: 'unit'
        },
        preprocessors: {
            'js/angularDataServiceModule.js': 'coverage'
        },
        coverageReporter: {
            type: 'html',
            dir: 'coverage/'
        }
    });
}