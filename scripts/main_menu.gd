extends CanvasLayer


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_options_pressed() -> void:
	print("Settings Pressed")


func _on_quit_pressed() -> void:
	get_tree().quit()
