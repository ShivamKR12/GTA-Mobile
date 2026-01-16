extends CanvasLayer

@onready var car_indicator = $"Car Indicator"
@onready var weapons = $"Weapon Icons"
@onready var ammo = $"Weapon Icons/Ammo"
@onready var reload = $"Touch Controls/Bottom Right/Reload"
@onready var shop = $Shop
@onready var money = $Money
@onready var joystick = $"Touch Controls/Virtual Joystick"

func _ready():
	shop.hide()
	setup_sound(self)

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
