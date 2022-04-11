extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func init(players: Dictionary):
	init_client(players)
	
	
	if get_tree().is_network_server():
		init_server()

func init_client(players_init: Dictionary):
	print("Players to init: ", players_init)
	var player_scene = load("res://character/Player.tscn")
	
	# Create every player
	for id in players_init:
		var p_init = players_init[id]
		
		var p = player_scene.instance()
		
		# Init with color and position
		p.init(p_init["color_id"], $Spawn.get_position())
		p.set_name(str(id)) # Use unique ID as node name
		p.set_network_master(id) #set unique id as master
		
		# Set the player's camera as the main one if we are controling it
		p.get_node("Camera").current = get_tree().get_network_unique_id() == id
		
		$Players.add_child(p)

		# Connect the player's signals
		p.connect("checkpoint", $Level1, "player_checkpoint")

func init_server():
	pass

func game_ended():
	pass
