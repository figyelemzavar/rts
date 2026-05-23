extends Node2D

# Összekötjük a fenti generátor Node-al az Inspectorban
@export var map_generator: Node = null

var terrain_layer: TileMapLayer = null

var astar_grid: AStarGrid2D
var cell_size: Vector2i = Vector2i(64, 64)

var active_scene: PackedScene = null
var current_size: Vector2i = Vector2i(1, 1)
var ghost: Node2D
var ghost_label: Label

var active_building_radius: int = 0
var active_building_ratio: float = 0.0
var active_building_target_data: String = ""

var ghost_building_name: String = ""
var ghost_prevent_overlap: bool = false
var ghost_min_distance: int = 0

func _ready() -> void:
	terrain_layer = get_node_or_null("TileMapLayer")
	if not terrain_layer:
		terrain_layer = get_parent().get_node_or_null("TileMapLayer")
	
	if terrain_layer and terrain_layer.tile_set:
		cell_size = terrain_layer.tile_set.tile_size
		
		# Kérjük a külső scriptet, hogy először pakolja le a tile-okat
		if map_generator and map_generator.has_method("generate_new_map"):
			map_generator.generate_new_map(terrain_layer)
		else:
			print("WARNING: MapGenerator nincs beállítva vagy hiányzik a generate_new_map függvénye!")
		
		# Miután a generátor végzett, most már lekérhetjük a végleges méreteket
		setup_grid()
	else:
		print("CRITICAL ERROR: GridManager cannot find 'TileMapLayer' node anywhere!")

func setup_grid() -> void:
	astar_grid = AStarGrid2D.new()
	var map_limits = terrain_layer.get_used_rect() # Így már a frissen generált méretet kapja meg
	astar_grid.region = map_limits
	astar_grid.cell_size = cell_size
	astar_grid.update()
	
	for x in range(map_limits.position.x, map_limits.end.x):
		for y in range(map_limits.position.y, map_limits.end.y):
			var coords = Vector2i(x, y)
			var tile_data = terrain_layer.get_cell_tile_data(coords)
			if tile_data == null or not tile_data.get_custom_data("buildable"):
				astar_grid.set_point_solid(coords, true)

func _process(_delta: float) -> void:
	if ghost and active_scene:
		update_ghost_position()

func update_ghost_position() -> void:
	if not terrain_layer: return
	var mouse_pos = get_global_mouse_position()
	var tile_pos: Vector2i = terrain_layer.local_to_map(mouse_pos)
	
	var cell_center_pos = terrain_layer.map_to_local(tile_pos)
	var offset = Vector2(current_size - Vector2i(1, 1)) * Vector2(cell_size) / 2.0
	ghost.global_position = cell_center_pos + offset
	
	var valid = can_place_at(tile_pos, current_size)
	
	ghost.modulate = Color(0.2, 1, 0.2, 0.6) if valid else Color(1, 0.2, 0.2, 0.6)

	if ghost_label:
		ghost_label.global_position = ghost.global_position + Vector2(20, -20)
		
		if valid:
			if active_building_radius > 0:
				var estimated_res = _get_estimated_resources(tile_pos)
				if estimated_res > 0:
					ghost_label.text = "+%d %s" % [estimated_res, active_building_target_data.capitalize()]
					ghost_label.modulate = Color(1, 1, 1, 1)
				else:
					ghost_label.text = "0 production"
					ghost_label.modulate = Color(1, 1, 1, 1)
			else:
				ghost_label.text = "Buildable"
				ghost_label.modulate = Color(1, 1, 1, 1)
		else:
			if ghost_prevent_overlap and _is_too_close_to_same_type(tile_pos):
				ghost_label.text = "Too close to another %s!" % ghost_building_name
			else:
				ghost_label.text = "Cannot build here"
				
			ghost_label.modulate = Color(1, 1, 1, 1)

func _get_estimated_resources(center: Vector2i) -> int:
	if not terrain_layer: return 0
	var count = 0
	
	for x in range(center.x - active_building_radius, center.x + active_building_radius + current_size.x):
		for y in range(center.y - active_building_radius, center.y + active_building_radius + current_size.y):
			var target_tile = Vector2i(x, y)
			if astar_grid and astar_grid.is_in_boundsv(target_tile):
				var tile_data = terrain_layer.get_cell_tile_data(target_tile)
				if tile_data and tile_data.get_custom_data(active_building_target_data) == true:
					count += 1
					
	return int(round(count * active_building_ratio))

