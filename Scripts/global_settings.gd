extends Node

const SETTINGS_PATH = "user://settings.cfg"

var shadows_enabled: bool = false
var use_sky_shader: bool = false

func _ready():
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		shadows_enabled = config.get_value("Video", "shadows_enabled", false)
		use_sky_shader = config.get_value("Video", "use_sky_shader", false)
	else:
		# Defaults for mobile
		shadows_enabled = false
		use_sky_shader = false

func save_settings():
	var config = ConfigFile.new()
	config.set_value("Video", "shadows_enabled", shadows_enabled)
	config.set_value("Video", "use_sky_shader", use_sky_shader)
	config.save(SETTINGS_PATH)
