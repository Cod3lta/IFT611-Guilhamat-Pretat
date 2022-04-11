extends KinematicBody2D


const GRAVITY = 25
const JUMP_AMOUNT = 450
const MAX_SPEED = Vector2(200, 400)
const ACCELERATION = 50

var horisontal_speed = 0
var velocity = Vector2.ZERO
var input_x: float # The player's key input

var respawn_point: Vector2 = Vector2.ZERO

puppet var puppet_velocity = Vector2.ZERO
puppet var puppet_position = Vector2.ZERO

signal die(player)
signal checkpoint(position)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func init(color_id: int, pos: Vector2):
	$Sprite.set_texture(load("res://character/player-" + str(color_id) + ".png"))
	respawn_point = pos
	position = pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	get_on_floor()
	get_input()
	get_gravity()
	
	jump()
	
	multiplayer_movements()
	apply_movements()
	
	animate()


func get_on_floor():
	if is_on_floor():
		velocity.y = 0

func get_input():
	if is_network_master():
		# move left & right
		input_x = Input.get_action_strength("game_right") - Input.get_action_strength("game_left")
		var target_speed = input_x * MAX_SPEED.x
		if abs(target_speed) > abs(velocity.x):
			velocity.x = lerp(velocity.x, target_speed, 0.1) # Accelerate
		else:
			velocity.x = lerp(velocity.x, target_speed, 0.3) # Slow down

func get_gravity():
	if !is_on_floor() and velocity.y < MAX_SPEED.y:
		velocity.y += GRAVITY

func multiplayer_movements():
	if is_network_master():
		# TODO : don't send the position and velocity in every frame
		rset_unreliable("puppet_velocity", velocity) # used for the puppet's animations
		rset_unreliable("puppet_position", position)
	else:
		position = puppet_position
		velocity = puppet_velocity

func apply_movements():
	# Already uses delta in it's implementation
	velocity  = move_and_slide(velocity, Vector2.UP)
	# print(collision)

func jump():
	if Input.is_action_just_pressed("game_jump") and is_on_floor():
		velocity.y = -JUMP_AMOUNT

func animate():
	if not is_on_floor():
		$AnimationPlayer.play("jump")
	elif abs(velocity.x) > 3:
		$AnimationPlayer.play("walking")
	else:
		$AnimationPlayer.play("idle")
	$Sprite.flip_h = velocity.x < 0


func _on_DeathDetector_body_entered(body):
	position = respawn_point


func _on_CheckpointDetector_body_entered(body):
	if not body is TileMap: return
	emit_signal("checkpoint", self.position)
	respawn_point = position
	print(body.get_position())
	$CheckpointParticle.restart()
	
