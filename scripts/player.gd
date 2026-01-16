extends CharacterBody3D

@onready var mesh_look:Node3D = $"Mesh Look"
@onready var mesh:Node3D = $"normal-man-a/Skeleton3D/Mesh"
@onready var animations:AnimationPlayer = $AnimationPlayer
@onready var animation_tree:AnimationTree = $AnimationTree

@onready var camera_holder:Node3D = $"Camera Holder"
@onready var camera_raycast:RayCast3D = $"Camera Holder/RayCast3D"
@onready var camera:Camera3D = $"Camera Holder/RayCast3D/Camera3D"
@onready var weapon_aim:SkeletonIK3D = $"normal-man-a/Skeleton3D/Weapon Aim"

@onready var ui:CanvasLayer = $"Camera Holder/RayCast3D/Camera3D/CanvasLayer"

@export var speed = 1.0
@export var walk_speed = 1.0
@export var run_speed = 3.0
@export var jump_velocity = 4.0
@export var look_sensitivity = 0.01

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var driving_car:VehicleBody3D
var detected_car:VehicleBody3D

var aiming := false
var reloading := false
var animation_attacking := false
var weapon_index := 0
@onready var weapon_holder:BoneAttachment3D = $"normal-man-a/Skeleton3D/Weapon Holder"
@onready var weapon_count := 0

@onready var touch := DisplayServer.is_touchscreen_available()

var money := 0
var total_money := 0
var purchases:Array[String]

@export var max_health := 100
var health := max_health
@export var regen_rate := 2.0 # health per second
var dead := false

func _ready() -> void:
	if !touch: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	for x in weapon_holder.get_children(): if weapon_count < 2 or x.useable: weapon_count += 1
	switch_weapon()
	add_money(0)
	load_game()
	
	add_to_group("Player")
	# ensure UI shows starting HP
	if ui and ui.has_method("update_health_bar"):
		ui.update_health_bar(health, max_health)
	if touch and ui and ui.enter_car_button:
		ui.enter_car_pressed.connect(_on_enter_car_button_pressed)

func add_money(amount:int):
	if amount > 0: total_money += amount
	money += amount
	ui.money.text = "Money: " + str(money)

