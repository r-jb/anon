// https://www.w3schools.com/js//js_asynchronous.asp

// Change visuals when an element is running
function set_visuals_running(element) {
	document.getElementById(element.id).value = 'false';
	document.getElementById(element.id).innerText = 'Stop';
	document.getElementById(element.id).parentElement.className = 'element_on';
}

// Change visuals when an element is stopped
function set_visuals_stopped(element) {
	document.getElementById(element.id).value = 'true';
	document.getElementById(element.id).innerText = 'Run';
	document.getElementById(element.id).parentElement.className = 'element_off';
}

// Toggle modules or bundles of modules asynchronously
async function toggle(html_element, script_element_type, script_element_value) {
	try {
		const to_state = html_element.value;
		const get_request = await fetch('php/toggle.php?type=' + script_element_type + '&value=' + script_element_value + '&state=' + to_state);
		const get_response = await get_request.text();

		// Log response for debugging
		console.log(html_element.id + ' called for ' + script_element_value + ' of type ' + script_element_type + ' to be ' + to_state  + ': ' + get_response);

		// Set button state accordingly
		if (get_response === '1') {
			set_visuals_running(html_element);
		} else {
			set_visuals_stopped(html_element);
		}

	} catch (error) {
		console.log(error);
	}
}

// ! TODO
// Returns the state of a module or bundle
async function check_state(html_element, script_element_type, script_element_value) {
	try {
		const get_request = await fetch('php/check.php?type=' + script_element_type + '&value=' + script_element_value);
		const get_response = await get_request.text();

		// Set button state accordingly
		if (get_response === '1') {

			// Script is running, set the button to 'Stop'
			document.getElementById(html_element.id).innerText = 'Stop';

		} else {

			// Script stopped, set the button to 'Run'
			document.getElementById(html_element.id).innerText = 'Run';

		}

	} catch (error) {
		console.log(error);
	}
}

// ! TODO: periodic check to change state automatically & asynchonously