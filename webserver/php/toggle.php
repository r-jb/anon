<?php
	$modules_list = array(
		'mac',
		'hostname'
	);

	// Toggle a module
	// Returns the shell exit code
	// 0 = No error
	// not 0 = Error
	function exec_module(string $module, string $state = '') {
		$exit_code = 1;

		// If array exists in list of modules
		GLOBAL $modules_list;
		if (in_array($module, $modules_list)) {
			$cmd="sudo anon $module $state";
			exec($cmd, $cmd_output, $exit_code);
			//print_r($cmd_output);
		}

		return $exit_code;
	}

	if (isset($_GET['value'])) {
		$value = strip_tags($_GET['value']);

		// If both parameters 'value' and 'state' are set, then pass the toggle command
		if (isset($_GET['state'])) {
			$state = strip_tags($_GET['state']);
			echo exec_module($value, $state);
		}

		// If only parameter 'value' is set, then pass the check command
		else echo exec_module($value);
	}
	
	// If no parameter is set, then return an error
	else echo '1';
?>