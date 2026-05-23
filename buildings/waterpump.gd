extends Node2D

@export_group("Base Settings")
@export var building_name: String = "Water Pump"
@export var gold_cost: int = 150
@export var building_size: Vector2i = Vector2i(1, 1)
@export var prevent_overlap: bool = true

## The minimum grid distance (in tiles) required between buildings of this same type.
@export var min_distance: int = 4

@export_group("Producer Settings")
@export var radius: int = 4
@export var target_custom_data: String = "water"
@export var production_ratio: float = 1.0
@export var production_speed_ticks: int = 2

var placed_tile_pos: Vector2i = Vector2i.ZERO
var current_production_tick: int = 0

# Ezt a függvényt hívja meg a GameManager minden egyes tick alkalmával
func perform_tick() -> void:
	current_production_tick += 1
	
	# Csak akkor termel, ha eltelt a meghatározott mennyiségű tick (production_speed_ticks)
	if current_production_tick >= production_speed_ticks:
		current_production_tick = 0
		_produce_resources()

func _produce_resources() -> void:
	var game_manager = get_parent()
	if not game_manager: return
	
	# Megkeressük a GridManagert, hogy kiszámoljuk a pontos termelést a rácson
	var grid_manager = game_manager.get_node_or_null("GridManager")
	if grid_manager and grid_manager.has_method("_get_estimated_resources"):
		# Lekérjük a pontosan kiszámolt erőforrás mennyiséget a lehelyezési pozíciónk alapján
		var amount = grid_manager._get_estimated_resources(placed_tile_pos)
		
		if amount > 0 and "global_water" in game_manager:
			game_manager.global_water += amount
			# Frissítjük a fő UI-t, hogy azonnal látszódjon a növekedés
			if game_manager.has_method("_update_ui_text"):
				game_manager._update_ui_text()
