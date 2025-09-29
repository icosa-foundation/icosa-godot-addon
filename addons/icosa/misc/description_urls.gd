extends RichTextLabel

var list_of_tlds = "res://addons/icosa/misc/tlds.txt"
var bbcode_fmt = "[url=%s]%s[/url]"
var tlds: PackedStringArray = []

func _ready():
	# Load TLDs from file
	var file = FileAccess.open(list_of_tlds, FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			# Ignore comments and empty lines
			if line != "" and not line.begins_with("#"):
				tlds.append(line.to_lower())
		file.close()
	
	# Run once at startup
	convert_links()
	# Update automatically when visibility changes
	visibility_changed.connect(convert_links)
	meta_clicked.connect(_on_meta_clicked)
	
# This assumes RichTextLabel's `meta_clicked` signal was connected to
# the function below using the signal connection dialog.
func _on_meta_clicked(meta):
	# `meta` is of Variant type, so convert it to a String to avoid script errors at run-time.
	OS.shell_open(str(meta))

func convert_links():
	var words = text.split(" ")
	var new_words: Array = []

	for word in words:
		var leading_punct = _leading_punct(word)
		var trailing_punct = _trailing_punct(word)
		var cleaned = _strip_punctuation(word)

		if _is_url_like(cleaned):
			var url = cleaned
			if not url.begins_with("http://") and not url.begins_with("https://"):
				url = "https://" + url
			new_words.append(leading_punct + bbcode_fmt % [url, cleaned] + trailing_punct)
		else:
			new_words.append(word)

	text = " ".join(new_words)
	bbcode_enabled = true


func _is_url_like(word: String) -> bool:
	if not word.contains("."):
		return false
	var parts = word.to_lower().split(".")
	if parts.size() < 2:
		return false
	var last_part = parts[-1]
	return last_part in tlds


func _strip_punctuation(word: String) -> String:
	var start = 0
	var end = word.length()
	var punctuation = ".,!?;:()[]{}\"'"

	while start < end and punctuation.find(word[start]) != -1:
		start += 1
	while end > start and punctuation.find(word[end - 1]) != -1:
		end -= 1

	return word.substr(start, end - start)


func _leading_punct(word: String) -> String:
	var punctuation = ".,!?;:()[]{}\"'"
	var start = 0
	while start < word.length() and punctuation.find(word[start]) != -1:
		start += 1
	return word.substr(0, start)


func _trailing_punct(word: String) -> String:
	var punctuation = ".,!?;:()[]{}\"'"
	var end = word.length()
	while end > 0 and punctuation.find(word[end - 1]) != -1:
		end -= 1
	return word.substr(end, word.length() - end)
