'use strict'

#
# This is a demo of an angular app config and run components
#

angular.module 'myAngularApp', ['bnx.module.facebook']


(->
  ### @ngInject ###
  config = ($routeProvider, $locationProvider) ->

      # console.log 'bootstrapping app'

      $routeProvider
      .when '/',
        templateUrl: 'app/main.html'
        controller: 'MainCtrl as main'
      .when '/route',
        templateUrl: 'app/route/route.html'
        controller: 'RouteCtrl as route'
      .otherwise '/'

      $locationProvider
      .html5Mode 'true'

      # no need to load the facebook sdk here because the dom won't be loaded anyway
      # let's let the directive handling that when the <script> has been rendered

  config
    .$inject = ['$routeProvider', '$locationProvider']



  run = ($rootScope, facebookApi) ->

    $rootScope.$on 'fb.auth.authResponseChange', (event, response) ->
      # do someting...

    facebookApi.login().then (response) ->
      console.log 'fb log : ',response

    facebookApi.api('/me').then (response) ->
      console.log 'fb api call', response

  run
    .$inject = ['$rootScope', 'facebookApi']

  angular
    .module 'myAngularApp'
    .config config
    .run run

)()
