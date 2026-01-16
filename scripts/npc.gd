extends CharacterBody3D

@export var walk_speed := 1.0
@export var chase_speed := 2.0
@export var run_speed := 3.0
@export var health := 100
@export var dead_time := 3.0
var navigation_region:NavigationRegion3D
@onready var navigation_agent:NavigationAgent3D = $NavigationAgent3D
@onready var mesh:MeshInstance3D = $"normal-man-a/Skeleton3D/Mesh"
@onready var mesh_look:Node3D = $"Mesh Look"
@onready var animations:AnimationPlayer = $AnimationPlayer
@onready var animation_tree:AnimationTree = $AnimationTree
var move := true
var run := false
var dead := false
var texture:Texture2D

@export var min_money := 50
@export var max_money := 100
@export var attack_damage := 10
@export var attack_range := 2.0
@export var attack_cooldown := 1.2
var attack_timer := 0.0
var player: CharacterBody3D = null
var chase := false
var animation_attacking := false
var weapon_index := 0
@onready var weapon_holder:BoneAttachment3D = $"normal-man-a/Skeleton3D/Weapon Holder"

func _ready() -> void:
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	patroll()
	add_to_group("NPC")
	# try to find player (may be null at startup; we'll refresh in _physics_process)
	player = get_tree().get_first_node_in_group("Player")
	animation_tree.active = true  # ✅ must be active
	animation_tree.anim_player = "AnimationPlayer"
	animation_tree.set("parameters/Movement/transition_request", "Run")
	var new_mat = StandardMaterial3D.new()
	new_mat.albedo_texture = texture
	mesh.set_surface_override_material(0, new_mat)

func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)

func _physics_process(delta):
	if dead: return
	
	# update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
	
	# keep player reference up-to-date (in case it wasn't found in _ready)
	if not player or not player.is_inside_tree():
		player = get_tree().get_first_node_in_group("Player")
	
	# existing early-return: still respect move flag
	if not move or dead: return
	
	# If NPC is running away, do original logic
	if run:
		var movement_speed := run_speed
		var next_path_position: Vector3 = navigation_agent.get_next_path_position()
		var new_velocity: Vector3 = position.direction_to(next_path_position) * movement_speed
		if navigation_agent.avoidance_enabled:
			navigation_agent.velocity = new_velocity
		else:
			_on_velocity_computed(new_velocity)
		# Rotate NPC toward movement direction (restores original look logic)
		if velocity != Vector3.ZERO:
			var look_target = position - Vector3(velocity.x, 0, velocity.z)
			if not position.is_equal_approx(look_target):
				mesh_look.position = position
				mesh_look.look_at(position - Vector3(velocity.x, 0, velocity.z))
				rotation.y = lerp_angle(rotation.y, mesh_look.rotation.y, delta * 5)
		# patroll()
		return
	
	# If chasing player, update target to player
	if player and chase:
		# Move faster if chasing
		var movement_speed = chase_speed
		var next_path_position: Vector3 = navigation_agent.get_next_path_position()
		var new_velocity: Vector3 = position.direction_to(next_path_position) * movement_speed
		
		if navigation_agent.avoidance_enabled:
			navigation_agent.velocity = new_velocity
		else:
			_on_velocity_computed(new_velocity)
		
		set_movement_target(player.global_transform.origin)
		animation_tree.set("parameters/Movement/transition_request", "Run")
		# Attack if close enough and cooldown passed
		var dist = position.distance_to(player.position)
		if dist <= attack_range and attack_timer <= 0:
			attack_timer = attack_cooldown
			animation_attacking = animation_tree.get("parameters/IdlePunch/active")
			weapon_holder.get_child(weapon_index).attacking = animation_attacking or animation_tree.get("parameters/MovePunch/active")
			$"Damage Sound".play()
			# play a punch animation if present
			if velocity.length() > 0.1:
				animation_tree.set("parameters/MovePunch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			else:
				animation_tree.set("parameters/IdlePunch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			# deliver damage directly
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
		# Rotate NPC toward movement direction (restores original look logic)
		if velocity != Vector3.ZERO:
			var look_target = position - Vector3(velocity.x, 0, velocity.z)
			if not position.is_equal_approx(look_target):
				mesh_look.position = position
				mesh_look.look_at(position - Vector3(velocity.x, 0, velocity.z))
				rotation.y = lerp_angle(rotation.y, mesh_look.rotation.y, delta * 5)
	
	# Otherwise, keep patrolling
	if move:
		var movement_speed := walk_speed
		var next_path_position: Vector3 = navigation_agent.get_next_path_position()
		var new_velocity: Vector3 = position.direction_to(next_path_position) * movement_speed
		if navigation_agent.avoidance_enabled:
			navigation_agent.velocity = new_velocity
		else:
			_on_velocity_computed(new_velocity)
		# Rotate NPC toward movement direction (restores original look logic)
		if velocity != Vector3.ZERO:
			var look_target = position - Vector3(velocity.x, 0, velocity.z)
			if not position.is_equal_approx(look_target):
				mesh_look.position = position
				mesh_look.look_at(position - Vector3(velocity.x, 0, velocity.z))
				rotation.y = lerp_angle(rotation.y, mesh_look.rotation.y, delta * 5)
	
	if velocity.length() > 0.05:
		if run:
			animation_tree.set("parameters/Movement/transition_request", "Run")
		else:
			animation_tree.set("parameters/Movement/transition_request", "Walk")
	else:
		animation_tree.set("parameters/Movement/transition_request", "Idle")

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
	animation_tree.set("parameters/Movement/transition_request", "Idle")
	await get_tree().create_timer(1).timeout
	move = true
	patroll()
	if dead or run: return
	animation_tree.set("parameters/Movement/transition_request", "Walk")

func take_damage(amount:float) -> void:
	if dead: return
	health = max(health - amount, 0)
	var hb = $"Health Bar/SubViewport/Control/ProgressBar"
	if hb: hb.value = health
	# play damage sound
	if has_node("Damage Sound"): $"Damage Sound".play()
	
	if health == 0:
		# Die: use deferred cleanup to avoid physics flush errors
		if has_node("Death Sound"): $"Death Sound".play()
		if has_node("Health Bar"): $"Health Bar".hide()
		animation_tree.active = false
		animations.play("DieN")
		dead = true
		# schedule finish in idle (not during the physics callback)
		call_deferred("_finish_death")
		return
	
	# If health low -> flee; else chase & attack player
	var flee_threshold := 60
	if health <= flee_threshold:
		run = true
		animation_tree.set("parameters/Movement/transition_request", "Run")
		# choose a flee target / keep your existing patrolling logic
		patroll()
	else:
		# Chase and retaliate
		run = false
		chase = true
		# ensure we have the player reference
		if not player or not player.is_inside_tree():
			player = get_tree().get_first_node_in_group("Player")
		if player:
			set_movement_target(player.global_transform.origin)
			animation_tree.set("parameters/Movement/transition_request", "Run")

func chase_player():
	if dead or run: return
	set_movement_target(player.position)
	animation_tree.set("parameters/Movement/transition_request", "Run")

func attack_player():
	if dead or run: return
	attack_timer = attack_cooldown
	animation_tree.set("parameters/IdlePunch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if position.distance_to(player.position) <= attack_range:
		player.take_damage(attack_damage)

func _finish_death() -> void:
	# safe to change collision state now (executed after physics flush)
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	# give money to player (if present)
	var p = get_tree().get_first_node_in_group("Player")
	if p and p.has_method("add_money"):
		p.add_money(randi_range(min_money, max_money))
	await get_tree().create_timer(dead_time).timeout
	queue_free()
