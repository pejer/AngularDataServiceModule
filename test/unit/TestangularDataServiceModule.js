/**
 * Created with JetBrains PhpStorm.
 * User: henrikpejer
 * Date: 8/10/13
 * Time: 12:28
 * To change this template use File | Settings | File Templates.
 */
'use strict';

describe('version', function(){
    beforeEach(angular.module('AngularDataServiceModule'));
    
    describe('dataService',function(){
       it('should return current version', inject(function(dataService){
           expect(dataService.version).toEqual('0.1');
       }));
    });
});