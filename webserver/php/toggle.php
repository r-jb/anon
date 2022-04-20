<?php

	$modules_list = array(
		'mac',
		'hostname'
	);
	$state=false;

	// Toggle a module
	// Returns the status as a boolean
	function toggle_module(string $module, bool $state) {
		$output_state = false;

		// If array exists in list of modules
		if (in_array($module, $modules_list)) {
			$exit_code = 1;

			if ($state) {
				$state_cmd = 'on';
			} else {
				$state_cmd = 'off';
			}

			// Execute system command
			//exec(string COMMAND, array OUTPUT, int RETURN_VARIABLE);
			exec("sh ../anon.sh $module $state_cmd", null, $exit_code);

			// Set output status depending on execution
			if ($exit_code == 0) {
				$output_state = true;
			}
		}

		return $output_state;
	}

	function toggle_test($sstate) {
		$state = !$state;
		return $state;
	}

	// ! TODO: add support for toggle_module()
//	if (ifset()) {
		# code...
//	}

	echo toggle_test($_GET['state']);
	//echo toggle_module($_GET['value'], $_GET['state']);
?>