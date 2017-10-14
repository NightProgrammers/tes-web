app.factory('ResFactory', ['$http',
    function ($http) {
        var _factory = {};

        _factory.getDomainList = function () {
            return $http.get('/domains')
        };
        _factory.getResList = function (domain) {
            return $http.get('/' + domain +'/res')
        };
        _factory.getResDetail = function (domain, resId) {
           return $http.get('/' + domain +'/res/' + encodeURIComponent(resId));
        };
        _factory.delRes = function (domain, resId) {
            return $http.delete('/' + domain +'/res/' + encodeURIComponent(resId))
        };
        _factory.addRes = function (domain, resDetail) {
            return $http.put('/' + domain +'/res', JSON.stringify(resDetail))
        };
        _factory.editRes = function (domain, resId, resDetail) {
            var detailJson = JSON.stringify(resDetail);
            return $http.post('/' + domain +'/res/' + encodeURIComponent(resId), detailJson)
        };


        return _factory;
    }
]);