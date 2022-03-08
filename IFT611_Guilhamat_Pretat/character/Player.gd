extends KinematicBody2D


var velocity = Vector2.ZERO
var speed = 500

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	get_input()
	get_gravity()
	# Already uses delta in it's implementation
	apply_movements()


func get_input():
	var velocity_x: float = Input.get_action_strength("game_right") - Input.get_action_strength("game_left")
	velocity.x = velocity_x * speed

func get_gravity():
	velocity.y += 1

func apply_movements():
	move_and_slide(velocity)
