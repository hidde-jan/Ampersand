<?php

class Config {
	
	public static function get($configVar, $scope = 'global'){
		if (!isset($GLOBALS[$scope][$configVar])) throw new Exception("Variable $configVar in scope $scope does not exists", 500);
		
		return $GLOBALS[$scope][$configVar];
	}
	
	public static function set($configVar, $scope, $value){
		$GLOBALS[$scope][$configVar] = $value;
		
		return true;
	}
}

// Default configuration
Config::set('contextName', 'global', $contextName); // from Generics.php

?>