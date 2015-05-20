# /*
#  * AngularJs module for Facebook API, coffee script version !
#  *
#  * Author: Francois <francois@coni.tv>
#  * Based on the module made by boynux <reachme@boynux.com>
#  *
#  * This program is free software: you can redistribute it and/or modify
#  * it under the terms of the GNU General Public License as published by
#  * the Free Software Foundation, either version 3 of the License, or
#  * (at your option) any later version.
#  *
#  * This program is distributed in the hope that it will be useful,
#  * but WITHOUT ANY WARRANTY; without even the implied warranty of
#  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  * GNU General Public License for more details.
#  *
#  * You should have received a copy of the GNU General Public License
#  * along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  *
#  */

'use strict'

# all angular components are wrapped in IIFEs
# see https://github.com/Plateful/plateful-mobile/wiki/AngularJS-CoffeeScript-Style-Guide

# this is the provider that does most of the job

(->

  ### @ngInject ###
  facebookProvider = ($injector) ->
    initialized = false
    defaultParams = {
      appId:''
      xfbml: true
      version: 'v2.3'
    }
    facebookEvents = auth: [
        'authResponseChange'
        'statusChange'
        'login'
        'logout'
      ]
    Q = []

    # I've left these queue & process functions, for those who wish to queue more jobs to be ran
    # when facebook is finished loading, but with the promise mechanic below,
    # you can directly add calls to anything you want in $get.waitForNotification

    processPostInitializeQ = () ->
      # console.log 'processing Q'
      while item = Q.shift()
        func = item[0]
        self = item[1]
        args = item[2]

        func.apply self, args
      return

    executeWhenInitialized: (callback, self, args) ->
      # console.log 'adding to Q: ', callback
      Q.push [
        callback
        self
        args
      ]
      return

    {
      # a promise is required to notify the app that the sdk is loaded
      # since $q can't be injected here, it is created in $get,
      #and passed on when the init function is called
      init: (params, promise) ->
        window.fbAsyncInit = () ->
          angular.extend(defaultParams, params)
          FB.init defaultParams
          promise.notify 'sdk loaded'
          return
        return

      $get: ($injector) ->

        # $rootScope and $q are injected here using the $injector service
        #
        # $injector is the only component that can be injected in a provider before the $get method
        # To avoid using $get: ['$rootScope', '$q', ($rootScope, $q) -> {...}]
        # which is required by minification tools but kind of heavy and clunky
        # we use the strict $injection technique on the provider component, therefore using only $injector
        #
        _q = $injector.get('$q')
        _rootScope = $injector.get('$rootScope')

        promise = _q.defer()

        deferred = (func) ->
          def = _q.defer()
          func (response) ->
            if response and response.error
              def.reject response
            else
              def.resolve response

            _rootScope.$apply()

          return def.promise

        waitForNotification = (message, f) ->
          # the f argument is an object like this : f = {func: "functionName", self: "context", args: "arguments (array)"}
          promise.promise.then null, null, (notification) ->
            if notification == message
              f.func.apply f.self, f.args

        registerEventHandlers = () ->
          angular.forEach facebookEvents, (events, domain) ->
            angular.forEach events, (_event) ->
              waitForNotification 'sdk loaded', {
                func: () ->
                  FB.event.subscribe domain+'.'+_event, (response) ->
                    _rootScope.$broadcast 'fb.'+domain+'.'+_event, response
                    return
                  return
                self: this
                args: []
              }

        waitForNotification 'sdk loaded', {
          func: () ->

            # Here, we are sure that the sdk is loaded.
            # you can either queue jobs everywhere else in executeWhenInitialized
            #(but they might be queued after this is ran)
            # or link other function calls below, or even declare more
            # waitForNotification blocks with dedicated promise.notify messages

            initialized = true
            processPostInitializeQ()
            registerEventHandlers()
            console.log 'Sdk loaded', initialized
            
          self: this
          args: []
        }

        api = (path) ->
          deferred (callback) ->
            waitForNotification 'user logged', {
              func: (path) ->
                FB.api path, (response) ->
                  callback response
              self: this
              args:[path]
            }

        login = (params) ->
          deferred (callback) ->
            waitForNotification 'sdk loaded', {
              func:(params) ->
                FB.login((response) ->
                  callback response
                  promise.notify 'user logged'
                  promise.resolve 'this is resolved'
                  , params)
              self: this
              args: [params]
            }

        {
          initialized: initialized
          init:this.init
          promise: promise
          login: login
          api: api
        }
    }

  facebookProvider
    .$inject = ['$injector']

  angular
    .module 'bnx.module.facebook'
    .provider 'facebook', facebookProvider

)()

