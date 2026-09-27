extends CharacterBody3D

enum State { IDLE, PATROL, CHASE, FLEE, DEAD }
var current_state: State = State.IDLE

@export var walk_speed := 1.0
@export var chase_speed := 2.0
@export var run_speed := 3.0
@export var health := 100
@export var dead_time := 3.0

var navigation_region: NavigationRegion3D
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh: MeshInstance3D = $"normal-man-a/Skeleton3D/Mesh"
@onready var mesh_look: Node3D = $"Mesh Look"
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree

var texture: Texture2D

@export var min_money := 50
@export var max_money := 100
@export var attack_damage := 10
@export var attack_range := 2.0
@export var attack_cooldown := 1.2

var attack_timer := 0.0
var path_update_timer := 0.0
var player: CharacterBody3D = null
var weapon_index := 0
@onready var weapon_holder: BoneAttachment3D = $"normal-man-a/Skeleton3D/Weapon Holder"

func _ready() -> void:
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	add_to_group("NPC")
	
	player = get_tree().get_first_node_in_group("Player")
	animation_tree.active = true
	animation_tree.anim_player = "AnimationPlayer"
	
	var new_mat = StandardMaterial3D.new()
	new_mat.albedo_texture = texture
	mesh.set_surface_override_material(0, new_mat)
	
	change_state(State.PATROL)

func change_state(new_state: State):
	if current_state == State.DEAD: return
	current_state = new_state
	
	match current_state:
		State.IDLE:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		State.PATROL:
			animation_tree.set("parameters/Movement/transition_request", "Walk")
			set_random_patrol_target()
		State.CHASE:
			animation_tree.set("parameters/Movement/transition_request", "Run")
		State.FLEE:
			animation_tree.set("parameters/Movement/transition_request", "Run")
			set_random_patrol_target()
		State.DEAD:
			animation_tree.active = false
			animations.play("DieN")
			if has_node("Health Bar"): $"Health Bar".hide()
			call_deferred("_finish_death")

func _physics_process(delta: float):
	if current_state == State.DEAD: return
	
	if attack_timer > 0: attack_timer -= delta
	
	if not player or not player.is_inside_tree():
		player = get_tree().get_first_node_in_group("Player")
	
	match current_state:
		State.IDLE:
			# Do nothing, await timer to switch back to patrol
			pass
			
		State.PATROL:
			move_along_path(walk_speed, delta)
			
		State.CHASE:
			if player:
				path_update_timer -= delta
				if path_update_timer <= 0:
					path_update_timer = 0.25
					navigation_agent.set_target_position(player.global_transform.origin)
				
				move_along_path(chase_speed, delta)
				
				var dist = position.distance_to(player.position)
				if dist <= attack_range and attack_timer <= 0:
					perform_attack()
					
		State.FLEE:
			move_along_path(run_speed, delta)

func move_along_path(speed: float, delta: float):
	var next_pos: Vector3 = navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = position.direction_to(next_pos) * speed
	
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = new_velocity
	else:
		_on_velocity_computed(new_velocity)
		
	# Look towards movement direction
	if velocity != Vector3.ZERO:
		var look_target = position - Vector3(velocity.x, 0, velocity.z)
		if not position.is_equal_approx(look_target):
			mesh_look.position = position
			mesh_look.look_at(look_target)
			rotation.y = lerp_angle(rotation.y, mesh_look.rotation.y, delta * 5)
			
	# Dynamic animation updating
	if velocity.length() > 0.05:
		if current_state == State.PATROL:
			animation_tree.set("parameters/Movement/transition_request", "Walk")
		else:
			animation_tree.set("parameters/Movement/transition_request", "Run")
	else:
		animation_tree.set("parameters/Movement/transition_request", "Idle")

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()

func set_random_patrol_target():
	if not navigation_region: return
	var verts = navigation_region.navigation_mesh.get_vertices()
	if verts.size() > 0:
		navigation_agent.set_target_position(verts[randi_range(0, verts.size() - 1)] * navigation_region.scale.x)

func _on_navigation_agent_3d_navigation_finished():
	if current_state == State.DEAD: return
	
	if current_state == State.FLEE:
		set_random_patrol_target()
	elif current_state == State.PATROL:
		change_state(State.IDLE)
		await get_tree().create_timer(1.0).timeout
		if current_state == State.IDLE: # Check if still idle
			change_state(State.PATROL)

func perform_attack():
	attack_timer = attack_cooldown
	var is_moving = velocity.length() > 0.1
	var active_anim = animation_tree.get("parameters/IdlePunch/active")
	weapon_holder.get_child(weapon_index).attacking = active_anim or animation_tree.get("parameters/MovePunch/active")
	
	if has_node("Damage Sound"): $"Damage Sound".play()
	
	if is_moving:
		animation_tree.set("parameters/MovePunch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		animation_tree.set("parameters/IdlePunch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if current_state == State.DEAD: return
	health = max(health - amount, 0)
	
	var hb = $"Health Bar/SubViewport/Control/ProgressBar"
	if hb: hb.value = health
	
	if has_node("Damage Sound"): $"Damage Sound".play()
	
	if health == 0:
		change_state(State.DEAD)
		return
		
	var flee_threshold := 60
	if health <= flee_threshold:
		change_state(State.FLEE)
	else:
		change_state(State.CHASE)

func _finish_death() -> void:
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	
	if has_node("Death Sound"): $"Death Sound".play()
	
	var p = get_tree().get_first_node_in_group("Player")
	if p and p.has_method("add_money"):
		p.add_money(randi_range(min_money, max_money))
		
	await get_tree().create_timer(dead_time).timeout
	queue_free()
