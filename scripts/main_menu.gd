# Word Tower Defense - Main Menu Scene Script
extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var user_name_input: LineEdit = $VBoxContainer/UserNameInput

func _ready() -> void:
	GameState.reset()
	var last := GameState.load_last_user()
	if last != "":
		user_name_input.text = last
	start_button.grab_focus()

# Read the name from the input (default "玩家" if empty), store it as the
# current user and persist it so the box is pre-filled next launch.
func _confirm_user() -> String:
	var user := user_name_input.text.strip_edges()
	if user == "":
		user = "玩家"
	GameState.current_user = user
	GameState.save_last_user(user)
	GameState.current_level = GameState.load_progress(user)
	return user

func _on_start_button_pressed() -> void:
	_confirm_user()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_wrong_words_button_pressed() -> void:
	_confirm_user()
	get_tree().change_scene_to_file("res://scenes/wrong_words.tscn")

func _on_records_button_pressed() -> void:
	_confirm_user()
	get_tree().change_scene_to_file("res://scenes/records.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
