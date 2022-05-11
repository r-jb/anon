<?php
	$modules_list = array(
		'info',
		'clean',
		'shred',
		'mat',
		'webui',
		'timezone',
		'hostname',
		'kalitorify',
		'wtg',
		'macchanger'
	);

	// Toggle a module
	// Returns the shell exit code
	// 0 = No error
	// not 0 = Error
	function exec_module(string $module, string $option = '') {
		$exit_code = 1;

		// If array exists in list of modules
		GLOBAL $modules_list;
		if (in_array($module, $modules_list)) {
			exec("sudo anon $module $option", $cmd_output, $exit_code);
		}

		return $exit_code;
	}

	$out='1';
	if (isset($_GET['module'])) {
		$module = strip_tags($_GET['module']);

		// If both parameters 'module' and 'option' are set, then pass the toggle command
		if (isset($_GET['option'])) {
			$option = strip_tags($_GET['option']);
			$out=exec_module($module, $option);
		}

		// If only parameter 'module' is set, then pass the check command
		else $out=exec_module($module);
	}
	
	// If no parameter is set, then return an error
	echo $out;
?>