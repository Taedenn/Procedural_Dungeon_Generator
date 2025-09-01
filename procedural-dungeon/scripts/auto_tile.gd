extends Node2D

@onready var tiles = $TileMapLayer
@export var terrain_set: int = 1
@export var terrain: int = 0

# pixel size of tileset
@export var grid_size = Vector2i(32, 64)

# height/width of dungeon bounds
@export var map_width = 32
@export var map_height = 16
@export var draw_grid: bool = false

@export var num_rooms = 8

# min/max of room dimensions
@export var min_room_size = Vector2i(4,2)
@export var max_room_size = Vector2i(6,3)

# affects how sparse the corridors will be
# by culling percentage of remaining branches: 0% - 100%
@export_range(0, 100, 10.0, "suffix:%") var tiles_to_cull: float = 60.0

# prevent infinite loops
var max_attempts = 100

# keep track of room tiles, rooms placed,
# tiles already visted, and corridor tiles
var room_tiles: Array[Vector2i] = []
var rooms_placed: Array[Rect2i] = []
var visited_tiles: Array[Vector2i] = []
var corridor_tiles: Array[Vector2i] = []

# for drawing grid (optional)
var grid_color = Color(1, 1, 1, 0.2)
var grid_line_width = 1.0

func _ready():
	generate_dungeon()

func _draw() -> void:
	## draw simple grid
	if draw_grid:
		for x in map_width + 1:
			var start = Vector2(x * grid_size.x, 0)
			var end = Vector2(x * grid_size.x, map_height * grid_size.y)
			draw_line(start, end, grid_color, grid_line_width)
			
		for y in map_height + 1:
			var start = Vector2(0, y * grid_size.y)
			var end = Vector2(map_width * grid_size.x, y * grid_size.y)
			draw_line(start, end, grid_color, grid_line_width)

func generate_dungeon(): 
	## place number of rooms specified with given dimensions, 
	## place player, and begin flood fill
	
	queue_redraw()
	clear_dungeon()
	
	if terrain_set == 0:
		grid_size.y = 32
		min_room_size = Vector2i(3,3)
		max_room_size = Vector2i(6,6)
	else:
		grid_size.y = 64
		map_height = int(map_height / 2)
		min_room_size = Vector2i(4,2)
		max_room_size = Vector2i(6,3)
	
	# make sure tileset matches desired grid_size
	tiles.tile_set.tile_size = grid_size
	
	var player_placed = false
	
	for i in range(num_rooms):
		var attempts = 0
		var placed = false
		
		while attempts < max_attempts and not placed:
			attempts += 1
			
			var room_width = randi_range(min_room_size.x, max_room_size.x)
			var room_height = randi_range(min_room_size.y, max_room_size.y)
			
			var grid_x = randi_range(0, map_width - room_width)
			var grid_y = randi_range(0, map_height - room_height)
			
			var room_rect = Rect2i(grid_x, grid_y, room_width, room_height)
			
			if is_position_valid(room_rect, rooms_placed):
				place_room(room_rect)
				rooms_placed.append(room_rect)
				placed = true
				if not player_placed:
					var player_instance = $Camera
					player_instance.position = (room_rect.position + room_rect.size/2) * grid_size + grid_size / 2
					player_instance.visible = true
					player_placed = true
	flood_fill()
	room_connections()
	cull_corridors()

func clear_dungeon():
	room_tiles.clear()
	rooms_placed.clear()
	visited_tiles.clear()
	corridor_tiles.clear()
	tiles.clear()
	
	"for child in get_children():
		if child is CharacterBody2D:
			child.queue_free()"

func place_room(room_rect: Rect2i):
	
	for x in range(room_rect.position.x, room_rect.position.x + room_rect.size.x):
		for y in range(room_rect.position.y, room_rect.position.y + room_rect.size.y):
			room_tiles.append(Vector2i(x, y))

func flood_fill():
	## begin flood fill algorithm, 
	## find all empty spaces leftover and fill according to rules
	
	var start_points = find_start_points()
	if start_points.is_empty():
		print("No valid start points")
		return
		
	start_points.shuffle()
	var start = start_points.pop_back()
	flood_fill_corridors(start, false)

