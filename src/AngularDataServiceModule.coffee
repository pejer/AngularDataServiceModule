'use strict'
angularDataServiceModule = angular.module "AngularDataServiceModule", ['ngResource'], null
###
  Created by Henrik Pejer  mr (at) henrikpejer.com

  Thought here is to have a library that automaticaly loads uris
  expecting a JSON-object with a certain structure and use that for
  angular models

  Things to remember

  + Service to look up data ( service->get({"author":"1,2,3","books":true})
    would get authors with id 1,2 and 3 plus their books
  + Cache to cache all data requested and also for reuse
  + Events for when data is being updated
  + IF the app requires authentication, then we should authenticate _before_ using local storage...
###
# service

#angularDataServiceModule.
angularDataServiceModule.factory "dataService", ['$http', 'dataStore', 'dataObject', '$q', '$rootScope','angularDataServiceConfig',($http, dataStore, dataObject, $q,$rootScope,config)->
    #config = {
    #  baseUri: "http://localhost/api"
    #  timeOut: 1000
    #}
    useLocalStoreage = if config.useLocalStorage then config.useLocalStorage else false

    serviceReturn = {
      version: "0.1",
      useLocalStorage:(val)->
        if val?
          useLocalStoreage = if val == true then true else false
        useLocalStoreage
      new: (model)->
          new dataObject(model, 'new')
      get: (model, timeout = config.timeOut)->
        uri = ''
        dataReturn = {}
        angular.forEach(model, (value, model)->
          # value = if value == true then '-' else value
          dataReturn[model] = []
          switch true
            when value == true # case with getting whatever we could from that model
                  uri += '/'+model+'/-'
            when typeof value == 'string'
                if !dataStore.inStore model,value
                  # perhaps check if we can get it from localStoreage
                  if useLocalStoreage == true && window.localStorage && window.localStorage[model+'/'+value]?
                    dataStore.set(model, value, angular.extend(new dataObject(model, value), angular.fromJson(window.localStorage[model+'/'+value])))
                  else
                    uri += '/'+model+'/'+value
                else
                  uri += '/'+model+'/'+value
                dataReturn[model].push dataStore.get model,value, timeout
            when typeof value == 'object'
              modelSet = false
              angular.forEach(value,(value)->
                if !dataStore.inStore model,value
                  if !modelSet
                    if useLocalStoreage == true && window.localStorage && window.localStorage[model+'/'+value]?
                      dataStore.set(model, value, angular.extend(new dataObject(model, value), angular.fromJson(window.localStorage[model+'/'+value])))
                    else
                      modelSet = true
                      uri += '/'+model+'/'+value
                  else
                    uri += ','+value
                dataReturn[model].push dataStore.get model,value,timeout
              )
            else # should we have an else here and what should it do?
              return false
        )
        if uri != ''
          $rootScope.safeApply($http.get(config.baseUri + uri).then((responseData)->
            angular.forEach(responseData.data, (modelData, model)->
              switch(model)
                when 'links','meta'
                  break
                else
                  listResolver = []
                  angular.forEach modelData, (post, id)->
                    dataStore.set model, id, angular.extend(new dataObject(model, id), post)
                    if post.slug?   # if something called 'slug' exist, let's map that to the id of the post
                      dataStore.set model, post.slug, dataStore.get model, id
                    listResolver.push dataStore.get model, id
                  if dataStore.inStore model, '-'
                    dataStore.set model, '-', $q.all(listResolver)
              )
            )
          )
        ret = {}
        angular.forEach(dataReturn,(promisesForModel, model)->
          if promisesForModel.length == 0
            ret[model] = dataStore.get model,'-'
          else
            ret[model] = $q.all(promisesForModel).then((responseData)->
              ret = []
              angular.forEach responseData, (dataValue)->
                if dataValue?
                  ret.push(dataValue);
              ret
            )
        )
        ret
    }
    return serviceReturn
]

angularDataServiceModule.factory "dataObject", ['$http','angularDataServiceConfig', ($http,config)->
  # walk through the data
  # connect, if present, resource to each other
  # have methods to update self (only)
  # template
  class
    constructor: (@$model, @id = 'new')->
    $generateUri: ()->
        config.baseUri+'/'+@.$model+'/'+ @.id;
    # save : should create a new one if necessary
    $save: ()->
        self = @
        $http.post(@.$generateUri(), @).then((responseData)->
            angular.forEach(responseData.data[self.$model], (post)->
                angular.forEach(post, (value, key)->
                    if self[key] != value
                      self[key] = value
                )
                if config.useLocalStorage == true && window.localStorage?
                  window.localStorage[self.$model+'/'+self.id] = angular.toJson(post)
            )
        )
    $refresh: ()->
      self = @
      $http.get(@.$generateUri()).then((responseData)->
        angular.forEach(responseData.data[self.$model][self.id], (value, key)->
          if self[key] != value
            self[key] = value
        )
        if config.useLocalStorage == true && window.localStorage?
          window.localStorage[self.$model+'/'+self.id] = angular.toJson(responseData.data[self.$model][self.id])
      )
]

angularDataServiceModule.factory "dataStore", ['$q','$timeout','$rootScope', 'angularDataServiceConfig',($q,$timeout,$rootScope,config)->
  data = {}
  useLocalStorage = if config.useLocalStorage then config.useLocalStorage else true
  setLocalStorage = (key,value)->
    if useLocalStorage
      window.localStorage[key] = angular.toJson(value)

  {
    flush: (model)->
      if model?
        data[model] = {}
      else
        data = {}
    clear: (model)->
      data[model] = {}
    delete: (model, dataId = null)->
      if dataId == null then delete data[model] else delete data[model][dataId]
    inStore: (model,dataId = null)->
      if data[model]?
          if dataId != null
            return if data[model][dataId]? then true else false
          else
            return if data[model]? then true else false
      else
        false
    get: (model, dataId = null,timeout=1000)->
      $timeout $rootScope.safeApply,10 # ugly hack to trigger the changes
      if @.inStore(model,dataId)
        if dataId != null
          dataObject = data[model][dataId]
        else
          dataObject = data[model]
        if dataObject.promise? && dataObject.promise.$$v?
            return dataObject.promise.$$v
        else
          $q.all([dataObject.promise]).then((responseData)->
            return responseData[0]
          )
      else
        if !data[model]?
          data[model] = {}
        deferedObject = $q.defer()
        deferedObject.promise.then((responseData)->
          responseData
        )
        # timeout is here so that when an error or 404 occurs, the promise still resolves
        $timeout ()->
            deferedObject.resolve()
        ,timeout
        if dataId != null
          data[model][dataId] = deferedObject
        else
          data[model] = deferedObject
        deferedObject.promise
    set: (model, dataId, modelData = null)->
      if modelData == null
        if !@.inStore(model)
          @.get(model)
        data[model].resolve(dataId)
      else
        if !@.inStore(model,dataId)
          @.get(model,dataId)
        data[model][dataId].resolve(modelData)
        setLocalStorage(model+'/'+dataId, modelData);
      @.get(model,dataId)
  }
]
#
# This is basically the brilliant Auth Interceptor Module
# by Witold Szczerba
#
# The origignal license comment is below.
#
# @license HTTP Auth Interceptor Module for AngularJS
# (c) 2012 Witold Szczerba
# License: MIT
#
angularDataServiceModule.factory "httpTokenRestService", ['$rootScope','httpBuffer',($rootScope,httpBuffer)->
  {
    loginConfirmed:(data)->
      $rootScope.$broadcast 'event:auth-loginConfirmed', data
      httpBuffer.retryAll()
  }
]

angularDataServiceModule.config ['$httpProvider',($httpProvider)->
  interceptor = ['$rootScope', '$q', 'httpBuffer', ($rootScope, $q, httpBuffer)->
    success = (response)->
      response

    error = (response)->
      if (response.status == 401 && !response.config.ignoreAuthModule)
        deferred = $q.defer()
        httpBuffer.append(response.config, deferred)
        $rootScope.$broadcast('event:auth-loginRequired')
        return deferred.promise
      $q.reject(response)

    (promise)->
      promise.then(success, error)
  ]
  $httpProvider.responseInterceptors.push(interceptor)
]

# todo: rename event 'test:event'
angularDataServiceModule.factory 'httpBuffer', ['$injector','$rootScope', ($injector,$rootScope)->
  buffer = []
  $http = null

  retryHttpRequest = (config, deferred)->
    successCallback = (response)->
      deferred.resolve(response)
    errorCallback = (response)->
      deferred.reject(response)

    $http = $http || $injector.get('$http')
    $http(config).then successCallback, errorCallback

  {
    append: (config, deferred)->
      buffer.push({
        config: config,
        deferred: deferred
      })

    retryAll: ()->
      for buff in buffer
        $rootScope.$broadcast('event:test',buff)
        retryHttpRequest(buff.config, buff.deferred)
      buffer = []
      false
  }
]

###
  Grabbed from here : https://coderwall.com/p/ngisma
###
angular.module('ng',null,null).run(['$rootScope', ($rootScope)->
  $rootScope.safeApply = (fn)->
    if @? && @.$root? && @.$root.$$phase?
        phase = @.$root.$$phase
        if(phase == '$apply' || phase == '$digest')
          if fn? && (typeof(fn) == 'function')
            fn()
        else
          @.$apply(fn)
    else
      if fn? && (typeof(fn) == 'function')
        fn()
])