angular.module('AmpersandApp').controller('AtomicTypeAheadController', function($scope, Restangular, ResourceService){
    
    $scope.hasNoResults = false;
    
    /*
     * Typeahead functionality
     * $scope.typeahead is initiated in InterfaceController to be able to reuse typeahead data
     */
    $scope.getTypeahead = function(resourceType){
        // Only if not yet set
        if(typeof $scope.typeahead[resourceType] === 'undefined'){
            $scope.typeahead[resourceType] = Restangular.all('resources/' + resourceType).getList().$object;
        }
    };
    
    $scope.typeaheadOnSelect = function ($item, $model, $label, resource, ifc, patchResource){
        if(typeof $item._id_ === 'undefined') console.log('Resource id undefined');
        else if($item._id_ === '') console.log('Empty resource id provided');
        else{
            selected = {value : $item._id_};
            if(Array.isArray(resource[ifc])) ResourceService.addItem(resource, ifc, selected, patchResource);
            else if(resource[ifc] === null){
                resource[ifc] = $item._id_;
                ResourceService.saveItem(resource, ifc, patchResource);
            }
            else console.log('Error: Property already set and/or not defined');
            
            $scope.hasNoResults = false;
        }
    };
    
    $scope.typeAheadCreate = function (resource, ifc, selected, patchResource){
        if(Array.isArray(resource[ifc])) ResourceService.addItem(resource, ifc, selected, patchResource);
        else if(resource[ifc] === null){
            resource[ifc] = selected.value;
            ResourceService.saveItem(resource, ifc, patchResource);
        }
        else console.log('Error: Property already set and/or not defined');
    };
});