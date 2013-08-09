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
  ['$http', 'dataStore', 'dataObject', '$q', ($http, dataStore, dataObject, $q)->
    doneonce = false
    serviceReturn = {
      new: (model, data = null)->
          # if data is provided, that will be used to create the object
          # otherwise an object ready for creation is returned
          new dataObject(model, 'new')
      get: (model, useCache = true)->
        promises = {}
        uri = 'http://localhost/api';
        needToFetchData = false;
        angular.forEach(model, (value, model)->
          promises[model] = []
          value = if value == true then '-' else value
          if value.match /,/
            uri += '/' + model + '/'
            angular.forEach(value.split(','), (idValue)->
              cacheValue = dataStore.get(model, idValue)
              promises[model].push cacheValue
            )
            uri += value
          else
            cacheValue = dataStore.get(model, value)
            uri += '/' + model + '/' + value
            if value != '-'
              promises[model].push cacheValue
        )
        if doneonce == false
            $http.get(uri).then((origData)->
              doneonce = true;
              meta = angular.copy origData.data.meta
              links = angular.copy origData.data.links
              data = angular.copy origData.data
              delete data.meta
              delete data.links
              angular.forEach(data, (value, model)->
                # this trickery needs to stop... somehow
                dataStore.resolve model, '-', value
                dataStore.delete model,'-'
                angular.forEach(data[model], (post, id)->
                  dataStore.resolve model, id, angular.extend(new dataObject(model, id), post)
                )
              )
            )
        else
          return cacheValue
        ret = {}
        angular.forEach(promises, (promise, model)->
          if promise.length == 0
            ret[model] = dataStore.get model, '-'
          else
            ret[model] = $q.all(promise);
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
                #if id != self.id
                    # dataStore.set(self.$model,id,self)
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
# todo : make sure we can extend this with some sort of coool local storage... right?
angularDataServiceModule.factory "dataStore", ['$q', ($q)->
  data = {}
  {
  flush: ()->
    data = {}
  clear: (model)->
    data.model = {}
  delete: (model, dataId)->
    data[model][dataId] = null
  get: (model, dataId)->
    if data[model]? && data[model][dataId]?

      if data[model][dataId].promise?
        console.log model, dataId, "Does have a promise"
        data[model][dataId].promise
      else
        console.log model, dataId, "Does NOT have a promise"
        data[model][dataId]
    else
      defer = $q.defer()
      @.set(model, dataId, defer)
      p = defer.promise
      p.then((d) ->
        return d
      )
      p
  set: (model, dataId, modelData)->
    if !data[model]?
      data[model] = {}
    data[model][dataId] = modelData
  resolve: (model, dataId, d)->
    if dataId == '-' && data[model]? && data[model][dataId]?
      newData = []
      self = @
      angular.forEach(d, (value,key)->
        newData.push(self.get(model, key))
      )
      d = $q.all(newData)
    if !data[model]? || !data[model][dataId]?
      @.get(model, dataId)
      data[model][dataId].resolve(d)
    else
      data[model][dataId].resolve(d)
      console.log model,dataId,data[model][dataId].promise
  }
]