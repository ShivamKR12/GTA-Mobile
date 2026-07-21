extends Camera3D


@export var target_distance = 5.0
@export var target_height = 2.0
@export var speed := 10.0
@export var look_sensitivity := 0.005

var follow_this: Node3D = null
var cam_rot_h := 0.0
var cam_rot_v := 0.2
var manual_rotation_timer := 0.0
var last_lookat: Vector3

func _ready():
	follow_this = get_parent()
	if follow_this and follow_this.get_parent() is VehicleBody3D:
		follow_this = follow_this.get_parent()
	if follow_this:
		last_lookat = follow_this.global_transform.origin

func _input(event: InputEvent) -> void:
	if not current: return
	
	var touch = DisplayServer.is_touchscreen_available()
	var ui = get_tree().get_first_node_in_group("Player").ui if get_tree().has_group("Player") else null
	
	if (event is InputEventMouseMotion and not touch and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or (event is InputEventScreenDrag and ui and event.index != ui.joystick._touch_index):
		cam_rot_h -= event.relative.x * look_sensitivity
		cam_rot_v -= event.relative.y * look_sensitivity
		cam_rot_v = clamp(cam_rot_v, -PI/4, PI/3)
		manual_rotation_timer = 2.0 # Wait before auto-centering

func _physics_process(delta):
	if follow_this == null: return
	
	var car = follow_this as VehicleBody3D

	if manual_rotation_timer > 0:
		manual_rotation_timer -= delta
	elif car:
		# Auto-center behind the car based on movement direction
		var velocity = car.linear_velocity
		velocity.y = 0
		if velocity.length_squared() > 1.0: # Moving fast enough
			# Place the camera in the opposite direction of the velocity (behind the car)
			var target_h = atan2(-velocity.x, -velocity.z)
			
			# Check if going in reverse
			var forward = -car.global_transform.basis.z
			if velocity.dot(forward) >= 0:
				# Normalize angles for smooth interpolation
				cam_rot_h = lerp_angle(cam_rot_h, target_h, delta * 3.0)
				cam_rot_v = lerp(cam_rot_v, 0.2, delta * 3.0)

	var offset = Vector3(
		sin(cam_rot_h) * cos(cam_rot_v),
		sin(cam_rot_v),
		cos(cam_rot_h) * cos(cam_rot_v)
	) * target_distance
	
	var target_pos = follow_this.global_transform.origin + offset
	target_pos.y += target_height
	
	global_transform.origin = global_transform.origin.lerp(target_pos, delta * speed)
	
	var target_lookat = follow_this.global_transform.origin + Vector3(0, target_height * 0.5, 0)
	last_lookat = last_lookat.lerp(target_lookat, delta * speed)
	look_at(last_lookat, Vector3.UP)
