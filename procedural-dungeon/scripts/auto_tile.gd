extends Node2D

@onready var tiles = $TileMapLayer
@onready var player = preload("res://scenes/player.tscn")

@export var grid_size = Vector2(32, 32)
@export var map_width_cells = 32
@export var map_height_cells = 32
@export var num_rooms = 5
@export var max_attempts = 100
@export var grid_color = Color(1, 1, 1, 0.2)
@export var grid_line_width = 1.0
@export var min_room_size = Vector2i(2,2)
@export var max_room_size = Vector2i(10,10)

var room_tiles: Array[Vector2i] = []
var visited_tiles: Array[Vector2i] = []
var corridor_tiles: Array[Vector2i] = []

func _ready():
	queue_redraw()
	generate_dungeon()
	
func generate_dungeon():
	var rooms_placed = []
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
					player_instance.position = room_rect.position
					add_child(player_instance)
					player_placed = true
				print("Placed room at: ", room_rect.position, " size: ", room_rect.size)
					
	flood_fill()
	
func _draw() -> void:
	for x in map_width_cells + 1:
		var start = Vector2(x * grid_size.x, 0)
		var end = Vector2(x * grid_size.x, map_height_cells * grid_size.y)
		draw_line(start, end, grid_color, grid_line_width)
		
	for y in map_height_cells + 1:
		var start = Vector2(0, y * grid_size.y)
		var end = Vector2(map_width_cells * grid_size.x, y * grid_size.y)
		draw_line(start, end, grid_color, grid_line_width)
		
func is_position_valid(room_rect: Rect2i, existing_rooms: Array) -> bool:
	var buffered_rect = Rect2i(
		room_rect.position.x - 1,
		room_rect.position.y - 1,
		room_rect.size.x + 2,
		room_rect.size.y + 2
	)
	for room in existing_rooms:
		if buffered_rect.intersects(room):
			return false
	return true
	
func place_room(room_rect: Rect2i):
	var cells: Array[Vector2i] = []
	
	for x in range(room_rect.position.x, room_rect.position.x + room_rect.size.x):
		for y in range(room_rect.position.y, room_rect.position.y + room_rect.size.y):
			cells.append(Vector2i(x,y))
			room_tiles.append(Vector2i(x, y))
			
	tiles.set_cells_terrain_connect(cells, 0, 0, true)
		
func flood_fill():
	var start_points = find_start_points()
	#print("start points: ", start_points)
	if start_points.is_empty():
		print("Fail")
		return
		
	start_points.shuffle()
	for start in start_points:
		flood_fill_corridors(start)
	
	if not corridor_tiles.is_empty():
		tiles.set_cells_terrain_connect(corridor_tiles, 0, 0, true)
	
func find_start_points() -> Array[Vector2i]:
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
	
func flood_fill_corridors(pos: Vector2i):
	var stack: Array[Vector2i] = [pos]
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	
	while not stack.is_empty():
		var current = stack.pop_back()
		
		if (not visited_tiles.has(current) and 
			not corridor_tiles.has(current) and 
			is_within_bounds(current) and 
			not is_adjacent_to_room(current, 1)):
			
			visited_tiles.append(current)
			corridor_tiles.append(current)
			
			#print("current: ", current)
			
			directions.shuffle()
			
			for direction in directions:
				var neighbor = current + direction
				
				"""print("neighbor: ", neighbor, " ", 
				visited_tiles.has(neighbor), is_within_bounds(neighbor),
				is_adjacent_to_room(neighbor, 1))"""
				
				if (not visited_tiles.has(neighbor) and 
					is_within_bounds(neighbor) and 
					not is_adjacent_to_room(neighbor, 1)):
					#print("pass")
					
					var connection_count = 0
					var neighbor_directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
					for neighbor_dir in neighbor_directions:
						var neighbor_neighbor = neighbor + neighbor_dir
						
						"""print("neighbor's neighbors: ", neighbor_neighbor, 
							corridor_tiles.has(neighbor_neighbor), room_tiles.has(neighbor_neighbor),
							neighbor_neighbor == current)"""
						
						if (corridor_tiles.has(neighbor_neighbor) or
							room_tiles.has(neighbor_neighbor) or
							neighbor_neighbor == current):
							connection_count += 1
							#print("connections: ", connection_count)
							
					if connection_count > 1:
						visited_tiles.append(neighbor)
						
					stack.append(neighbor)
	
func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return[
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x, pos.y - 1)]
	
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
