# Game Over Scene
extends Control

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel

func _ready() -> void:
    score_label.text = "最终得分: %d" % GameState.score
    message_label.text = "💪 别灰心！多练习几次，单词就会记住的！"

func _on_retry_button_pressed() -> void:
    GameState.load_level(GameState.current_level)
    get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_menu_button_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
