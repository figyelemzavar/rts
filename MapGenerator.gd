# ==========================================
# MapGenerator.gd
# ==========================================
extends Node

# === GENERÁLÁSI BEÁLLÍTÁSOK ===
@export var map_width: int = 60
@export var map_height: int = 60
@export var source_id: int = 0

@export var grass_atlas_pos: Vector2i = Vector2i(0, 0)
@export var fertile_atlas_pos: Vector2i = Vector2i(0, 1)
@export var water_atlas_pos: Vector2i = Vector2i(1, 1)
@export var mountain_atlas_pos: Vector2i = Vector2i(1, 0)

var elevation_noise: FastNoiseLite
var fertility_noise: FastNoiseLite

# Ez a függvény fogja legenerálni a pályát a kapott TileMapLayer-re
func generate_new_map(terrain_layer: TileMapLayer) -> void:
	if not terrain_layer:
		print("ERROR: MapGenerator nem kapott TileMapLayer-t!")
		return
		
	setup_noises()
	terrain_layer.clear()
	
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x, y)
			var elev_val = elevation_noise.get_noise_2d(float(x), float(y))
			
			if elev_val < -0.25:
				terrain_layer.set_cell(coords, source_id, water_atlas_pos)
			elif elev_val > 0.45:
				terrain_layer.set_cell(coords, source_id, mountain_atlas_pos)
			else:
				var fert_val = fertility_noise.get_noise_2d(float(x), float(y))
				if fert_val > 0.25:
					terrain_layer.set_cell(coords, source_id, fertile_atlas_pos)
				else:
					terrain_layer.set_cell(coords, source_id, grass_atlas_pos)
					
	print("Pályagenerálás sikeresen befejeződött!")

func setup_noises() -> void:
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = randi()
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.frequency = 0.04
	
	fertility_noise = FastNoiseLite.new()
	fertility_noise.seed = randi() + 12345
	fertility_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fertility_noise.frequency = 0.1
