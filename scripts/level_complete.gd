# Level Complete Scene
extends Control

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel

func _ready() -> void:
    score_label.text = "总分: %d" % GameState.score
    level_label.text = "第 %d 关通关！" % GameState.current_level
    message_label.text = "🎉 太棒了！你已经掌握了这一关的单词！"

func _on_next_button_pressed() -> void:
    GameState.current_level += 1
    GameState.load_level(GameState.current_level)
    get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_menu_button_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_quiz_button_pressed() -> void:
    # Link to quiz/test
    get_tree().change_scene_to_file("res://scenes/quiz.tscn")
