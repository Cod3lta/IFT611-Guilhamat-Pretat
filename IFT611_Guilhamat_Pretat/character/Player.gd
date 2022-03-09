extends KinematicBody2D


const GRAVITY = 25
const JUMP_AMOUNT = 450
const MAX_SPEED = Vector2(200, 400)
const ACCELERATION = 50

var horisontal_speed = 0
var velocity = Vector2.ZERO


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	get_on_floor()
	get_input()
	get_gravity()
	
	jump()
	
	apply_movements()


func get_on_floor():
	if is_on_floor():
		velocity.y = 0

func get_input():
	# move left & right
	var input_x: float = Input.get_action_strength("game_right") - Input.get_action_strength("game_left")
	var target_speed = input_x * MAX_SPEED.x
	if abs(target_speed) > abs(velocity.x):
		velocity.x = lerp(velocity.x, target_speed, 0.1) # Accelerate
	else:
		velocity.x = lerp(velocity.x, target_speed, 0.3) # Slow down


func get_gravity():
	if !is_on_floor() and velocity.y < MAX_SPEED.y:
		velocity.y += GRAVITY


func apply_movements():
	# Already uses delta in it's implementation
	move_and_slide(velocity, Vector2.UP)

func jump():
	if Input.is_action_just_pressed("game_jump") and is_on_floor():
		velocity.y = -JUMP_AMOUNT
