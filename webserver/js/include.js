(() => {
	const includes = document.getElementsByTagName('include-view');
	[].forEach.call(includes, i => {
		let filePath = 'views/' + i.getAttribute('src') + '.html';
		fetch(filePath).then(file => {
			file.text().then(content => {
				i.insertAdjacentHTML('afterend', content);
				i.remove();
			});
		});
	});
})();