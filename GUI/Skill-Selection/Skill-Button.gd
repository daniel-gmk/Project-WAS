extends MarginContainer

var keybind
var keybindValue
var placing
var skillName
var mainSkillMenu
var bindLabel
var selectedSkillPlacing
var toggled = false

func initialize(menu, skill, place):
	mainSkillMenu = menu
	skillName = skill
	placing = place
	if has_node("ColorRect/SkillButton"):
		get_node("ColorRect/SkillButton").connect("pressed", mainSkillMenu, "skillButtonPressed", [self])
		if get_node("ColorRect/SkillButton").has_node("BindLabel"):
			bindLabel = get_node("ColorRect/SkillButton/BindLabel")

func toggle_on():
	get_node("ColorRect").color = Color("#6e70ff")
	toggled = true

func toggle_off():
	get_node("ColorRect").color = Color("#8c8c8c")
	toggled = false
