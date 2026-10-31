# Page data only. To add a page, append one dictionary to PAGES.
# Rules per page: 4 sentences x 3 lines, each line at most ~31 characters.
# "targets" lists the sentence indices (0-3) the player must redact.
# "ids" names each sentence so the newspaper can report on what was redacted.
# "read_animation" plays the zoomed reading animation when the page is revealed.
const PAGES = [
	{
		"header": ["INTELLIGENCE SECTION / FILE 01-01", "02 NOV 1941 / WESTERN SECTOR", "SUBJECT: ENGAGEMENT AT MARLOW"],
		"sentences": [
			["Our forces took the Marlow", "crossing at 0600 hours after", "a brief engagement."],
			["Own casualties were 112 dead", "and 340 wounded, nearly one", "third of the assault battalion."],
			["Enemy resistance collapsed by", "midday; 200 prisoners were", "taken and moved to the rear."],
			["Supplies at the crossing are", "sufficient for four days of", "continued operations."],
		],
		"ids": ["marlow_crossing", "marlow_casualties", "marlow_prisoners", "marlow_supplies"],
		"targets": [1],
		"read_animation": true,
		"footer": ["FILED BY: MAJ. K. LANGE", "RESTRICTED / COPY 01 OF 03"],
	},
	{
		"header": ["INTELLIGENCE SECTION / FILE 01-02", "03 NOV 1941 / WESTERN SECTOR", "SUBJECT: DAMAGE REPORT, ALDEN"],
		"sentences": [
			["Artillery fire on Alden was", "concentrated on the rail depot", "and the two nearby bridges."],
			["The district hospital took a", "direct hit during the barrage", "and was destroyed."],
			["Roughly sixty patients and", "staff were inside at the time", "of the strike."],
			["The rail depot is no longer", "usable. Repairs will take", "about two weeks."],
		],
		"ids": ["alden_targets", "alden_hospital", "alden_victims", "alden_depot"],
		"targets": [1, 2],
		"footer": ["FILED BY: MAJ. K. LANGE", "RESTRICTED / COPY 01 OF 03"],
	},
	{
		"header": ["INTELLIGENCE SECTION / FILE 01-03", "04 NOV 1941 / EASTERN SECTOR", "SUBJECT: STATUS OF THE EAST LINE"],
		"sentences": [
			["The eastern line holds with", "three understrength divisions", "along the river Kell."],
			["Fuel reserves cover only six", "days. Command has chosen to", "withhold this from the units."],
			["Two supply convoys were lost", "to partisan raids; drivers and", "escorts are presumed dead."],
			["Morale remains satisfactory", "and no further reinforcement", "is requested at this time."],
		],
		"ids": ["kell_line", "kell_fuel", "kell_convoys", "kell_morale"],
		"targets": [1, 2],
		"footer": ["FILED BY: MAJ. K. LANGE", "RESTRICTED / COPY 01 OF 03"],
	},
]
