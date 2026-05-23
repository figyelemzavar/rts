extends Node2D

# --- ECONOMY & TIME ---
var global_gold: int = 500
var global_water: int = 0

var tick_timer: float = 0.0
var tick_rate: float = 1.0
var total_ticks: int = 0

# --- NODES ---
var grid_manager: Node2D = null

# --- UI NODES ---
var ui_layer: CanvasLayer
var gold_label: Label
var water_label: Label
var time_label: Label
var building_menu: HBoxContainer

# --- DATA ---
var active_building_scene: PackedScene = null
var current_building_size: Vector2i = Vector2i(1, 1)
var available_building_scenes: Array[PackedScene] = []
var active_buildings: Array = []

func _ready() -> void:
	_setup_ui()
	
	if has_node("GridManager"):
		grid_manager = $GridManager
	else:
		print("HIBA: Nem található 'GridManager' nevű gyerekcsomópont!")
	
	_load_buildings_from_folder()

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	var top_vbox = VBoxContainer.new()
	top_vbox.position = Vector2(20, 20)
	ui_layer.add_child(top_vbox)
	
	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 22)
	top_vbox.add_child(gold_label)
	
	water_label = Label.new()
	water_label.add_theme_font_size_override("font_size", 22)
	water_label.modulate = Color(0.3, 0.6, 1.0)
	top_vbox.add_child(water_label)
	
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 18)
	top_vbox.add_child(time_label)
	
	building_menu = HBoxContainer.new()
	building_menu.position = Vector2(20, get_viewport_rect().size.y - 80)
	building_menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	building_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_layer.add_child(building_menu)
	
	_update_ui_text()

func _update_ui_text() -> void:
	if gold_label: gold_label.text = "Gold: " + str(global_gold)
	if water_label: water_label.text = "Water: " + str(global_water)
	if time_label: time_label.text = "Time (Tick): " + str(total_ticks)

func _load_buildings_from_folder() -> void:
	var path = "res://buildings/"
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)
		return
		
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tscn"):
				var scene = load(path + file_name)
				if scene: available_building_scenes.append(scene)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	_populate_building_menu()

func _populate_building_menu() -> void:
	for child in building_menu.get_children():
		child.queue_free()

	var cancel_btn = Button.new()
	cancel_btn.text = " Cancel (X) "
	cancel_btn.pressed.connect(func(): _select_building(null, Vector2i(1,1)))
	building_menu.add_child(cancel_btn)

	for scene in available_building_scenes:
		var temp = scene.instantiate()
		if temp:
			var cost = temp.get("gold_cost") if "gold_cost" in temp else 0
			var b_name = temp.get("building_name") if "building_name" in temp else temp.name
			var b_size = temp.get("building_size") if "building_size" in temp else Vector2i(1, 1)
			
			var btn = Button.new()
			btn.text = " %s (%dG) " % [b_name, cost]
			btn.pressed.connect(func(): _select_building(scene, b_size))
			building_menu.add_child(btn)
			temp.queue_free()

func _select_building(scene: PackedScene, size: Vector2i) -> void:
	active_building_scene = scene
	current_building_size = size
	if grid_manager and grid_manager.has_method("set_active_building"):
		grid_manager.set_active_building(scene, size)

func _process(delta: float) -> void:
	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		_on_game_tick()

func _on_game_tick() -> void:
	total_ticks += 1
	for building in active_buildings:
		if is_instance_valid(building) and building.has_method("perform_tick"):
			building.perform_tick()
	_update_ui_text()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and active_building_scene:
		if building_menu.get_global_rect().has_point(get_viewport().get_mouse_position()): return
		
		if grid_manager:
			var tile_pos = grid_manager.get_tile_under_mouse()
			if grid_manager.can_place_at(tile_pos, current_building_size):
				_place_building_logic(tile_pos)

func _place_building_logic(tile_pos: Vector2i) -> void:
	var new_building = active_building_scene.instantiate()
	var cost = new_building.get("gold_cost") if "gold_cost" in new_building else 0
	
	if global_gold < cost:
		new_building.queue_free()
		return
		
	global_gold -= cost
	_update_ui_text()
	
	new_building.global_position = grid_manager.get_world_position_for_tile(tile_pos, current_building_size)
	
	# Elmentjük a tiszta rácskoordinátát az épületbe, mielőtt a fához adnánk
	if "placed_tile_pos" in new_building:
		new_building.placed_tile_pos = tile_pos
	
	add_child(new_building)
	active_buildings.append(new_building)
	
	grid_manager.set_building_solid(tile_pos, current_building_size)
