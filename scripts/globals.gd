# Word Tower Defense - Main Entry
# Godot 4.3 GDScript

extends Node

func _ready() -> void:
    # Start with main menu
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
