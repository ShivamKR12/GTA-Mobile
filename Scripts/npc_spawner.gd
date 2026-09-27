extends Node3D

var npc = preload("res://scenes/NPC.tscn")
@onready var navigation_region:NavigationRegion3D = $"../City Holder"
@export var textures:Array[Texture2D]
@export var amount := 10

func _ready() -> void:
	for x in amount:
		var current_npc = npc.instantiate()
		get_parent().add_child.call_deferred(current_npc)
		current_npc.navigation_region = navigation_region
		current_npc.position = navigation_region.navigation_mesh.get_vertices()[randi_range(0, navigation_region.navigation_mesh.get_vertices().size() - 1)] * navigation_region.scale.x
		current_npc.texture = textures.pick_random()
