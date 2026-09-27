extends Node3D

@export var useable := true
@export var price := 500
@export var gun_range := 50
@export var damage := 20.0
@export var fire_rate := 0.1
@export var mag_size := 30
@export var reload_time := 3.0
@export var spread := 1.0
@export var auto := true
@export var bullet_count := 1

@export var trace_time := 0.2

var fireing := false
var shooting := true
var can_shoot := true
var reloading := false
var bullets := 30

@onready var muzzle = $Muzzle
var trace_mat:StandardMaterial3D

var shot_sound := preload("res://Sound/gunshot_16.ogg")

func _ready() -> void:
	if !useable:
		hide()
		process_mode = ProcessMode.PROCESS_MODE_DISABLED
	gun_range *= 50
	bullets = mag_size
	for x in bullet_count: muzzle.add_child(RayCast3D.new())
	for x in muzzle.get_children(): x.target_position = Vector3(gun_range, 0, 0)
	var laser = ImmediateMesh.new()
	muzzle.hide()
	muzzle.mesh = laser
	var laser_mat = StandardMaterial3D.new()
	laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_mat.albedo_color = Color(5, 0, 0)
	muzzle.mesh = laser
	laser.surface_begin(Mesh.PRIMITIVE_LINES, laser_mat)
	laser.surface_add_vertex(Vector3.ZERO)
	laser.surface_add_vertex(Vector3.RIGHT * gun_range)
	laser.surface_end()
	trace_mat = StandardMaterial3D.new()
	trace_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace_mat.albedo_color = Color(5, 4, 0)

func shoot():
	if !can_shoot or reloading:
		$Gunempty05.play()
		return
	if fireing: return
	play_shot_sound()
	for x in bullet_count:
		if bullets <= 0:
			can_shoot = false
			return
		bullets -= 1
		muzzle.get_child(x).rotation.y = deg_to_rad(randf_range(-spread, spread))
		muzzle.get_child(x).rotation.z = deg_to_rad(randf_range(-spread, spread))
	for x in muzzle.get_children():
		var trace = MeshInstance3D.new()
		add_child(trace)
		trace.position = muzzle.position
		var trace_mesh = ImmediateMesh.new()
		trace.mesh = trace_mesh
		trace_mesh.surface_begin(Mesh.PRIMITIVE_LINES, trace_mat)
		trace_mesh.surface_add_vertex(Vector3.ZERO)
		if x.is_colliding():
			trace_mesh.surface_add_vertex(to_local(x.get_collision_point()))
			if x.get_collider().has_method("take_damage"): x.get_collider().take_damage(damage)
		else: trace_mesh.surface_add_vertex(x.basis.x * range)
		trace_mesh.surface_end()
		trace.reparent(get_tree().root)
		destroy_trace(trace)
	can_shoot = auto and bullets > 0
	if !can_shoot or !shooting or reloading: return
	fireing = true
	await get_tree().create_timer(fire_rate).timeout
	fireing = false
	if can_shoot and shooting and !reloading: shoot()

func start_shooting():
	if shooting or reloading: return
	can_shoot = bullets > 0
	shooting = true
	shoot()

func stop_shooting(): 
	if !shooting or reloading: return
	can_shoot = bullets > 0
	shooting = false

func reload(): 
	can_shoot = false
	shooting = false
	reloading = true
	$Reload02.play()
	await get_tree().create_timer(reload_time).timeout
	bullets = mag_size
	reloading = false
	can_shoot = true

func destroy_trace(trace:MeshInstance3D):
	await get_tree().create_timer(trace_time).timeout
	trace.queue_free()

func play_shot_sound():
	var sound = AudioStreamPlayer.new()
	sound.volume_db = -5
	sound.stream = shot_sound
	add_child(sound)
	sound.play()
	await get_tree().create_timer(shot_sound.get_length()).timeout
	sound.queue_free()
