# Wrong Words Scene - shows the current user's misspelled words.
extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var list: VBoxContainer = $VBoxContainer/ScrollContainer/List

func _ready() -> void:
	var user := GameState.current_user if GameState.current_user != "" else "玩家"
	title_label.text = "📖 错词本 - %s" % user
	var words := GameState.get_wrong_words(user)
	if words.is_empty():
		var empty := Label.new()
		empty.text = "还没有打错的单词，继续加油！"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 22)
		list.add_child(empty)
		return
	for i in range(words.size()):
		var w = words[i]
		var row := Label.new()
		row.text = "%d. [%s]  %s   ❌ %s   ➜   ✅ %s" % [i + 1, w["time"], w["cn"], w["wrong"], w["correct"]]
		row.add_theme_font_size_override("font_size", 20)
		list.add_child(row)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
