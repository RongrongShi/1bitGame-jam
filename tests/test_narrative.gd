extends SceneTree

const PAGES = preload("res://scenes/pages.gd").PAGES
const NEWS = preload("res://scenes/pages.gd").NEWSPAPERS


func _body(page: Dictionary) -> String:
	var lines := PackedStringArray()
	for paragraph in page.sentences:
		lines.append_array(paragraph)
	return " ".join(lines)


func _initialize() -> void:
	assert(PAGES.size() == 7 and NEWS.size() == 4)
	for page in PAGES:
		assert(page.ids.size() == page.sentences.size())
		assert(page.sentence_rows.size() == page.sentences.size())
		for index in range(1, page.sentences.size()):
			assert(page.sentence_rows[index] > page.sentence_rows[index - 1] + page.sentences[index - 1].size() - 1)
		for target in page.targets:
			assert(target.has("line") and target.has("text"))
			assert(target.text not in ["not", "no longer", "insufficient"])
	assert(PAGES[0].header[0].contains("B-7") and PAGES[1].header[0].contains("B-7"))
	assert(_body(PAGES[0]).contains("will cease at 0430 on 03 NOV"))
	assert(PAGES[0].header[1].contains("02 NOV 1944"))
	assert(_body(PAGES[0]).contains("312") and _body(PAGES[1]).contains("312 wounded"))
	assert(_body(PAGES[1]).contains("east-bank depot: 2200"))
	assert(_body(PAGES[1]).contains("in the present allocation"))
	assert(_body(PAGES[2]).contains("I didn't see it myself"))
	assert(_body(PAGES[2]).contains("Don't bring supper to West Station again"))
	for target in PAGES[2].targets:
		assert(PAGES[2].ids[target.sentence] == "civilian_shooting", "Keep the private warning and family details intact")
	assert(" ".join(NEWS[0].lead).contains("yesterday morning"))
	assert(" ".join(NEWS[0].notice).contains("Marta Keller"))
	assert(" ".join(NEWS[0].notice).contains("Saturday morning"))
	assert(NEWS[0].notice_title == "MISSING PERSON")
	assert(_body(PAGES[3]).contains("staff on continuous duty are unchanged"))
	assert(NEWS[1].date == "FRIDAY, 20 APRIL 1945")
	assert(" ".join(NEWS[1].lead).contains("introduced last November"))
	assert(NEWS[1].notice_title.contains("DEPOT 6"))
	assert(PAGES[4].header[1] == "20 APR 1945")
	assert(NEWS[2].date == "SATURDAY, 21 APRIL 1945")
	assert(" ".join(NEWS[2].lead).contains("Shelter No. 14"))
	assert(NEWS[2].caption.contains("Archive photograph"))
	assert(_body(PAGES[5]).contains("received at 1600"))
	assert(_body(PAGES[5]).contains("requested at 1630"))
	assert(_body(PAGES[5]).contains("goods yard at 1800"))
	assert(_body(PAGES[5]).contains("remains in force pending written amendment"))
	assert(" ".join(NEWS[3].notice).contains("1800 on 21 April"))
	assert(" ".join(NEWS[3].columns[1]).contains("No passenger service had been authorised"))
	assert(_body(PAGES[6]).contains("20 APR - SHELTER REGISTER"))
	assert(_body(PAGES[6]).contains("21 APR - GOODS YARD NOTICE"))
	assert(_body(PAGES[6]).contains("Warning received at 1600. Initialled: H. Weber."))
	assert(_body(PAGES[6]).contains("Once receipt is acknowledged"))
	assert(not _body(PAGES[6]).contains("No duplicate register"))
	var main = load("res://scenes/main.gd")
	assert(main.INTRO_LINES[0].contains("Major Lange"))
	assert(_body(PAGES[6]).contains("K. Lange"))
	assert(main.INTRO_LINES.slice(-3) == main.CALLBACK_LINES)
	assert(main.ENDING_LINES.slice(-3) == main.CALLBACK_LINES)
	print("PASS: future operation timing, matching casualty return, protected private warning, ration contrast, paired papers, warning timeline and routine records transfer")
	quit()
