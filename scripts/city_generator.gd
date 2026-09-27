@tool
extends Node3D

@export var generate_city: bool = false:
	set(value):
		if value:
			generate()
		generate_city = false

@export var clear_city: bool = false:
	set(value):
		if value:
			clear_all()
		clear_city = false

@export_group("Grid Settings")
@export var grid_width: int = 30
@export var grid_height: int = 30
@export var tile_size: float = 2.0

# Assets
const BASE_PATH = "res://City/base.gltf"
const ROAD_STRAIGHT = "res://City/road_straight.gltf"
const ROAD_INTERSECTION = "res://City/road_junction.gltf"
const ROAD_CORNER = "res://City/road_corner.gltf"
const ROAD_TSPLIT = "res://City/road_tsplit.gltf"

var buildings = [
	"res://City/building_A.gltf", 
	"res://City/building_B.gltf",
	"res://City/building_C.gltf", 
	"res://City/building_D.gltf",
	"res://City/building_E.gltf", 
	"res://City/building_F.gltf",
	"res://City/building_G.gltf", 
	"res://City/building_H.gltf"
]

var props = [
	"res://City/dumpster.gltf", 
	"res://City/bush.gltf",
	"res://City/bench.gltf", 
	"res://City/firehydrant.gltf",
	"res://City/watertower.gltf",
	"res://City/box_A.gltf", 
	"res://City/trash_A.gltf"
]

func clear_all():
	var children = get_children()
	for i in range(children.size() - 1, -1, -1):
		children[i].free()
	print("City Cleared!")

func generate():
	clear_all()
	print("Generating Complex Organic City...")
	
	var base_scene = load(BASE_PATH)
	var road_straight = load(ROAD_STRAIGHT)
	var road_cross = load(ROAD_INTERSECTION)
	var road_corner = load(ROAD_CORNER)
	var road_tsplit = load(ROAD_TSPLIT)
	
	var loaded_buildings = []; for b in buildings: if ResourceLoader.exists(b): loaded_buildings.append(load(b))
	var loaded_props = []; for p in props: if ResourceLoader.exists(p): loaded_props.append(load(p))

	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene

	# 1. Base Grid Matrix
	var road_map = []
	for x in range(grid_width):
		var col = []
		col.resize(grid_height)
		col.fill(false)
		road_map.append(col)
		
	var road_x_indices = []; var cx = 0
	while cx < grid_width: road_x_indices.append(cx); cx += randi_range(3, 6)
	var road_z_indices = []; var cz = 0
	while cz < grid_height: road_z_indices.append(cz); cz += randi_range(3, 6)

	for rx in road_x_indices:
		for z in range(grid_height): road_map[rx][z] = true
	for rz in road_z_indices:
		for x in range(grid_width): road_map[x][rz] = true

	# 2. Randomly Prune Segments to create L-shapes, T-shapes, and Cul-de-sacs
	for rx in road_x_indices:
		for i in range(road_z_indices.size() - 1):
			if randf() > 0.65: # 35% chance to erase this block's vertical road
				for z in range(road_z_indices[i] + 1, road_z_indices[i+1]):
					road_map[rx][z] = false
					
	for rz in road_z_indices:
		for i in range(road_x_indices.size() - 1):
			if randf() > 0.65: # 35% chance to erase this block's horizontal road
				for x in range(road_x_indices[i] + 1, road_x_indices[i+1]):
					road_map[x][rz] = false

	# 3. Spawn City
	for x in range(grid_width):
		for z in range(grid_height):
			var pos = Vector3(x * tile_size, 0, z * tile_size)
			
			if road_map[x][z]:
				var n = z > 0 and road_map[x][z-1]
				var s = z < grid_height - 1 and road_map[x][z+1]
				var w = x > 0 and road_map[x-1][z]
				var e = x < grid_width - 1 and road_map[x+1][z]
				
				var count = int(n) + int(s) + int(w) + int(e)
				var mesh_inst = null
				var rot_y = 0.0
				
				if count == 4:
					mesh_inst = road_cross.instantiate()
				elif count == 3:
					mesh_inst = road_tsplit.instantiate()
					if not n: rot_y = PI
					elif not s: rot_y = 0.0
					elif not w: rot_y = -PI/2.0
					elif not e: rot_y = PI/2.0
				elif count == 2:
					if (n and s) or (w and e):
						mesh_inst = road_straight.instantiate()
						rot_y = 0.0 if (n and s) else PI/2.0
					else:
						mesh_inst = road_corner.instantiate()
						if n and e: rot_y = -PI/2.0
						elif e and s: rot_y = 0.0
						elif s and w: rot_y = PI/2.0
						elif w and n: rot_y = PI
				else:
					mesh_inst = road_straight.instantiate() # Dead end
					rot_y = 0.0 if (n or s) else PI/2.0
					
				if mesh_inst:
					add_child(mesh_inst)
					if root: mesh_inst.owner = root
					mesh_inst.position = pos
					mesh_inst.rotation.y = rot_y
			else:
				var base = base_scene.instantiate()
				add_child(base)
				if root: base.owner = root
				base.position = pos
				
				# Smart Building Placement (Distance to 2D pruned roads)
				var dist_n = 99; for i in range(1, z + 1): if road_map[x][z-i]: dist_n = i; break
				var dist_s = 99; for i in range(1, grid_height - z): if road_map[x][z+i]: dist_s = i; break
				var dist_w = 99; for i in range(1, x + 1): if road_map[x-i][z]: dist_w = i; break
				var dist_e = 99; for i in range(1, grid_width - x): if road_map[x+i][z]: dist_e = i; break
				
				var min_d = min(min(dist_n, dist_s), min(dist_w, dist_e))
				var is_sandwiched = (min_d > 1)
				
				if is_sandwiched:
					# Courtyard / Deep Block
					if loaded_props.size() > 0:
						var prop_count = randi_range(1, 3)
						for i in range(prop_count):
							var prop = loaded_props.pick_random().instantiate()
							add_child(prop)
							if root: prop.owner = root
							prop.position = pos + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
							prop.rotation.y = randf() * PI * 2.0
				else:
					var touches = []
					if dist_n == 1: touches.append(PI)
					if dist_s == 1: touches.append(0.0)
					if dist_w == 1: touches.append(-PI/2.0)
					if dist_e == 1: touches.append(PI/2.0)
					
					var face_rot = touches.pick_random() if touches.size() > 0 else 0.0
					
					if randf() > 0.2 and loaded_buildings.size() > 0:
						var bldg = loaded_buildings.pick_random().instantiate()
						add_child(bldg)
						if root: bldg.owner = root
						bldg.position = pos
						bldg.rotation.y = face_rot
					elif loaded_props.size() > 0:
						var prop_count = randi_range(1, 2)
						for i in range(prop_count):
							var prop = loaded_props.pick_random().instantiate()
							add_child(prop)
							if root: prop.owner = root
							prop.position = pos + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
							prop.rotation.y = randf() * PI * 2.0
	
	print("Organic Procedural City Generated! Blocks: ", grid_width, "x", grid_height)
