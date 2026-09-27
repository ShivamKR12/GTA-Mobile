extends CanvasLayer


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_options_pressed() -> void:
	$MainMenu.hide()
	
	if has_node("SettingsPanel"):
		$SettingsPanel.show()
		return
		
	var panel = Panel.new()
	panel.name = "SettingsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Performance Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)
	
	var shadow_btn = CheckButton.new()
	shadow_btn.text = "Enable Dynamic Shadows (Heavy GPU usage)"
	shadow_btn.button_pressed = get_node("/root/GlobalSettings").shadows_enabled
	shadow_btn.toggled.connect(func(toggled): get_node("/root/GlobalSettings").shadows_enabled = toggled)
	vbox.add_child(shadow_btn)
	
	var shader_btn = CheckButton.new()
	shader_btn.text = "Use Stylized Sky Shader (Heavy GPU usage)"
	shader_btn.button_pressed = get_node("/root/GlobalSettings").use_sky_shader
	shader_btn.toggled.connect(func(toggled): get_node("/root/GlobalSettings").use_sky_shader = toggled)
	vbox.add_child(shader_btn)
	
	var apply_btn = Button.new()
	apply_btn.text = "Apply & Return"
	apply_btn.pressed.connect(func():
		get_node("/root/GlobalSettings").save_settings()
		panel.hide()
		$MainMenu.show()
	)
	vbox.add_child(apply_btn)


func _on_quit_pressed() -> void:
	get_tree().quit()