func find_start_points() -> Array[Vector2i]:
	## finds all empty tiles minus ones bordering rooms
	
	var inverse_array: Array[Vector2i] = []
	var x_tiles: Array[Vector2i] = []
	
	for room in room_tiles:
		x_tiles.append(room)
		for neighbor in get_neighbors(room):
			if is_within_bounds(neighbor) and not x_tiles.has(neighbor):
				x_tiles.append(neighbor)
	
	for x in range(map_width):
		for y in range(map_height):
			var cell = Vector2i(x,y)
			if not x_tiles.has(cell):
				inverse_array.append(cell)

	return inverse_array

func flood_fill_corridors(pos: Vector2i, placed_start: bool):
	## algorithm that fills in tiles:
	##   check neighboring tiles that are empty/unvisited
	##   check neighboring tile's neighbors
	##   if more than one connection (touching filled tile), do not fill
	
	var stack: Array[Vector2i] = [pos]
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	
	while not stack.is_empty():
		var current = stack.pop_back()
		
		if (not visited_tiles.has(current) and 
			not corridor_tiles.has(current) and 
			is_within_bounds(current) and 
			not is_adjacent_to_room(current, 1)):
			
			if placed_start:
				corridor_tiles.append(current)
			
			visited_tiles.append(current)
			directions.shuffle()
			
			for direction in directions:
				var neighbor = current + direction
				
				if (not visited_tiles.has(neighbor) and 
					is_within_bounds(neighbor) and 
					not is_adjacent_to_room(neighbor, 1)):
					if not corridor_tiles.has(current):
						#if start has at least one valid neighbor, place it
						if not placed_start:
							corridor_tiles.append(current)
							placed_start = true 
					
					var connection_count = 0
					var neighbor_directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
					for neighbor_dir in neighbor_directions:
						var neighbor_neighbor = neighbor + neighbor_dir
						if (corridor_tiles.has(neighbor_neighbor) or
							room_tiles.has(neighbor_neighbor) or
							neighbor_neighbor == current):
							connection_count += 1
							
					if connection_count > 1:
						visited_tiles.append(neighbor)
						
					stack.append(neighbor)
		
		elif not placed_start:
			visited_tiles.append(current)
			
			var start_points = find_start_points()
			for tile in visited_tiles:
				start_points.erase(tile)
			start_points.shuffle()
			
			if not start_points.is_empty():
				flood_fill_corridors(start_points.pop_back(), false)
			else:
				print("No valid starting points")
				return

func room_connections():
	## find tiles neighboring rooms, choose one of these neighbors to connect to a corridor
	
	for room in rooms_placed:
		var edges = get_perimeter_points(room)
		var adjacent_tiles: Array[Vector2i] = []
		for edge in edges:
			adjacent_tiles.append_array(get_neighbors(edge))
		
		adjacent_tiles = remove_duplicates(adjacent_tiles)
		adjacent_tiles.shuffle()
		var connections: Array[Vector2i] = []
		for tile in adjacent_tiles:
			if (is_within_bounds(tile) and
				not room_tiles.has(tile)): 
					if (is_adjacent_to_corridor(tile)):
						connections.append(tile)
					elif (connections.is_empty() and get_adjacent_room_connections(tile) > 3):
						connections.append(tile)
		
		if not connections.is_empty():
			connections = reduce_array(connections)
			if not corridor_tiles.has(connections[0]):
				corridor_tiles.append(connections[0])
		else:
			var room_area = get_room_area(room)
			for tile in room_area:
				corridor_tiles.erase(tile)
				room_tiles.erase(tile)
				
	var fill_tiles = corridor_tiles + room_tiles
	tiles.set_cells_terrain_connect(fill_tiles, terrain_set, terrain, true)

func cull_corridors():
	var cull_goal = int(corridor_tiles.size() * (tiles_to_cull * 0.01))
	var total_culled = 0
	var passes = 0
	
	while total_culled < cull_goal and passes < max_attempts * 100:
		passes += 1
		var culled_this_pass = _cull_pass(cull_goal - total_culled)
		if culled_this_pass == 0:
			break
			
		total_culled += culled_this_pass
	if total_culled > 0:
		tiles.set_cells_terrain_connect(corridor_tiles, terrain_set, 0, true)