func _input(event: InputEvent) -> void:
	if ui.shop.visible: return
	if (event is InputEventMouseMotion and !touch) or (event is InputEventScreenDrag and event.index != ui.joystick._touch_index):
		camera_holder.rotate_y(event.relative.x * -look_sensitivity)
		camera_raycast.rotate_x(event.relative.y * look_sensitivity)
		camera_raycast.rotation.x = clamp(camera_raycast.rotation.x, -PI/6, PI/10)
		weapon_aim.rotation.x = camera_raycast.rotation.x

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit"): quit()
	
	if Input.is_action_just_pressed("shop"): ui.toggle_shop()
	
	if Input.is_action_just_pressed("enter"):
		_handle_enter_car_action()
	
	if !dead and health < max_health:
		health = min(max_health, health + regen_rate * delta)
	
	if driving_car: return
	
	animation_attacking = animation_tree.get("parameters/IdlePunch/active") or animation_tree.get("parameters/IdleStab/active")
	if weapon_index < 2: weapon_holder.get_child(weapon_index).attacking = animation_attacking or animation_tree.get("parameters/MovePunch/active") or animation_tree.get("parameters/MoveStab/active")
	
	reloading = weapon_index > 1 and weapon_holder.get_child(weapon_index).reloading
	
	if !animation_attacking and !reloading:
		if Input.is_action_just_pressed("next_weapon"):
			if weapon_index == weapon_count - 1: weapon_index = 0
			else: weapon_index += 1
			switch_weapon()
		elif Input.is_action_just_pressed("previous_weapon"):
			if weapon_index == 0: weapon_index = weapon_count - 1
			else: weapon_index -= 1
			switch_weapon()
	
	aiming = (Input.is_action_pressed("aim") or (Input.is_action_pressed("attack") and touch)) and weapon_index > 1
	
	if weapon_index > 1: weapon_holder.get_child(weapon_index).muzzle.visible = aiming and !reloading
	
	if Input.is_action_pressed("walk") or aiming or reloading: speed = walk_speed
	else: speed = run_speed
	
	var input := Vector2.ZERO
	if !animation_attacking: input = Input.get_vector("move_left","move_right","move_forward","move_backward").normalized() * speed
	
	velocity = input.x * -camera_holder.global_basis.x + input.y * -camera_holder.global_basis.z + Vector3(0, velocity.y, 0)
	
	if input:
		mesh_look.look_at(position - Vector3(velocity.x, 0, velocity.z))
		if aiming: animation_tree.set("parameters/Movement/transition_request", "GunWalk")
		else:
			if speed == walk_speed: animation_tree.set("parameters/Movement/transition_request", "Walk")
			else: animation_tree.set("parameters/Movement/transition_request", "Run")
	else:
		if aiming: animation_tree.set("parameters/Movement/transition_request", "GunIdle")
		else: animation_tree.set("parameters/Movement/transition_request", "Idle")
	
	if aiming: rotation.y = lerp_angle(rotation.y, camera_holder.rotation.y, delta * 5)
	else: rotation.y = lerp_angle(rotation.y, mesh_look.rotation.y, delta * 5)
	
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			$"01_EffortGrunt(male)".play()
			animation_tree.set("parameters/Jump/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			velocity.y = jump_velocity
	else: velocity.y -= gravity * delta
	
	move_and_slide()
	
	if aiming:
		weapon_aim.rotation_degrees.y = lerp(weapon_aim.rotation_degrees.y, -45.0, 10 * delta)
		if !weapon_aim.is_running(): weapon_aim.start()
		weapon_aim.position = position + Vector3(0, 2, 0)
		if input: weapon_aim.rotation.y = rotation.y - deg_to_rad(30)
		else: weapon_aim.rotation.y = rotation.y - deg_to_rad(50)
	else:
		weapon_aim.rotation_degrees.y = lerp(weapon_aim.rotation_degrees.y, 0.0, 10 * delta)
		if weapon_aim.is_running(): weapon_aim.stop()
	
	if camera_raycast.is_colliding():
		camera.global_position = camera_raycast.get_collision_point()
		camera.position.z += 0.1
	else:
		var camera_distance := 2.0
		var camera_side := 0.0
		if aiming:
			camera_distance = 1.0
			camera_side = -0.8
		camera.position.z = lerpf(camera.position.z, -camera_distance, delta * 10)
		camera_raycast.position.x = lerpf(camera_raycast.position.x, camera_side, delta * 10)
		camera_raycast.target_position.z = -camera_distance - 0.1
	
	if weapon_index > 1 and !reloading and Input.is_action_just_pressed("reload"):
		animation_tree.set("parameters/Reload Time/scale", 3 / weapon_holder.get_child(weapon_index).reload_time)
		animation_tree.set("parameters/Reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		weapon_holder.get_child(weapon_index).reload()
	
	if Input.is_action_pressed("attack") and !animation_attacking and !reloading:
		if aiming: weapon_holder.get_child(weapon_index).start_shooting()
		else:
			if weapon_index > 1: weapon_holder.get_child(weapon_index).stop_shooting()
			else:
				var knife = weapon_holder.get_child(weapon_index)
				knife.start_attack()  # Begin attack and clear hit list
				if weapon_index == 1:
					if input: animation_tree.set("parameters/MoveStab/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
					else: animation_tree.set("parameters/IdleStab/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
				else:
					if input: animation_tree.set("parameters/MovePunch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
					else: animation_tree.set("parameters/IdlePunch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif weapon_index > 1: weapon_holder.get_child(weapon_index).stop_shooting()
	
	if weapon_index > 1: ui.set_ammo(weapon_holder.get_child(weapon_index).bullets, weapon_holder.get_child(weapon_index).mag_size)
	
	if not dead and health < max_health:
		health = min(max_health, health + regen_rate * delta)
		if ui and ui.has_method("update_health_bar"):
			ui.update_health_bar(health, max_health)
	
	camera_holder.position = position + Vector3(0, 1.6, 0)
	mesh_look.position = position

func _on_enter_car_button_pressed() -> void:
	# Simulate the same behavior as pressing "E"
	_handle_enter_car_action()

func switch_weapon():
	ui.set_weapon(weapon_index)
	for x in weapon_count:
		weapon_holder.get_child(x).visible = x == weapon_index
		if x == weapon_index: weapon_holder.get_child(x).process_mode = PROCESS_MODE_INHERIT
		else: weapon_holder.get_child(x).process_mode = PROCESS_MODE_DISABLED

func buy_weapon(weapon_name:String):
	var weapon := weapon_holder.find_child(weapon_name)
	if !weapon or weapon.price > money: return
	add_money(-weapon.price)
	ui.buy_weapon(weapon_name, weapon_count)
	weapon_holder.move_child(weapon, weapon_count)
	weapon_count += 1
	purchases.append(weapon_name)

func _on_car_detector_body_shape_entered(_body_rid: RID, body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	if driving_car: return
	detected_car = body
	ui.car_indicator.show()
	_update_car_ui()

func _on_car_detector_body_shape_exited(_body_rid: RID, _body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	if driving_car: return
	detected_car = null
	ui.car_indicator.hide()
	_update_car_ui()

func quit():
	save_game()
	get_tree().quit()
	# get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func save_game():
	var file = GameSave.new()
	file.money = total_money
	file.purchases = purchases
	file.position = position
	ResourceSaver.save(file, "res://save.tres")

func load_game():
	var file = ResourceLoader.load("res://save.tres")
	if !file: return
	money = file.money
	total_money = money
	position = file.position
	for x in file.purchases: buy_weapon(x)

func take_damage(amount: float) -> void:
	if dead:
		return
	health = max(health - amount, 0)
	if ui and ui.has_method("update_health_bar"):
		ui.update_health_bar(health, max_health)
	# Optional: play a damage sound if you have one, e.g. $"Damage Sound".play()
	if health == 0:
		die()

func die() -> void:
	if dead:
		return
	$"04_DeathGroan(male)".play()
	
	dead = true
	# stop movement and inputs
	velocity = Vector3.ZERO
	# play death animation if available
	animation_tree.active = false
	animations.play("DieN")
	# Disable collisions / cleanup after physics flush
	call_deferred("_player_post_death")

func _player_post_death() -> void:
	# safe to change collision state now (not during physics flush)
	#if has_node("CollisionShape3D"):
		#$CollisionShape3D.disabled = true
	# show game over UI if available
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over()
	# wait a bit then reload (or implement a better respawn)
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	var weapon = weapon_holder.get_child(weapon_index)
	if not weapon or not weapon.has_method("end_attack"):
		return
	if anim_name == "IdlePunch" or anim_name == "MovePunch" or anim_name == "IdleStab" or anim_name == "MoveStab":
		weapon_holder.get_child(weapon_index).end_attack()

func _handle_enter_car_action() -> void:
	if driving_car:
		position = driving_car.player_exit.global_position
		driving_car.toggle_player()
		driving_car = null
		camera.current = true
		ui.reparent(camera)
	elif detected_car:
		position.y = -100
		velocity = Vector3.ZERO
		driving_car = detected_car
		detected_car = null
		camera.current = false
		ui.reparent(driving_car.camera)
		driving_car.toggle_player()
		
	_update_car_ui()

func _update_car_ui():
	# If there's no UI, bail
	if not ui:
		return

	# TOUCH (mobile) UI handling
	if touch:
		if driving_car:
			# When driving on touch devices, show the *exit* button and hide player controls
			if ui.has_method("show_exit_button"):
				ui.show_exit_button()
			elif ui.has_method("show_enter_button"):
				# fallback if your UI only has one function for both states
				ui.show_enter_button()
			ui.hide_player_controls()
		else:
			# Not driving: show enter button when a car is nearby, otherwise hide it
			if detected_car:
				if ui.has_method("show_enter_button"):
					ui.show_enter_button()
			else:
				if ui.has_method("hide_enter_button"):
					ui.hide_enter_button()
			ui.show_player_controls() # player controls visible when not driving

	# DESKTOP (keyboard/mouse) UI handling
	else:
		# Ensure mobile-only enter/exit buttons are hidden on non-touch platforms
		if ui.has_method("hide_enter_button"):
			ui.hide_enter_button()
		if ui.has_method("hide_exit_button"):
			ui.hide_exit_button()
		if ui.has_method("hide_mobile_controls"):
			ui.hide_mobile_controls()
