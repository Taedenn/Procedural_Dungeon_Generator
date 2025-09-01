extends VBoxContainer

@onready var auto_tile = get_node("../../../../..")

@onready var terrain_set_option = $TerrainSet
@onready var mwidth_slider = $MWidth
@onready var mheight_slider = $MHeight
@onready var draw_grid_check = $DrawGrid
@onready var rooms_slider = $Rooms
@onready var corridors_slider = $Corridors
@onready var generate_button = $Generate

func _ready():
	generate_button.pressed.connect(_on_generate_pressed)

	_initialize_controls_from_auto_tile()
	
func _initialize_controls_from_auto_tile():
	if auto_tile:
		terrain_set_option.selected = auto_tile.terrain_set
		mwidth_slider.value = auto_tile.map_width
		mheight_slider.value = auto_tile.map_height
		rooms_slider.value = auto_tile.num_rooms
		corridors_slider.value = auto_tile.tiles_to_cull
		draw_grid_check.button_pressed = auto_tile.draw_grid

func _on_generate_pressed():
	if auto_tile:
		
		auto_tile.terrain_set = terrain_set_option.selected
		auto_tile.map_width = int(mwidth_slider.value)
		auto_tile.map_height = int(mheight_slider.value)
		auto_tile.num_rooms = int(rooms_slider.value)
		auto_tile.tiles_to_cull = corridors_slider.value
		auto_tile.draw_grid = draw_grid_check.button_pressed
		
		auto_tile.generate_dungeon()
