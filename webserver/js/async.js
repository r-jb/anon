// Change visuals when an element is running
function set_visuals_running(element) {
	document.getElementById(element.id).value = 'stop';
	document.getElementById(element.id).innerText = 'Stop';
	document.getElementById(element.id).parentElement.className = 'element_on';
}

// Change visuals when an element is stopped
function set_visuals_stopped(element) {
	document.getElementById(element.id).value = 'start';
	document.getElementById(element.id).innerText = 'Start';
	document.getElementById(element.id).parentElement.className = 'element_off';
}

// Toggle modules or bundles of modules asynchronously
async function toggle(html_element, script_element_type, script_element_value) {
	try {
		const to_state = html_element.value;
		const get_request = await fetch('php/toggle.php?type=' + script_element_type + '&value=' + script_element_value + '&state=' + to_state);
		const get_response = await get_request.text();

		// Set button state accordingly
		if (to_state === 'start') {
			if (get_response === '0') set_visuals_running(html_element);
			else {
				alert('Error: module ' + script_element_value + ' did not start !')
				set_visuals_stopped(html_element);
			}
		} else if (to_state === 'stop') {
			if (get_response === '0') set_visuals_stopped(html_element);
			else {
				alert('Error: module ' + script_element_value + ' did not stop !')
				set_visuals_running(html_element);
			}
		}

	} catch (error) {
		console.log(error);
	}
}

// Check if a module/bundle is running
async function check(html_element) {
	try {
		const get_request = await fetch('php/toggle.php?value=' + html_element.id);
		const get_response = await get_request.text();

		// Set button state accordingly
		if (get_response === '0') set_visuals_running(html_element);
		else set_visuals_stopped(html_element);

	} catch (error) {
		console.log(error);
	}
}

// Checks the state of all modules/bundles on a page
async function check_all_state() {
	const button_element_list = document.getElementsByTagName('button')
	for (let i = 0; i < button_element_list.length; i++) {
		check(button_element_list[i]);
	}
}

// Periodically check the state of all modules/bundles once the page is loaded
window.addEventListener('load', function () {
	(function(){
		check_all_state();
		setTimeout(arguments.callee, 10000);
	})();
})