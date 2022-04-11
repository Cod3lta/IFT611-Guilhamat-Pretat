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

var playable:bool = true

master var remote_movement = Vector2()
puppet var remote_transform = Transform()
puppet var remote_vel = Vector2()

#client server reconciliation
export var csr = true # Client Server Reconciliation
puppet var ack = 0 # Last movement acknowledged
var old_movement = Vector2()
var time = 0


signal die(player)
signal checkpoint(position)

# Called when the node enters the scene tree for the first time.
func _ready():
	set_network_master(1)

func init(color_id: int, pos: Vector2):
	$Sprite.set_texture(load("res://character/player-" + str(color_id) + ".png"))
	respawn_point = pos
	position = pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	animate()
	

func _physics_process(delta):
	get_on_floor()
	if playable:
		get_input()
	get_gravity()
	
	jump()
	
	multiplayer_movements(delta)
	apply_movements()

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
	if velocity.y < MAX_SPEED.y:
		velocity.y += GRAVITY

func multiplayer_movements(delta):
	if is_network_master():
		# TODO : don't send the position and velocity in every frame
		rset_unreliable("puppet_velocity", velocity) # used for the puppet's animations
		rset_unreliable("puppet_position", position)
	else:
		time += delta
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
	if not is_network_master(): return
	position = respawn_point


func _on_CheckpointDetector_body_entered(body):
	if not is_network_master(): return
	if not body is TileMap: return
	emit_signal("checkpoint", self.position)
	respawn_point = position
	print(body.get_position())
	$CheckpointParticle.restart()
	


func _on_FinishDetector_body_entered(body):
	if not is_network_master(): return
	if get_tree().is_network_server():
		Gamestate.player_reached_finish()
	else:
		Gamestate.rpc_id(1, "player_reached_finish")
	
	playable = false
	velocity = Vector2.ZERO
	$EndParticle.restart()


func move_with_reconciliation(delta):
	var old_transform = transform
	transform = remote_transform
	var vel = remote_vel
	vel = move_and_slide(vel, Vector2.UP)
	
	interpolate(old_transform)

func interpolate(old_transform):
	var timeBetween # TODO add the time between the two last received 
	transform.origin = old_transform.origin.linear_interpolate(transform.origin,timeBetween)

puppet func update_state(t, velocity, ack):
	self.remote_transform = t
	self.remote_vel = velocity
	self.ack = ack