func _cull_pass(culls_this_pass: int) -> int:
	## cull corridor tiles surrounded by at least 3 empty tiles
	var cull_tiles: Array[Vector2i] = []
	var corridors_to_check = corridor_tiles.duplicate()
	corridors_to_check.shuffle()
	
	var percentage: float = tiles_to_cull * 0.01
	
	for current in corridors_to_check:
		if cull_tiles.size() >= culls_this_pass:
			break
		if is_isolated_corridor_tile(current) and randf() <= percentage:
			corridor_tiles.erase(current)
			cull_tiles.append(current)
	if not cull_tiles.is_empty():
		tiles.set_cells_terrain_connect(cull_tiles, terrain_set, -1, true)
		
	return cull_tiles.size()

func reduce_array(arr: Array) -> Array:
	var working_array = arr.duplicate()
	while working_array.size() > 1:
		@warning_ignore("integer_division")
		var items_to_remove = working_array.size() / 2
		for i in range(items_to_remove):
			var random_index = randi() % working_array.size()
			working_array.remove_at(random_index)
	return working_array

func remove_duplicates(arr: Array[Vector2i]) -> Array[Vector2i]:
	var unique: Array[Vector2i] = []
	for item in arr:
		if not unique.has(item):
			unique.append(item)
	return unique

func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return[
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x, pos.y - 1)]

func get_perimeter_points(rect: Rect2i) -> Array[Vector2i]:
	var perimeter_points: Array[Vector2i] = []
	var pos = rect.position
	var size = rect.size
	
	for x in range(pos.x, pos.x + size.x):
		perimeter_points.append(Vector2i(x, pos.y))
	
	for x in range(pos.x, pos.x + size.x):
		perimeter_points.append(Vector2i(x, pos.y + size.y - 1))
	
	for y in range(pos.y, pos.y + size.y):
		perimeter_points.append(Vector2i(pos.x, y))
	
	for y in range(pos.y, pos.y + size.y):
		perimeter_points.append(Vector2i(pos.x - 1 + size.x, y))
	
	return perimeter_points

func get_room_area(rect: Rect2i) -> Array[Vector2i]:
	var area_points: Array[Vector2i] = []
	var pos = rect.position
	var size = rect.size
	
	for x in range(pos.x, pos.x + size.x):
		for y in range(pos.y, pos.y + size.y):
			area_points.append(Vector2i(x, y))
	
	return area_points

func get_adjacent_room_connections(pos: Vector2i) -> int:
	var connections = 0
	for room in room_tiles:
		if(abs(room.x - pos.x) <= 1 and 
			abs(room.y - pos.y) <= 1):
			connections += 1
	return connections

func is_position_valid(room_rect: Rect2i, existing_rooms: Array) -> bool:
	## return whether room desired to draw intersects with any existing room
	
	var buffered_rect = Rect2i(
		room_rect.position.x - 3,
		room_rect.position.y - 3,
		room_rect.size.x + 6,
		room_rect.size.y + 6
	)
	for room in existing_rooms:
		if buffered_rect.intersects(room):
			return false
	return true

func is_empty_tile(pos: Vector2i) -> bool:
	return tiles.get_cell_source_id(pos) == -1

func is_within_bounds(pos: Vector2i) -> bool:
	return (pos.x >= 0 and pos.x < map_width and
		pos.y >= 0 and pos.y < map_height)

func is_adjacent_to_room(pos: Vector2i, distance: int = 1) -> bool:
	for room in room_tiles:
		if(abs(room.x - pos.x) <= distance and 
			abs(room.y - pos.y) <= distance):
				return true
	return false

func is_adjacent_to_corridor(pos: Vector2i) -> bool:
	var directions = [
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x, pos.y - 1)]
		
	directions.shuffle()
	for dir in directions:
		if(corridor_tiles.has(dir)):
				return true
	return false

func is_isolated_corridor_tile(pos: Vector2i) -> bool:
	var empty_neighbors = 0
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	
	for dir in directions:
		var neighbor_pos = pos + dir
		
		if (not room_tiles.has(neighbor_pos) and
			not corridor_tiles.has(neighbor_pos)):
			empty_neighbors += 1
	return empty_neighbors >= 3
