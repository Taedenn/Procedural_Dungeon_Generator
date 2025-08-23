extends CharacterBody2D

@export var speed = 100

@onready var animations = $AnimationPlayer
@onready var walk = $Walk

var direction = "Down"

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed

func _physics_process(delta: float) -> void:
	get_input()
	move_and_collide(velocity * delta)
	update_animation()
	
func update_animation():
	if velocity.length() == 0:
		animations.stop()
		return
	else:
		
		var x: int = sign(velocity.x)
		var y: int = sign(velocity.y)
		
		match [x, y]:
			[0,1]: direction = "Down"
			[1,1]: direction = "Down"
			[-1,1]: direction = "Down"
			[0,-1]: direction = "Up"
			[-1,-1]: direction = "Up"
			[1,-1]: direction = "Up"
			[1,0]: direction = "Right"
			[-1,0]: direction = "Left"
			_: direction = "Down"
		
		animations.play("Walk_" + direction)
