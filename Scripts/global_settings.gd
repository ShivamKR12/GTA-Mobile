extends Node

const SETTINGS_PATH = "user://settings.cfg"

var shadows_enabled: bool = false
var use_sky_shader: bool = false
var master_volume: float = 1.0

func _ready():
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		shadows_enabled = config.get_value("Video", "shadows_enabled", false)
		use_sky_shader = config.get_value("Video", "use_sky_shader", false)
		master_volume = config.get_value("Audio", "master_volume", 1.0)
	else:
		# Defaults for mobile
		shadows_enabled = false
		use_sky_shader = false
		master_volume = 1.0

func save_settings():
	var config = ConfigFile.new()
	config.set_value("Video", "shadows_enabled", shadows_enabled)
	config.set_value("Video", "use_sky_shader", use_sky_shader)
	config.set_value("Audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)
