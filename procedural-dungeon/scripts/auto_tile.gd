extends Node2D

@onready var tiles = $TileMapLayer
@onready var player = preload("res://scenes/player.tscn")

@export var grid_size = Vector2i(32, 32)
@export var map_width_cells = 32
@export var map_height_cells = 32
@export var num_rooms = 5
@export var max_attempts = 100
@export var min_room_size = Vector2i(2,2)
@export var max_room_size = Vector2i(10,10)
@export var tiles_to_cull: int = 700

var room_tiles: Array[Vector2i] = []
var rooms_placed: Array[Rect2i] = []
var visited_tiles: Array[Vector2i] = []
var corridor_tiles: Array[Vector2i] = []
var grid_color = Color(1, 1, 1, 0.2)
var grid_line_width = 1.0

func _ready():
	queue_redraw()
	generate_dungeon()
	
func generate_dungeon(): 
	## place number of rooms specified with given dimensions, 
	## place player, and begin flood fill
	
	var player_placed = false
	
	for i in range(num_rooms):
		var attempts = 0
		var placed = false
		
		while attempts < max_attempts and not placed:
			attempts += 1
			
			var room_width = randi_range(min_room_size.x, max_room_size.x)
			var room_height = randi_range(min_room_size.y, max_room_size.y)
			
			var grid_x = randi_range(0, map_width_cells - room_width)
			var grid_y = randi_range(0, map_height_cells - room_height)
			
			var room_rect = Rect2i(grid_x, grid_y, room_width, room_height)
			
			if is_position_valid(room_rect, rooms_placed):
				place_room(room_rect)
				rooms_placed.append(room_rect)
				placed = true
				if not player_placed:
					var player_instance = player.instantiate()
					player_instance.position = (room_rect.position + room_rect.size/2) * grid_size + grid_size / 2
					add_child(player_instance)
					player_placed = true
	flood_fill()
	room_connections()
	cull_corridors()

func draw() -> void:
	## draw simple grid
	
	for x in map_width_cells + 1:
		var start = Vector2(x * grid_size.x, 0)
		var end = Vector2(x * grid_size.x, map_height_cells * grid_size.y)
		draw_line(start, end, grid_color, grid_line_width)
		
	for y in map_height_cells + 1:
		var start = Vector2(0, y * grid_size.y)
		var end = Vector2(map_width_cells * grid_size.x, y * grid_size.y)
		draw_line(start, end, grid_color, grid_line_width)

func place_room(room_rect: Rect2i):
	var cells: Array[Vector2i] = []
	
	for x in range(room_rect.position.x, room_rect.position.x + room_rect.size.x):
		for y in range(room_rect.position.y, room_rect.position.y + room_rect.size.y):
			cells.append(Vector2i(x,y))
			room_tiles.append(Vector2i(x, y))
			
	tiles.set_cells_terrain_connect(cells, 0, 0, true)

func flood_fill():
	## begin flood fill algorithm, 
	## find all empty spaces leftover and fill according to rules
	
	var start_points = find_start_points()
	if start_points.is_empty():
		print("No valid start points")
		return
		
	start_points.shuffle()
	flood_fill_corridors(start_points.pop_front())
	"for start in start_points:
		flood_fill_corridors(start)"
	
	if not corridor_tiles.is_empty():
		tiles.set_cells_terrain_connect(corridor_tiles, 0, 0, true)

func room_connections():
	## find tiles neighboring rooms, choose one of these neighbors to connect to a corridor
	
	for room in rooms_placed:
		var edges = get_perimeter_points(room)
		var adjacent_tiles: Array[Vector2i] = []
		for edge in edges:
			adjacent_tiles.append_array(get_neighbors(edge))
		
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
			tiles.set_cells_terrain_connect(connections, 0, 0, true)

func cull_corridors():
	var attempts = 0
	var cull_count = 0
	cull_corridors_recursive(attempts, cull_count)

func cull_corridors_recursive(attempts: int, cull_count: int):
	## cull corridor tiles surrounded by at least 3 empty tiles
	
	if cull_count >= tiles_to_cull or attempts >= max_attempts * 100:
		return
	
	var cull_tiles: Array[Vector2i] = []
	var corridors_to_check = corridor_tiles.duplicate()
	
	for current in corridors_to_check:		
		if cull_count >= tiles_to_cull or attempts >= max_attempts * 100:
			break
		
		if (is_isolated_corridor_tile(current)):
			corridor_tiles.erase(current)
			cull_tiles.append(current)
			#print("culled tile: ", current, " count: ", cull_count + 1, "/", tiles_to_cull, " attempts: ", attempts + 1, "/", max_attempts * 100)
			
			tiles.set_cells_terrain_connect(cull_tiles, 0, -1, true)
			cull_corridors_recursive(attempts + 1, cull_count + 1)
			return

func flood_fill_corridors(pos: Vector2i):
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
			
			visited_tiles.append(current)
			
			directions.shuffle()
			
			for direction in directions:
				var neighbor = current + direction
				
				if (not visited_tiles.has(neighbor) and 
					is_within_bounds(neighbor) and 
					not is_adjacent_to_room(neighbor, 1)):
					if not corridor_tiles.has(current):
						corridor_tiles.append(current) 
					#if current has at least one valid neighbor, place it
					
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

func reduce_array(arr: Array) -> Array:
	var working_array = arr.duplicate()
	while working_array.size() > 1:
		@warning_ignore("integer_division")
		var items_to_remove = working_array.size() / 2
		for i in range(items_to_remove):
			var random_index = randi() % working_array.size()
			working_array.remove_at(random_index)
	return working_array

func find_start_points() -> Array[Vector2i]:
	## finds all empty tiles minus ones bordering rooms
	
	var inverse_array: Array[Vector2i] = []
	
	var x_tiles: Array[Vector2i] = []
	for room in room_tiles:
		x_tiles.append(room)
		for neighbor in get_neighbors(room):
			if is_within_bounds(neighbor) and not x_tiles.has(neighbor):
				x_tiles.append(neighbor)
	
	for x in range(map_width_cells):
		for y in range(map_height_cells):
			var cell = Vector2i(x,y)
			if not x_tiles.has(cell):
				inverse_array.append(cell)

	return inverse_array

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
	return (pos.x >= 0 and pos.x < map_width_cells and
		pos.y >= 0 and pos.y < map_height_cells)

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
	
