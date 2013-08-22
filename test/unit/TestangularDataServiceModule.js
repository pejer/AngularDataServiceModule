/**
 * Created with JetBrains PhpStorm.
 * User: henrikpejer
 * Date: 8/10/13
 * Time: 12:28
 * To change this template use File | Settings | File Templates.
 */
'use strict';

describe('angularDataServiceModule', function(){
    var ds, $httpBackend,$rs,store;
    afterEach(function(){
        //$rootScope.$apply();
    });
    beforeEach(angular.mock.module('app'));
    beforeEach(angular.mock.inject(function(dataService, dataStore,_$httpBackend_,$rootScope){
        ds = dataService
        $httpBackend = _$httpBackend_;
        $rs = $rootScope;
        store = dataStore;
        $httpBackend.when('GET','/api/author/1').respond({"meta":{"status":null,"messages":[]},'links':{},"author":{"1":{"id":1,"name":"Henrik Pejer"}}});
        $httpBackend.when('GET','/api/author/1/books/-').respond({"meta":{"status":null,"messages":[]},"author":{"1":{"id":1,"name":"Henrik Pejer"}},"books":{
            "1":{id:1,"title":"First book"},
            "2":{id:2,"title":"Second book"},
            "3":{id:3,"title":"Third book",slug:"third-book"}
        }});

        $httpBackend.when('GET','/api/books/1,2').respond({"meta":{"status":null,"messages":[]},"books":{
            "1":{id:1,"title":"First book"},
            "2":{id:2,"title":"Second book"}
        }});

        $httpBackend.when('GET','/api/books/1').respond({"meta":{"status":null,"messages":[]},"books":{"1":{"id":1,"title":"New first title"}}});
        $httpBackend.when('POST','/api/books/1').respond({"meta":{"status":null,"messages":[]},"books":{"1":{"id":1,"title":"Updated title"}}});
        $httpBackend.when('POST','/api/author/new').respond({"meta":{"status":null,"messages":[]},"author":{"99":{"id":99,"name":"Newly Created Author"}}});
    }));
    var app = angular.module('app',['AngularDataServiceModule']);
    app.constant('angularDataServiceConfig', {
            baseUri:"/api",
            timeout: 10000,
            modelUri: "http://localhost/api/{{ $model }}/{{ id }}"
        }
    );

    it('should have a version of 0.1',function(){
        expect(ds.version).toBe('0.1');
    });

    it('should return a valid author object',function(){
        var authorTest= ds.get({'author':'1'});
        var res = null;
        authorTest.author.then(function(val){
            res = val
        });
        $httpBackend.flush();
        $rs.$apply();
        expect(res[0].$model).toBe("author");
        expect(res[0].id).toBe(1);
        expect(res[0].name).toBe("Henrik Pejer");
    });

    it('should return an array of 3 books',function(){
        var authorTest= ds.get({'author':'1','books':true});
        var books = null;
        var author = null;
        authorTest.author.then(function(val){
            author = val
        });
        authorTest.books.then(function(val){
            books = val
        });
        $httpBackend.flush();
        $rs.$apply();
        expect(author[0].$model).toBe("author");
        expect(author[0].id).toBe(1);
        expect(author[0].name).toBe("Henrik Pejer");

        expect(books[0].$model).toBe("books");
        expect(books[0].id).toBe(1);
        expect(books[0].title).toBe("First book");

        books[0].$refresh();
        $httpBackend.flush();
        $rs.$apply();

        expect(books[0].title).toBe("New first title");

        books[0].title = 'test';
        books[0].$save();
        $httpBackend.flush();
        $rs.$apply();

        expect(books[0].title).toBe("Updated title");

        expect(books[1].$model).toBe("books");
        expect(books[1].id).toBe(2);
        expect(books[1].title).toBe("Second book");

        expect(books[2].$model).toBe("books");
        expect(books[2].id).toBe(3);
        expect(books[2].title).toBe("Third book");
    });

    it('should not call http backend for this',function(){
        var books;
        ds.get({'books':[1,2]}).books.then(function(val){
            books = val
        });

        $httpBackend.flush();
        $rs.$apply();

        expect(books[0].id).toBe(1);
    });

    it('should create a new author',function(){
        var author;
        author = ds.new('author');
        expect(author.$model).toBe('author');
        expect(author.id).toBe('new');
        author.name="Henry Rollins";
        author.$save();
        $httpBackend.flush();
        $rs.$apply();

        expect(author.name).toBe('Newly Created Author');
        expect(author.id).toBe(99);
    });

    it('should store object', function () {
        expect(store.inStore('test','henrik')).toBe(false);
        store.set('test','henrik');
        expect(store.inStore('test','henrik')).toBe(true);
    });

    it('should resolve the value',function(){
        var o = {"name": "Henrik"};
        expect(store.inStore('test','henrik1')).toBe(false);
        store.set('test','henrik1',o);
        $rs.$apply();
        setTimeout(250,function(){expect(store.get('test','henrik1')).toBe(o);});
    });

    it('should resolve values with only model',function(){
        var o = {"name":"Henke"};
        expect(store.inStore('user')).toBe(false);
        store.set('user',o);
        $rs.$apply();
        setTimeout(250,function(){expect(store.get('user')).toBe(o);});
    });

    it('should erase object',function(){
        expect(store.inStore('user')).toBe(false);
        store.set('user', {"something": "else"});
        expect(store.inStore('user')).toBe(true);
        store.delete('user');
        expect(store.inStore('user')).toBe(false);

        expect(store.inStore('something','1')).toBe(false);
        store.set('something','1', {"something": "else"});
        expect(store.inStore('something','1')).toBe(true);
        store.delete('something','1');
        expect(store.inStore('something','1')).toBe(false);

    });

    it('should clear a model',function(){
        expect(store.inStore('something','1')).toBe(false);
        expect(store.inStore('something','2')).toBe(false);
        store.set('something','1', {"something": "else"});
        store.set('something','2', {"something": "else"});
        expect(store.inStore('something','1')).toBe(true);
        expect(store.inStore('something','2')).toBe(true);
        store.clear('something');
        expect(store.inStore('something','1')).toBe(false);
        expect(store.inStore('something','2')).toBe(false);
    });

    it('should flush a model',function(){
        expect(store.inStore('something','1')).toBe(false);
        expect(store.inStore('stay','1')).toBe(false);
        expect(store.inStore('something','2')).toBe(false);
        store.set('something','1', {"something": "else"});
        store.set('stay','1', {"something": "else"});
        store.set('something','2', {"something": "else"});
        expect(store.inStore('something','1')).toBe(true);
        expect(store.inStore('stay','1')).toBe(true);
        expect(store.inStore('something','2')).toBe(true);
        store.flush('something');
        expect(store.inStore('something','1')).toBe(false);
        expect(store.inStore('stay','1')).toBe(true);
        expect(store.inStore('something','2')).toBe(false);
    });

    it('should flush everything',function(){
        expect(store.inStore('something','1')).toBe(false);
        expect(store.inStore('stay','1')).toBe(false);
        expect(store.inStore('something','2')).toBe(false);
        store.set('something','1', {"something": "else"});
        store.set('stay','1', {"something": "else"});
        store.set('something','2', {"something": "else"});
        expect(store.inStore('something','1')).toBe(true);
        expect(store.inStore('stay','1')).toBe(true);
        expect(store.inStore('something','2')).toBe(true);
        store.flush();
        expect(store.inStore('something','1')).toBe(false);
        expect(store.inStore('stay','1')).toBe(false);
        expect(store.inStore('something','2')).toBe(false);
    });

});