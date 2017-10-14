window.app = angular.module('TES', ['ngRoute', 'ui.ace', 'ng.jsoneditor']).config(['$routeProvider',
    function ($routeProvider) {
        $routeProvider.when('/res/list', {
            templateUrl: '../partials/res/list.html',
            controller: 'ResList'
        }).when('/res/add', {
            templateUrl: '../partials/res/add.html',
            controller: 'ResAdd'
        }).when('/res/all', {
            templateUrl: '../partials/res/all.html',
            controller: 'ResAll'
        }).otherwise({
            redirectTo: '/res/list'
        });
    }
]);
