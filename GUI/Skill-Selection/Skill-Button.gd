extends MarginContainer

var placing
var skillName
var mainSkillMenu

func initialize(menu, skill, place):
	mainSkillMenu = menu
	skillName = skill
	placing = place
	if has_node("ColorRect/SkillButton"):
		get_node("ColorRect/SkillButton").connect("pressed", mainSkillMenu, "skillButtonPressed", [skillName, placing])

func toggle_on():
	print("toggled")
	get_node("ColorRect").color = Color("#6e70ff")

func toggle_off():
	print("untoggled")
	get_node("ColorRect").color = Color("#8c8c8c")
