# Word Tower Defense - Main Menu Scene Script

extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var title_label: Label = $VBoxContainer/TitleLabel

func _ready() -> void:
    GameState.reset()
    start_button.grab_focus()

func _on_start_button_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_button_pressed() -> void:
    get_tree().quit()
