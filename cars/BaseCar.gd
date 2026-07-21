extends VehicleBody3D

@export var STEER_SPEED = 3.0
@export var STEER_LIMIT = 0.6
var steer_target = 0
@export var engine_force_value = 80.0

@onready var camera = $look/Camera3D
@onready var player_exit = $"Player Exit"
var has_player := false

func toggle_player():
	has_player = !has_player
	camera.current = has_player
	$Hud.visible = has_player

func _physics_process(delta):
	if not has_player:
		return

	var speed_mps = linear_velocity.length()
	traction(speed_mps)
	$Hud/speed.text = str(round(speed_mps * 3.6)) + "  KMPH"

	var forward_dir = -global_transform.basis.z
	var fwd_mps = linear_velocity.dot(forward_dir)
	
	var joystick_active := false

	# var touch_enabled = DisplayServer.is_touchscreen_available()
	var ui = get_tree().get_first_node_in_group("Player").ui if get_tree().has_group("Player") else null

	if ui and ui.joystick:
		if ui.joystick.output.length() > 0.05:  # A small deadzone
			joystick_active = true
	
	# --- STEERING ---
	var steer_input := 0.0

	if joystick_active:
		# Joystick steering
		steer_input = -ui.joystick.output.x
	else:
		# Keyboard steering
		steer_input = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")

	# Less steering at higher speeds for stability
	var speed_factor = clamp(speed_mps / 30.0, 0.0, 1.0)
	var current_steer_limit = lerp(STEER_LIMIT, STEER_LIMIT * 0.3, speed_factor)
	steer_target = steer_input * current_steer_limit

	# --- ENGINE / BRAKE ---
	var forward_input := 0.0

	if joystick_active:
		# Joystick throttle (Y axis)
		forward_input = ui.joystick.output.y
	else:
		# Keyboard throttle
		forward_input = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")

	# forward_input meaning:
	# > 0 = reverse / brake
	# < 0 = forward

	engine_force = 0.0
	brake = 0.0


	# --- APPLY VEHICLE FORCE ---
	if forward_input < 0:
		# forward
		if fwd_mps < -1.0: # Moving backwards, apply brakes
			brake = 5.0
		else:
			if speed_mps < 10.0:
				engine_force = -engine_force_value * 2.5
			elif speed_mps < 25.0:
				engine_force = -engine_force_value * 1.5
			else:
				engine_force = -engine_force_value

	elif forward_input > 0:
		# reverse / brake
		if fwd_mps > 1.0: # Moving forwards, apply brakes
			brake = 5.0
		else:
			if speed_mps < 10.0:
				engine_force = engine_force_value * 1.5
			else:
				engine_force = engine_force_value

	else:
		# Auto slow-down when no input
		if speed_mps > 0.5:
			brake = 1.0

	# --- Handbrake / walking slowdown ---
	if Input.is_action_pressed("walk"):
		brake = 10
		$wheal2.wheel_friction_slip = 0.8
		$wheal3.wheel_friction_slip = 0.8
	else:
		$wheal2.wheel_friction_slip = 3
		$wheal3.wheel_friction_slip = 3

	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

func traction(speed):
	# Add artificial downforce to make the car stick to the road (GTA-style)
	apply_central_force(Vector3.DOWN * speed * 2.0)
