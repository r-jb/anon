MAX_DEPTH = 7
MIN_DEPTH = 3
MAX_WAIT = 93
MIN_WAIT = 39
DEBUG = True

# From https://en.wikipedia.org/wiki/List_of_most_visited_websites
ROOT_URLS = [
	'https://www.google.com/doodles',
	'https://www.youtube.com/',
	'https://twitter.com/explore',
	'https://en.wikipedia.org/wiki/Main_Page',
	'https://www.yahoo.com/',
	'https://www.amazon.com/',
	'https://www.netflix.com/',
	'https://www.reddit.com/'
	'https://www.ebay.com/',
	'https://www.bbc.co.uk/'
]


# items can be a URL "https://t.co" or simple string to check for "amazon"
blacklist = [
	"https://t.co", 
	"t.umblr.com", 
	"messenger.com", 
	"itunes.apple.com", 
	"l.facebook.com", 
	"bit.ly", 
	"mediawiki", 
	".css", 
	".ico", 
	".xml", 
	"intent/tweet", 
	"twitter.com/share", 
	"signup", 
	"login", 
	"dialog/feed?", 
	".png", 
	".jpg", 
	".json", 
	".svg", 
	".gif", 
	"zendesk",
	"clickserve"
	]  

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; rv:91.0) Gecko/20100101 Firefox/91.0'