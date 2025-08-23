extends Node2D

@onready var tiles = $TileMapLayer

@export var grid_size = Vector2(32, 32)
@export var map_width_cells = 32
@export var map_height_cells = 32
@export var num_rooms = 5
@export var max_attempts = 100
@export var grid_color = Color(1, 1, 1, 0.2)
@export var grid_line_width = 1.0
@export var min_room_size = Vector2i(2,2)
@export var max_room_size = Vector2i(10,10)

func _ready():
	queue_redraw()
	
	var rooms_placed = []
	
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
				print("Placed room at: ", room_rect.position, "size: ", room_rect.size)
					
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
			
	tiles.set_cells_terrain_connect(cells, 0, 0, true)
		
#func flood_fill()
		
		