# /**
#  * @ngdoc directive
#  * @name facebook
#  * @restrict EA
#  *
#  * @description
#  * Facebook initialization directive.
#  *
#  * @param {string} appId Facebook app id.
#  *
#  * @param {object} parameters initialization parameters, for details refer to init function
#  *                 description.
#  * @example
#  *                  <facebook app-id="123456"></facebook>
#  */

(->

  facebookSdk = ($location,facebook) ->
    template = "<div id='fb-root'></div>"
    script = document.createElement('script')
    script.src = "//connect.facebook.net/en_US/sdk.js"
    script.id = 'facebook-jssdk'
    script.async = true

    {
      restrict:'EA'
      template: template
      scope: {
        appId: '@'
        parameters: '='
      }
      link: (scope, element, attrs) ->
        if !facebookApi.inititialized
          document.body.appendChild(script)
          parameters = scope.parameters || {}
          angular.extend parameters, {appId:scope.appId}
          facebook.init(parameters,facebook.promise)
    }

  facebookSdk
    .$inject = ['$location','facebookApi']

  angular
    .module 'bnx.module.facebook'
    .directive 'facebookSdk', facebookSdk

)()

# /**
#  * @ngdoc directive
#  * @name facebookLogin
#  * @restrict E
#  *
#  * @description
#  * Shows facebook login button.
#  *
#  * @param {string} size defines button size, possible values are 'icon', 'small', 'medium',
#  *                 'large', 'xlarge'. default is "medium"
#  * @param {boolean} autoLogout whether to show logout button after user logs into facebook.
#  *                  default is false.
#  * @param {boolean} showFaces shows friends icon whom subscribed into this ad.
#  *                  default is false.
#  * @param {string}  scope comma separated list of required permission that needs to be granted
#  *                  during login default is basic_info.
#  *
#  * @example
#  *                  <facebook-login size="large" auto-logout="false"></facebook-login>
#  */

(->

  facebookLogin = () ->

    template = '<div class="fb-login-button" '
    template += 'data-max-rows="1" '
    template += 'data-size="{{size||\'medium\'}}" '
    template += 'data-show-faces="{{!!showFaces}}" '
    template += 'data-auto-logout-link="{{!!autoLogout}}" '
    template += 'data-scope="{{scope || \'basic_info\'}}"'
    template += '></div>'

    {
      restrict: 'E'
      scope:{
        'autoLogout': '@'
        'size': '@'
        'showFaces': '@'
        'scope': '@'
      }
      template: template
    }

  angular
    .module 'bnx.module.facebook'
    .directive 'facebookLogin', facebookLogin

)()

# /**
#  * @ngdoc directive
#  * @name facebookLike
#  * @restrict E
#  *
#  * @description
#  * Shows facebook like/share/recommend button.
#  *
#  * @param {string} href indicates the page that will be liked. if not provided current
#  *                 absolute URL will be used.
#  * @param {string} colorScheme possible value are light and dark, default is 'light'
#  * @param {string} layout possible values standard, button_count, box_count,
#  *                 default is 'standard'. see Facebook FAQ for more details:
#  *                  https://developers.facebook.com/docs/plugins/like-button/#faqlayouts
#  * @param {boolean} showFaces whether to show profile photos below button, default is false
#  * @param {boolean} share includes share button near like button, default is false
#  * @param {string} action value can be 'like' or 'recommend', default is 'like'
#  *
#  * @example
#  *                  <facebook-like show-faces="true" action="recommend"></facebook-like>
#  */

(->

  facebookLike = ($location) ->
    template = '<div class="fb-like" '
    template += 'data-href="{{href || currentPage}}" '
    template += 'data-colorscheme="{{colorScheme || \'light\'}}" '
    template += 'data-layout="{{layout || \'standard\'}}" '
    template += 'data-action="{{ action || \'like\'}}" '
    template += 'data-show-faces="{{!!showFaces}}" '
    template += 'data-share="{{!!share}}"'
    template += 'data-action="{{action || \'like\'}}"'
    template += 'data-send="false"></div>'
    {
      restrict:'E'
      scope:{
        'colorScheme': '@',
        'layout':      '@',
        'showFaces':   '@',
        'href':        '@',
        'action':      '@',
        'share':       '@',
      }
      template:template
      link: (scope, element, attrs) ->
        scope.currentPage = $location.absUrl()
    }

  facebookLike
    .$inject = ['$location']

  angular
    .module 'bnx.module.facebook'
    .directive 'facebookLike', facebookLike
)()
