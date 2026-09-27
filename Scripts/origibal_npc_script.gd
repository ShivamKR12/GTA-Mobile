extends CharacterBody3D

@export var walk_speed := 1.0
@export var run_speed := 3.0
@export var health := 100
@export var dead_time := 3.0
var navigation_region:NavigationRegion3D
@onready var navigation_agent:NavigationAgent3D = $NavigationAgent3D
@onready var mesh:MeshInstance3D = $"normal-man-a/Skeleton3D/Mesh"
@onready var mesh_look:Node3D = $"Mesh Look"
@onready var animations:AnimationPlayer = $AnimationPlayer
var move := true
var run := false
var dead := false
var texture:Texture2D

@export var min_money := 50
@export var max_money := 100

func _ready() -> void:
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	patroll()
	animations.play("WalkN")
	var new_mat = StandardMaterial3D.new()
	new_mat.albedo_texture = texture
	mesh.set_surface_override_material(0, new_mat)

func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)

func _physics_process(delta):
	if !move or dead: return
	
	if velocity == Vector3.ZERO: _on_navigation_agent_3d_navigation_finished()
	else:
		mesh_look.position = position
		mesh_look.look_at(position - Vector3(velocity.x, 0, velocity.z))
		rotation.y = lerp_angle(rotation.y, mesh_look.rotation.y, delta * 5)
	
	var movement_speed := walk_speed
	if run: movement_speed = run_speed
	
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = position.direction_to(next_path_position) * movement_speed
	if navigation_agent.avoidance_enabled: navigation_agent.velocity = new_velocity
	else: _on_velocity_computed(new_velocity)

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()

func patroll():
	set_movement_target(navigation_region.navigation_mesh.get_vertices()[randi_range(0, navigation_region.navigation_mesh.get_vertices().size() - 1)] * navigation_region.scale.x)

func _on_navigation_agent_3d_navigation_finished():
	if dead: return
	if run:
		patroll()
		return
	move = false
	animations.play("IdleN")
	await get_tree().create_timer(1).timeout
	move = true
	patroll()
	if dead or run: return
	animations.play("WalkN")

func take_damage(amount:float):
	if dead: return
	health = max(health - amount, 0)
	$"Health Bar/SubViewport/Control/ProgressBar".value = health
	if !run:
		run = true
		animations.play("RunN")
	if health == 0:
		$"Death Sound".play()
		$"Health Bar".hide()
		animations.play("DieN")
		dead = true
		$CollisionShape3D.disabled = true
		velocity = Vector3.ZERO
		get_tree().get_first_node_in_group("Player").add_money(randi_range(min_money, max_money))
		await get_tree().create_timer(dead_time).timeout
		queue_free()
	else: $"Damage Sound".play()
