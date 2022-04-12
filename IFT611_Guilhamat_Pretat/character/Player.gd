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
puppet var puppet_state = {}

var playable:bool = true

master var puppet_movement = Vector2()
puppet var puppet_transform = Transform()
puppet var remote_vel = Vector2()

# Buffer containing the last two positions of the player
# Used for interpolation
var states_buffer = []
# The entries have the shape:
# 	[
#		"time": int
# 		"position": Vector2
# 		"velocity": Vector2
# 	]


export var csr = false # Client Server Reconciliation
export(float, 0, 200, 0.1) var packet_send_delay: float = 0 # Delay between outgoing packets
# TODO: use the packet_send_delay property


var time = 0
var lastTime = 0


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
	animate()
	
func _physics_process(delta):
	# Floor y velocity
	if is_on_floor():
		velocity.y = 0
	
	# Player input
	if playable: get_input()
	
	# Gravity
	if velocity.y < MAX_SPEED.y:
		velocity.y += GRAVITY
	
	# Jump
	if Input.is_action_just_pressed("game_jump") and is_on_floor():
		velocity.y = -JUMP_AMOUNT
		$JumpParticle.restart()
	
	print("States buffer size : ", states_buffer.size())
	if is_network_master():
		move_master(delta)
	else:
		move_puppet(delta)

func get_input():
	if is_network_master():
		# move left & right
		input_x = Input.get_action_strength("game_right") - Input.get_action_strength("game_left")
		var target_speed = input_x * MAX_SPEED.x
		if abs(target_speed) > abs(velocity.x):
			velocity.x = lerp(velocity.x, target_speed, 0.1) # Accelerate
		else:
			velocity.x = lerp(velocity.x, target_speed, 0.3) # Slow down

#####################################
#     MULTIPLAYER OPTIMISATION
#####################################

func _on_PacketDelay_timeout():
	if csr:
		rset_unreliable("puppet_state", {
			"time": OS.get_system_time_msecs() - Gamestate.base_time,
			"position": position,
			"velocity": velocity
		})
		
	else:
		rset_unreliable("puppet_velocity", velocity)
		rset_unreliable("puppet_position", position)

func move_master(delta: float):
	pass# if not csr:
	#	rset_unreliable("puppet_velocity", velocity)
	#	rset_unreliable("puppet_position", position)
	
	velocity = move_and_slide(velocity, Vector2.UP)

func move_puppet(delta: float):
	if csr:
		var last_state = puppet_state
		
		# If the packet is empty, we skip
		if last_state.size() == 0: return
		
		# If we have data in the buffer and the last buffer's data's time is before the last packet's time
		# OR there isn't any data in the buffer
		if states_buffer.size() > 0 and states_buffer[states_buffer.size() - 1].time < last_state.time or states_buffer.size() == 0:
			# The last recieved packet is a new one
			states_buffer.append(last_state)
		
		# While we have more than two data in the states_buffer
		while states_buffer.size() > 2: 
			# Remove the oldest data
			states_buffer.remove(0)
		
		if states_buffer.size() == 1:
			# One state is not enough to do an interpolation
			# So we do a direct assignation
			position = states_buffer[0].position
		
		if states_buffer.size() == 2:
			# Interpolate the position between states_buffer[0] and states_buffer[1]
			var dist_state0_state1: float = states_buffer[1].time - states_buffer[0].time
			var dist_state0_now: float = (OS.get_system_time_msecs() - Gamestate.base_time) - states_buffer[0].time
			var weight: float = dist_state0_now / dist_state0_state1
			interpolate(states_buffer[0], states_buffer[1], weight)
	
	else:
		position = puppet_position
		velocity = puppet_velocity


func interpolate(state_0, state_1, weight: float):
	assert(not is_network_master())
	
	# transform.origin = old_transform.origin.linear_interpolate(transform.origin, timeBetween)
	var interpolated_position: Vector2 = state_0.position.linear_interpolate(state_1.position, weight)
	var interpolated_velocity: Vector2 = state_0.velocity.linear_interpolate(state_1.velocity, weight)
	
	print("Interpolate: \t", state_0.position, "\t", state_1.position, "\t", weight, "\tNew position: ", interpolated_position)
	
	position = interpolated_position
	# velocity = interpolated_velocity
	# move_and_slide(interpolated_velocity, Vector2.UP)


#####################################
#     ANIMATION
#####################################

func animate():
	if not is_on_floor():
		$AnimationPlayer.play("jump")
	elif abs(velocity.x) > 3:
		$AnimationPlayer.play("walking")
	else:
		$AnimationPlayer.play("idle")
	
	$Sprite.flip_h = velocity.x < 0
	
	if abs(velocity.x) > 3 and is_on_floor(): 
		$FootstepsParticle.set_emitting(true)
	else:
		$FootstepsParticle.set_emitting(false)

#####################################
#     COLLISION DETECTORS
#####################################

# Death
func _on_DeathDetector_body_entered(body):
	if not is_network_master(): return
	position = respawn_point

# Checkpoint
func _on_CheckpointDetector_body_entered(body):
	if not is_network_master(): return
	if not body is TileMap: return
	emit_signal("checkpoint", self.position)
	respawn_point = position
	$CheckpointParticle.restart()

# Finish
func _on_FinishDetector_body_entered(body):
	if not is_network_master(): return
	if get_tree().is_network_server():
		Gamestate.player_reached_finish()
	else:
		Gamestate.rpc_id(1, "player_reached_finish")
	
	playable = false
	velocity = Vector2.ZERO
	$EndParticle.restart()


