# Records Scene - shows the current user's level completion history.
extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var list: VBoxContainer = $VBoxContainer/ScrollContainer/List

func _ready() -> void:
	var user := GameState.current_user if GameState.current_user != "" else "玩家"
	title_label.text = "🏆 通关记录 - %s" % user
	var records := GameState.get_level_records(user)
	if records.is_empty():
		var empty := Label.new()
		empty.text = "还没有通关记录，去挑战第一关吧！"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 22)
		list.add_child(empty)
		return
	for i in range(records.size()):
		var r = records[i]
		var row := Label.new()
		row.text = "%d. 第 %d 关通关    ⭐ %d 分    [%s]" % [i + 1, r["level"], r["score"], r["time"]]
		row.add_theme_font_size_override("font_size", 20)
		list.add_child(row)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
