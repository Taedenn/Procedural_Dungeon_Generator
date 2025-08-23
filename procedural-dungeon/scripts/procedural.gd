extends Node2D

@onready var raya_balc = preload("res://scenes/raya_balcony.tscn")

@export var grid_size = Vector2(32, 32)
@export var map_width_cells = 32
@export var map_height_cells = 32
@export var num_rooms = 5
@export var max_attempts = 100
@export var grid_color = Color(1, 1, 1, 0.2)
@export var grid_line_width = 1.0


func _ready():
	queue_redraw()
	
	var rooms_placed = []
	
	for i in range(num_rooms):
		var attempts = 0
		var placed = false
		
		while attempts < max_attempts and not placed:
			attempts += 1
			
			var grid_x = randi_range(0, map_width_cells)
			var grid_y = randi_range(0, map_height_cells)
			var snap_pos = Vector2(grid_x, grid_y) * grid_size
			
			if is_position_valid(snap_pos):
				var new_room = place_room(snap_pos)
				if new_room:
					rooms_placed.append(new_room)
					placed = true
					print("Placed room at: ", Vector2(grid_x, grid_y))
	
	for room in rooms_placed:
		var collision_checker = room.get_node("Collision_Checker")
		collision_checker.disabled = true
					
func _draw() -> void:
	for x in map_width_cells + 1:
		var start = Vector2(x * grid_size.x, 0)
		var end = Vector2(x * grid_size.x, map_height_cells * grid_size.y)
		draw_line(start, end, grid_color, grid_line_width)
		
	for y in map_height_cells + 1:
		var start = Vector2(0, y * grid_size.y)
		var end = Vector2(map_width_cells * grid_size.x, y * grid_size.y)
		draw_line(start, end, grid_color, grid_line_width)

func place_room(pos: Vector2) -> Node2D:
	var room = raya_balc.instantiate()
	room.position = pos
	add_child(room)
	return room
	
func is_position_valid(pos: Vector2) -> bool:
	var test_area = PhysicsShapeQueryParameters2D.new()
	test_area.collision_mask = 1
	test_area.transform = Transform2D(0, pos)
	
	var room_shape = raya_balc.instantiate().get_node("Collision_Checker").shape
	test_area.shape = room_shape
	
	var space_state = get_world_2d().direct_space_state
	var results = space_state.intersect_shape(test_area)
	
	return results.is_empty()