func can_place_at(start_tile: Vector2i, size: Vector2i) -> bool:
	if not astar_grid: return false
	
	for x in range(start_tile.x, start_tile.x + size.x):
		for y in range(start_tile.y, start_tile.y + size.y):
			var current_tile = Vector2i(x, y)
			if not astar_grid.is_in_boundsv(current_tile) or astar_grid.is_point_solid(current_tile):
				return false
				
	if ghost_prevent_overlap and _is_too_close_to_same_type(start_tile):
		return false
		
	return true

func _is_too_close_to_same_type(tile_pos: Vector2i) -> bool:
	var game_manager = get_parent()
	if game_manager and "active_buildings" in game_manager:
		for building in game_manager.active_buildings:
			if is_instance_valid(building) and "placed_tile_pos" in building and "building_name" in building:
				if building.building_name == ghost_building_name:
					var distance = tile_pos.distance_to(building.placed_tile_pos)
					if distance <= ghost_min_distance:
						return true
	return false

func set_building_solid(start_tile: Vector2i, size: Vector2i) -> void:
	if not astar_grid: return
	for x in range(start_tile.x, start_tile.x + size.x):
		for y in range(start_tile.y, start_tile.y + size.y):
			astar_grid.set_point_solid(Vector2i(x, y), true)

func get_tile_under_mouse() -> Vector2i:
	if not terrain_layer: return Vector2i.ZERO
	return terrain_layer.local_to_map(get_global_mouse_position())

func get_world_position_for_tile(tile_pos: Vector2i, size: Vector2i) -> Vector2:
	if not terrain_layer: return Vector2.ZERO
	var cell_center_pos = terrain_layer.map_to_local(tile_pos)
	var offset = Vector2(size - Vector2i(1, 1)) * Vector2(cell_size) / 2.0
	return cell_center_pos + offset

func set_active_building(scene: PackedScene, size: Vector2i) -> void:
	if ghost: ghost.queue_free()
	if ghost_label: ghost_label.queue_free()
	
	active_scene = scene
	current_size = size
	
	active_building_radius = 0
	active_building_ratio = 0.0
	active_building_target_data = ""
	
	ghost_building_name = ""
	ghost_prevent_overlap = false
	ghost_min_distance = 0
	
	if not scene: return
	
	var temp = scene.instantiate()
	
	if "building_name" in temp: ghost_building_name = temp.building_name
	if "prevent_overlap" in temp: ghost_prevent_overlap = temp.prevent_overlap
	if "min_distance" in temp: ghost_min_distance = temp.min_distance
	
	if "radius" in temp: active_building_radius = temp.radius
	if "production_ratio" in temp: active_building_ratio = temp.production_ratio
	if "target_custom_data" in temp: active_building_target_data = temp.target_custom_data
	
	ghost = Node2D.new()
	
	if active_building_radius > 0:
		var radius_visual = Polygon2D.new()
		var rad_w = float((active_building_radius * 2 + current_size.x) * cell_size.x)
		var rad_h = float((active_building_radius * 2 + current_size.y) * cell_size.y)
		radius_visual.polygon = PackedVector2Array([
			Vector2(-rad_w/2, -rad_h/2), Vector2(rad_w/2, -rad_h/2),
			Vector2(rad_w/2, rad_h/2), Vector2(-rad_w/2, rad_h/2)
		])
		radius_visual.color = Color(1, 1, 1, 0.25)
		ghost.add_child(radius_visual)
	
	var sprite_node = temp.get_node_or_null("Sprite2D")
	if sprite_node:
		var actual_sprite = Sprite2D.new()
		actual_sprite.texture = sprite_node.texture
		actual_sprite.centered = true
		ghost.add_child(actual_sprite)
	else:
		var base_visual = Polygon2D.new()
		var w = float(current_size.x * cell_size.x)
		var h = float(current_size.y * cell_size.y)
		base_visual.polygon = PackedVector2Array([
			Vector2(-w/2, -h/2), Vector2(w/2, -h/2),
			Vector2(w/2, h/2), Vector2(-w/2, h/2)
		])
		base_visual.color = Color(1, 1, 1, 1)
		ghost.add_child(base_visual)
	
	ghost.z_index = 100
	add_child(ghost)
	
	ghost_label = Label.new()
	ghost_label.add_theme_font_size_override("font_size", 16)
	ghost_label.z_index = 101
	add_child(ghost_label)
	
	temp.queue_free()
