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
###
# service
angularDataServiceModule.factory "dataService",
  ['$http', 'dataStore', 'dataObject', '$q', '$rootScope',($http, dataStore, dataObject, $q,$rootScope)->
    config = {
      baseUri: "http://localhost/api"
      timeOut: 1000
    }
    serviceReturn = {
      new: (model)->
          new dataObject(model, 'new')
      get: (model, timeout = config.timeOut)->
        uri = ''
        dataReturn = {}
        angular.forEach(model, (value, model)->
          value = if value == true then '-' else value
          dataReturn[model] = []
          if value.match /,/
            modelSet = false
            angular.forEach(value.split(','),(value)->
              if !dataStore.isset model,value
                if !modelSet
                  modelSet = true
                  uri += '/'+model+'/'+value
                else
                  uri += ','+value
              dataReturn[model].push dataStore.get model,value,timeout
            )
          else
            if value == '-'
              uri += '/'+model+'/'+value
            else
              if !dataStore.isset model,value
                  uri += '/'+model+'/'+value
              dataReturn[model].push dataStore.get model,value, timeout
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
                    listResolver.push dataStore.get model, id
                  if dataStore.isset model, '-'
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
    serviceReturn
  ]

angularDataServiceModule.factory "dataObject", ['$http', ($http)->
  # walk through the data
  # connect, if present, resource to each other
  # have methods to update self (only)
  # template
  class
    constructor: (@$model, @id = 'new')->
    $generateUri: ()->
        'http://localhost/api/' + @$model + '/' + @.id;
    # save : should create a new one if necessary
    $save: ()->
        self = @
        $http.post(@.$generateUri(), @).then((responseData)->
            angular.forEach(responseData.data[self.$model], (post)->
                angular.forEach(post, (value, key)->
                    if self[key] != value
                      self[key] = value
                )
            )
        )
    $refresh: ()->
      self = @
      $http.get(@.$generateUri()).then((responseData)->
        angular.forEach(responseData.data[self.$model][self.id], (value, key)->
          if self[key] != value
            self[key] = value
        )
      )
]

angularDataServiceModule.factory "dataStore", ['$q','$timeout', ($q,$timeout)->
  data = {}
  {
    flush: (model=false)->
      if model?
        data[model] = {}
      else
        data = {}
    clear: (model)->
      data[model] = {}
    delete: (model, dataId)->
      delete data[model][dataId]
    isset: (model,dataId)->
      if data[model]? && data[model][dataId]? then true else false
    get: (model, dataId,timeout=1000)->
      if @.isset(model,dataId)
        if data[model][dataId].promise.$$v?
          data[model][dataId].promise.$$v
        else
          $q.all([data[model][dataId].promise]).then((responseData)->
            return responseData[0]
          )
      else
        if !data[model]?
          data[model] = {}
        data[model][dataId] = $q.defer()
        data[model][dataId].promise.then((responseData)->
          responseData
        )
        # timeout is here so that when an error or 404 occurs, the promise still fires
        $timeout ()->
          data[model][dataId].resolve()
        ,timeout
        data[model][dataId].promise
    set: (model, dataId, modelData)->
      if !@.isset(model,dataId)
        @.get(model,dataId);
      data[model][dataId].resolve(modelData)
  }
]

###
  Grabbed from here : https://coderwall.com/p/ngisma
###
angular.module('ng',null,null).run(['$rootScope', ($rootScope)->
  $rootScope.safeApply = (fn)->
    phase = this.$root.$$phase
    if(phase == '$apply' || phase == '$digest')
      if fn? && (typeof(fn) == 'function')
        fn()
    else
      @.$apply(fn)
])