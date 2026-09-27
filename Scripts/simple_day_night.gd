extends Node3D

@export var day_length_seconds : float = 60.0

var time_passed : float = 0.0

@onready var sun : DirectionalLight3D = null
var moon : DirectionalLight3D = null
@onready var env : WorldEnvironment = null

func _ready():
	# Start at roughly 12:00 PM (Noon) so it's bright immediately
	time_passed = day_length_seconds * 0.5 
	
	# Grab existing sun
	for child in get_children():
		if child is DirectionalLight3D and child.name != "Moon":
			sun = child
			break
			
	if not sun:
		sun = DirectionalLight3D.new()
		add_child(sun)
		
	# Spawn Moon (Guaranteed to be LIGHT1 for the sky shader)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.6, 0.8, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = true
	add_child(moon)

	# Grab environment
	for child in get_children():
		if child is WorldEnvironment:
			env = child
			break
			
	if env and env.environment:
		var new_sky = Sky.new()
		
		if get_node("/root/GlobalSettings").use_sky_shader:
			var mat = ShaderMaterial.new()
			mat.shader = load("res://sky.gdshader")
			# Set shader params to replicate the nice stylized sky
			mat.set_shader_parameter("day_top_color", Color(0.1, 0.6, 1.0))
			mat.set_shader_parameter("day_bottom_color", Color(0.4, 0.8, 1.0))
			mat.set_shader_parameter("sunset_top_color", Color(0.7, 0.75, 1.0))
			mat.set_shader_parameter("sunset_bottom_color", Color(1.0, 0.5, 0.7))
			mat.set_shader_parameter("night_top_color", Color(0.02, 0.0, 0.04))
			mat.set_shader_parameter("night_bottom_color", Color(0.1, 0.0, 0.2))
			mat.set_shader_parameter("horizon_color", Color(0.0, 0.7, 0.8))
			mat.set_shader_parameter("horizon_blur", 0.5)
			mat.set_shader_parameter("sun_color", Color(10.0, 8.0, 1.0))
			mat.set_shader_parameter("sun_sunset_color", Color(10.0, 0.0, 0.0))
			mat.set_shader_parameter("moon_color", Color(1.0, 0.95, 0.7))
			mat.set_shader_parameter("clouds_speed", 2.0)
			mat.set_shader_parameter("clouds_scale", 3.0)
			mat.set_shader_parameter("clouds_cutoff", 0.3)
			mat.set_shader_parameter("clouds_fuzziness", 0.5)
			mat.set_shader_parameter("stars_texture", load("res://Textures/stars.png"))
			mat.set_shader_parameter("stars_speed", 1.0)
			new_sky.sky_material = mat
		else:
			var mat = ProceduralSkyMaterial.new()
			mat.sky_top_color = Color(0.1, 0.6, 1.0)
			mat.sky_horizon_color = Color(0.4, 0.8, 1.0)
			mat.ground_bottom_color = Color(0.1, 0.1, 0.1)
			mat.ground_horizon_color = Color(0.4, 0.8, 1.0)
			new_sky.sky_material = mat
			
		env.environment.sky = new_sky
		env.environment.background_mode = Environment.BG_SKY
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	# Apply shadow settings
	if sun:
		sun.shadow_enabled = get_node("/root/GlobalSettings").shadows_enabled
	if moon:
		moon.shadow_enabled = get_node("/root/GlobalSettings").shadows_enabled

func _process(delta: float) -> void:
	if not sun or not moon or not env or not env.environment: return
	
	time_passed += delta
	var cycle_progress = fmod(time_passed, day_length_seconds) / day_length_seconds
	
	# Time of day from 0 to 24 (6:00 is 0.25, 12:00 is 0.5, 18:00 is 0.75, 24:00 is 1.0)
	var time_of_day = cycle_progress * 24.0
	
	# Set global shader uniform for Streetlight.gdshader (Turns off lights during the day!)
	RenderingServer.global_shader_parameter_set("Time", time_of_day)
	
	# Pass time to sky shader to animate clouds and stars
	if env.environment.sky and env.environment.sky.sky_material is ShaderMaterial:
		env.environment.sky.sky_material.set_shader_parameter("overwritten_time", time_of_day * 100.0)
	
	# Rotations
	# Sun: sunrise at 6:00 (0.25), noon at 12:00 (0.5), sunset at 18:00 (0.75)
	var angle = (cycle_progress - 0.25) * PI * 2.0
	
	sun.rotation.x = -angle
	sun.rotation.y = PI / 4.0
	sun.rotation.z = 0.0
	
	# Moon is exactly opposite to the sun.
	moon.rotation.x = -angle + PI
	moon.rotation.y = PI / 4.0
	moon.rotation.z = 0.0
	
	# Light energies
	var sun_height = -sun.global_transform.basis.z.y
	var moon_height = -moon.global_transform.basis.z.y
	
	sun.light_energy = smoothstep(-0.1, 0.1, sun_height) * 1.5
	moon.light_energy = smoothstep(-0.1, 0.1, moon_height) * 0.5
	
	# Ambient light adjusting (Make it pitch dark at night!)
	env.environment.ambient_light_energy = lerp(0.01, 1.0, clamp(sun_height, 0.0, 1.0))
	
	# Disable fog to ensure clear visibility
	env.environment.fog_enabled = false
