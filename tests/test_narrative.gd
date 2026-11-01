extends SceneTree

const PAGES = preload("res://scenes/pages.gd").PAGES
const NEWS = preload("res://scenes/pages.gd").NEWSPAPERS


func _initialize() -> void:
	assert(PAGES.size() == 7 and NEWS.size() == 4)
	for page in PAGES:
		assert(page.ids.size() == page.sentences.size())
		for target in page.targets:
			assert(target.has("line") and target.has("text"))
			assert(target.text not in ["not", "no longer", "insufficient"], "Do not manufacture clean reversals by hiding a negation")
	assert(PAGES[0].header[0].contains("B-7") and PAGES[1].header[0].contains("B-7"))
	assert(PAGES[1].sentences[2][0].contains("18 HQ officers"))
	assert(PAGES[1].sentences[2][1].contains("312 wounded from Sector B-7"))
	assert(PAGES[2].sentences[2][0].contains("at dawn"))
	assert(NEWS[0].lead[5].contains("yesterday morning"))
	assert(NEWS[0].notice[0].contains("Marta Keller"))
	assert(NEWS[0].notice[1].contains("morning"))
	assert(PAGES[2].footer[1] == "Friedrich Keller")
	for target in PAGES[2].targets:
		assert(target.sentence == 2, "The warning to Marta must remain intact")
	assert(PAGES[4].header[1].contains("20 APR 1945"))
	assert(NEWS[1].date == "FRIDAY, 20 APRIL 1945")
	assert(NEWS[2].date == "SATURDAY, 21 APRIL 1945")
	assert(" ".join(NEWS[2].lead).contains("cleared yesterday"))
	assert(PAGES[5].sentences[1][0].contains("1600"))
	assert(PAGES[5].sentences[2][0].contains("1630"))
	assert(PAGES[5].sentences[0][2].contains("1800"))
	assert(" ".join(NEWS[3].notice).contains("1800 on 21 April"))
	assert(PAGES[6].sentences[2][0] == "Shelter register, 20 APR:")
	assert(PAGES[6].sentences[3][0] == "Goods yard notice, 21 APR:")
	assert(PAGES[6].sentences[3][2].contains("H. Weber, 1600"))
	var main = load("res://scenes/main.gd")
	assert(main.INTRO_LINES[0].contains("Major Lange"))
	assert(PAGES[6].sentences[2][1].contains("K. Lange"))
	assert(main.INTRO_LINES.slice(-3) == main.CALLBACK_LINES)
	assert(main.ENDING_LINES.slice(-3) == main.CALLBACK_LINES)
	print("PASS: report identities, guarded private warning, paired source/report dates, warning-order timeline, archive receipts and unchanged callbacks")
	quit()
