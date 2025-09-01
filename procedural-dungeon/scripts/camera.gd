extends CharacterBody2D

@export var speed: int = 200

func get_input():
	var input_dir = Input.get_vector("left", "right", "up", "down")
	velocity = input_dir * speed
	
func _physics_process(_delta: float) -> void:
	get_input()
	move_and_slide()
