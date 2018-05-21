app.controller('ResList', ['$scope', 'ResFactory',
    function ($scope, ResFactory) {
        /** 方法注册 **/
        $scope.fnUpdateDomainList = function () {
            ResFactory.getDomainList().success(function (data) {
                $scope.domainList = data.data;
            });
        };
        $scope.fnSetDomain = function (domain) {
            $scope.fnUpdateResList(domain);
        };
        $scope.fnSetResDetail = function (id) {
            $scope.editor.data = angular.copy($scope.resList[id]);
        };
        $scope.fnUpdateResList = function (domain) {
            console.log('$scope.fnSetDomain');
            ResFactory.getResList(domain).success(function (data) {
                $scope.resList = {};
                if ($scope.searchPattern) {
                    for (var resId in data.data) {
                        if (JSON.stringify(data.data[resId]).search($scope.searchPattern) != -1) {
                            $scope.resList[resId] =  data.data[resId]
                        }
                    }

                }  else {
                    $scope.resList = data.data;
                }

            });
        };
        $scope.fnDelRes = function (domain, id) {
            ResFactory.delRes(domain, id).success(function () {
                $scope.fnUpdateResList(domain);
                $scope.editor.data = {"提示": "请选择资源"};
            }).error(function (error) {
                $scope.editor.data = error.error.message;
            });
        };
        $scope.fnEditRes = function (domain, id, reDetail) {
            ResFactory.editRes(domain, id, reDetail).success(function () {
                $scope.resList[id] = reDetail;
                alert('更新成功');
            }).error(function (e) {
                alert(e.error.message)
            });
        };
        $scope.changeOptions = function () {
            // 'form', 'text', 'tree', 'view'
            $scope.editor.options.mode = $scope.editor.options.mode == 'tree' ? 'code' : 'tree';
        };
        $scope.searchPattern = null;
        $scope.editor = {
            options: {
                mode: 'tree'
            },
            data: {"提示": "请选择资源"}
        };

        $scope.fnUpdateDomainList();
    }
]);

app.controller('ResAdd', ['$scope', 'ResFactory',
    function ($scope, ResFactory) {
        $scope.fnUpdateDomainList = function () {
            ResFactory.getDomainList().success(function (data) {
                $scope.domainList = data.data;
            });
        };

        $scope.fnAddRes = function (domain) {
            ResFactory.addRes(domain, $scope.editor.data).success(function (data) {
                var newId = data.data;
                alert('添加成功:' + newId);
            }).error(function (err) {
                alert('Error:' + err.error.message);
            });
        };

        $scope.clearData = function () {
            $scope.editor.data = {};
        };
        $scope.changeOptions = function () {
            $scope.editor.options.mode = $scope.editor.options.mode == 'tree' ? 'view' : 'tree';
        };

        $scope.editor = {
            options: {
                mode: 'tree'
            },
            data: {
                comment: '例子:',
                type: 'node',
                status: 0,
                cfg: {
                    ip: '1.1.1.1',
                    username: 'admin',
                    password: 'admin123'
                },
                label: {
                    for: 'sddc',
                    lang: 'en'
                }

            }
        };

        $scope.fnUpdateDomainList();
    }
]);

app.controller('ResAll', ['$scope', 'ResFactory',
    function ($scope, ResFactory) {
        /** 方法注册 **/
        $scope.fnUpdateDomainList = function () {
            ResFactory.getDomainList().success(function (data) {
                $scope.domainList = data.data;
            });
        };
        $scope.fnSetDomain = function (domain) {
            $scope.fnSetAllResources(domain);
        };
        $scope.fnSetAllResources = function (domain) {
            ResFactory.getResList(domain).success(function (data) {
                $scope.editor.data = data.data;
            });
        };

        $scope.changeOptions = function () {
            $scope.editor.options.mode = $scope.editor.options.mode == 'view' ? 'code' : 'view';
        };
        $scope.editor = {
            options: {
                mode: 'tree'
            },
            data: {tip: "loading..."}
        };

        $scope.fnUpdateDomainList();
    }
]);