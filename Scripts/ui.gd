extends CanvasLayer

@onready var car_indicator = $"Car Indicator"
@onready var weapons = $"Weapon Icons"
@onready var ammo = $"Weapon Icons/Ammo"
@onready var attack = $"Touch Controls/Bottom Right/Attack"
@onready var jump = $"Touch Controls/Bottom Right/Jump"
@onready var reload = $"Touch Controls/Bottom Right/Reload"
@onready var switch_weapon = $"Touch Controls/Bottom Right/Switch Weapon"
@onready var shop = $Shop
@onready var money = $Money
@onready var joystick = $"Touch Controls/Virtual Joystick"
@onready var enter_car_button = $"Touch Controls/Bottom Right/Enter Car"

signal enter_car_pressed

func _ready():
	shop.hide()
	setup_sound(self)
	
	if not DisplayServer.is_touchscreen_available():
		hide_mobile_controls()

func setup_sound(node:Node):
	for x in node.get_children():
		if x is BaseButton: x.pressed.connect($"JdSherbert-UltimateUiSfxPack-Cursor-4".play)
		setup_sound(x)

func set_weapon(index:int):
	for x in weapons.get_child_count(): weapons.get_child(x).visible = x == index
	ammo.visible = index > 1
	reload.visible = index > 1

func set_ammo(bullets:int, mag_size:int): ammo.text = str(bullets) + "/" + str(mag_size)

func buy_weapon(weapon_name:String, count):
	$Shop/ScrollContainer/VBoxContainer.find_child(weapon_name).hide()
	weapons.move_child(weapons.find_child(weapon_name), count)

func toggle_shop():
	if shop.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Engine.time_scale = 1
		shop.hide()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Engine.time_scale = 0
		shop.show()

func update_health_bar(current: float, maximum: float) -> void:
	var hb = $HealthBar
	if hb and hb is ProgressBar:
		hb.max_value = maximum
		hb.value = current

func show_game_over():
	var go = $GameOver
	for child in get_children():
		if child != go and child is CanvasItem:
			child.hide()
	if go:
		go.show()

func show_player_controls():
	if DisplayServer.is_touchscreen_available():
		joystick.show()
		attack.show()
		jump.show()
		reload.show()
		switch_weapon.show()
	else:
		# DESKTOP: hide all touch-only controls
		joystick.hide()
		attack.hide()
		jump.hide()
		reload.hide()
		switch_weapon.hide()

func hide_mobile_controls():
	joystick.hide()  # still show joystick
	attack.hide()
	jump.hide()
	reload.hide()
	switch_weapon.hide()
	enter_car_button.hide()

func hide_player_controls():
	joystick.show()  # still show joystick
	attack.hide()
	jump.hide()
	reload.hide()
	switch_weapon.hide()

func _on_enter_car_pressed() -> void:
	emit_signal("enter_car_pressed")

func show_enter_button():
	if enter_car_button:
		enter_car_button.show()

func hide_enter_button():
	if enter_car_button:
		enter_car_button.hide()
