angularDataServiceModule = angular.module "AngularDataServiceModule", ['ngResource']
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

# todo : how to handle data already in cache?
# todo : how to return a promise that will return the correct resource objects? look into http://docs.angularjs.org/api/ng.$q
# service
angularDataServiceModule.factory "dataService",
  ['$http', 'dataStore', 'dataObject', '$q', '$rootScope',($http, dataStore, dataObject, $q,$rootScope)->
    serviceReturn = {
      new: (model, data = null)->
          # if data is provided, that will be used to create the object
          # otherwise an object ready for creation is returned
          new dataObject(model, 'new')
      get: (model, useCache = true)->
        baseUri = 'http://localhost/api';
        uri = ''
        dataReturn = {}
        angular.forEach(model, (value, model)->

          value = if value == true then '-' else value
          dataReturn[model] = []
          if value.match /,/
            modelSet = false
            angular.forEach(value.split(','),(value,key)->
              if !dataStore.isset model,value
                if !modelSet
                  modelSet = true
                  uri += '/'+model+'/'+value
                else
                  uri += ','+value
              dataReturn[model].push dataStore.get model,value
            )
          else
            if value == '-'
              uri += '/'+model+'/'+value
            else
              if !dataStore.isset model,value
                  uri += '/'+model+'/'+value
              dataReturn[model].push dataStore.get model,value
        )
        if uri != ''
          $rootScope.safeApply($http.get(baseUri+uri).then((d)->
            angular.forEach(d.data, (modelData, model)->
              switch(model)
                when 'links','meta'
                  break
                else
                  listResolver = []
                  angular.forEach modelData,(post,id)->
                    dataStore.set model,id,angular.extend(new dataObject(model,id),post)
                    listResolver.push dataStore.get model, id
                  if dataStore.isset model, '-'
                    dataStore.set model, '-', $q.all(listResolver)
                    # we should pick all that is set
                    # and resolve with them, right?
            )
          ,()->
            # todo: this should parse the url and somehow resolve the things
            console.log "Oops errors", arguments
          )
          )
        ret = {}
        angular.forEach(dataReturn,(promisesForModel, model)->
          if promisesForModel.length == 0
            ret[model] = dataStore.get model,'-'
          else
            ret[model] = $q.all promisesForModel
        )
        ret
    }
    serviceReturn
  ]

angularDataServiceModule.factory "dataObject", ['$http','dataStore', ($http,dataStore)->

  # walk through the data
  # connect, if present, resource to each other
  # have methods to update self (only)
  # template
  return class Obj
    constructor: (@$model, @id = 'new')->
    $generateUri: ()->
        'http://localhost/api/' + @$model + '/' + @.id;
    # save : should create a new one if necessary
    $save: ()->
        self = @
        $http.post(@.$generateUri(), @).then((d)->
            angular.forEach(d.data[self.$model], (post, id)->
                angular.forEach(post, (value, key)->
                    if self[key] != value
                      self[key] = value
                )
            )
        )
    $create: (success)->
      return
      #$http.post(@.$uri,@).then ()->
      # refreshes from server
    $refresh: ()->
      self = @
      $http.get(@.$generateUri()).then((d)->
        angular.forEach(d.data[self.$model][self.id], (value, key)->
          if self[key] != value
            self[key] = value
        )
      )
]
# basic cache for our service
# todo: always return promises
# todo: be able to handle promises and resolved promises
angularDataServiceModule.factory "dataStore", ['$q','$rootScope', ($q,$rootScope)->
  data = {}
  {
    flush: (model=false)->
      if model?
        data[model] = {}
      else
        data = {}
    clear: (model)->
      data.model = {}
    delete: (model, dataId)->
      delete data[model][dataId]
    isset: (model,dataId)->
      if data[model]? && data[model][dataId]? then true else false
    get: (model, dataId)->
      if @.isset(model,dataId)
        if data[model][dataId].promise.$$v?
          data[model][dataId].promise.$$v
        else
          $q.all([data[model][dataId].promise]).then((d)->
            return d[0]
          )
      else
        if !data[model]?
          data[model] = {}
          # should we .... really set some sort of promise here? Good or bad, who knows?!?!
        data[model][dataId] = $q.defer()
        data[model][dataId].promise.then((d)->
          d
        )
        #data[model][dataId].promise.$$v = {}
        data[model][dataId].promise
    set: (model, dataId, modelData)->
      if !@.isset(model,dataId)
        @.get(model,dataId);
      #data[model][dataId].promise.$$v =modelData
      data[model][dataId].resolve(modelData)
  }
]

###
  Grabbed from here : https://coderwall.com/p/ngisma
###
angular.module('ng').run(['$rootScope', ($rootScope)->
  $rootScope.safeApply = (fn)->
    phase = this.$root.$$phase
    if(phase == '$apply' || phase == '$digest')
      if fn? && (typeof(fn) == 'function')
        fn()
    else
      @.$apply(fn)
])