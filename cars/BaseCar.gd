extends VehicleBody3D

@export var STEER_SPEED = 1.5
@export var STEER_LIMIT = 0.6
var steer_target = 0
@export var engine_force_value = 40

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

	var speed = linear_velocity.length() * Engine.get_frames_per_second() * delta
	traction(speed)
	$Hud/speed.text = str(round(speed * 3.8)) + "  KMPH"

	var fwd_mps = transform.basis.x.x
	
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

	steer_target = steer_input * STEER_LIMIT

	# --- ENGINE / BRAKE ---
	var forward_input := 0.0

	if joystick_active:
		# Joystick throttle (Y axis)
		forward_input = ui.joystick.output.y
	else:
		# Keyboard throttle
		forward_input = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")

	# forward_input meaning:
	# > 0 = reverse
	# < 0 = forward


	# --- APPLY VEHICLE FORCE ---
	if forward_input > 0:
		# reverse
		if speed < 20 and speed != 0:
			engine_force = clamp(engine_force_value * 3 / speed, 0, 300)
		else:
			engine_force = engine_force_value
		brake = 0.0

	elif forward_input < 0:
		# forward
		if fwd_mps >= -1:
			if speed < 30 and speed != 0:
				engine_force = -clamp(engine_force_value * 10 / speed, 0, 300)
			else:
				engine_force = -engine_force_value
		else:
			brake = 1

	else:
		# no input
		engine_force = 0
		brake = 0.0

	# --- Handbrake / walking slowdown ---
	if Input.is_action_pressed("walk"):
		brake = 3
		$wheal2.wheel_friction_slip = 0.8
		$wheal3.wheel_friction_slip = 0.8
	else:
		$wheal2.wheel_friction_slip = 3
		$wheal3.wheel_friction_slip = 3

	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

func traction(speed):
	apply_central_force(Vector3.DOWN*speed)
