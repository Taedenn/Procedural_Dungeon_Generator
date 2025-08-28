extends CharacterBody2D

@export var speed: int = 200

func get_input():
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * speed
	
func _physics_process(_delta: float) -> void:
	get_input()
	move_and_slide()
