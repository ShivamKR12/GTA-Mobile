extends CanvasLayer

@onready var main_menu = $MainMenu
@onready var options_menu = $OptionsMenu
@onready var shadows_toggle = $OptionsMenu/VBoxContainer/HBoxShadows/ShadowsToggle
@onready var shader_toggle = $OptionsMenu/VBoxContainer/HBoxShader/ShaderToggle
@onready var volume_slider = $OptionsMenu/VBoxContainer/HBoxVolume/VolumeSlider

@onready var fade_transition = $FadeTransition
@onready var fade_anim = $FadeTransition/AnimationPlayer
@onready var fade_timer = $FadeTransition/FadeTimer

var button_type = ""

func _ready() -> void:
	if has_node("OptionsMenu"):
		shadows_toggle.button_pressed = GlobalSettings.shadows_enabled
		shader_toggle.button_pressed = GlobalSettings.use_sky_shader
		volume_slider.value = GlobalSettings.master_volume
	
	if has_node("FadeTransition"):
		fade_transition.visible = true
		fade_anim.play("fade_out")
		fade_timer.timeout.connect(_on_fade_timer_timeout)

func _on_start_game_pressed() -> void:
	button_type = "start"
	fade_transition.visible = true
	fade_anim.play("fade_in")
	fade_timer.start()

func _on_options_pressed() -> void:
	button_type = "options"
	fade_transition.visible = true
	fade_anim.play("fade_in")
	fade_timer.start()

func _on_quit_pressed() -> void:
	button_type = "quit"
	fade_transition.visible = true
	fade_anim.play("fade_in")
	fade_timer.start()

func _on_shadows_toggled(toggled_on: bool) -> void:
	GlobalSettings.shadows_enabled = toggled_on

func _on_shader_toggled(toggled_on: bool) -> void:
	GlobalSettings.use_sky_shader = toggled_on

func _on_volume_changed(value: float) -> void:
	GlobalSettings.master_volume = value

func _on_apply_pressed() -> void:
	GlobalSettings.save_settings()
	button_type = "main_menu"
	fade_transition.visible = true
	fade_anim.play("fade_in")
	fade_timer.start()

func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	elif button_type == "options":
		main_menu.hide()
		options_menu.show()
		fade_anim.play("fade_out")
	elif button_type == "main_menu":
		options_menu.hide()
		main_menu.show()
		fade_anim.play("fade_out")
	elif button_type == "quit":
		get_tree().quit()
