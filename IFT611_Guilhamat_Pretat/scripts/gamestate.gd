extends Node

# This file is used as an autoloaded singleton.
# If something happens with the connection, this file will emit signals
# informing the other scenes about the events

"""#################################################
				VARIABLES
#################################################"""

# Default game server port. Can be any number between 1024 and 49151.
# Not on the list of registered or common ports as of November 2020:
# https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
const DEFAULT_PORT = 8910

# Max number of players.
const MAX_PEERS = 8

# - COMPRESS_ZSTD : Compression Zstandard.
# - COMPRESS_NONE : No compression. Uses the most bandwidth, fewest CPU resources. Mmake network debugging using tools like Wireshark easier.
# - COMPRESS_RANGE_CODER : ENet's built-in range encoding. Works well on small packets, but not the most efficient algorithm on packets >4 KB.
# - COMPRESS_FASTLZ : FastLZ compression. Less CPU resources compared to COMPRESS_ZLIB, but more bandwidth.
# - COMPRESS_ZLIB : Zlib compression. Less bandwidth compared to COMPRESS_FASTLZ, but more CPU resources. 
#     Not very efficient on packets smaller than 4 KB. Recommended to use other compression algorithms in most cases.
const COMPRESSION = NetworkedMultiplayerENet.COMPRESS_RANGE_CODER

# Game base time (reference tick)
var base_time:int = -1

# Name for my player.
var player_name = "no player name yet"
var server_only: bool = true

# Names for remote players in id -> name format.
var players = {}
var id_players_ready = []

# Signals to let lobby GUI know what's going on.
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)

"""#################################################
				INIT
#################################################"""

func _ready():
	# Connect all the callbacks related to networking.
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

"""#################################################
				EVERY INSTANCE
#################################################"""

"""#####################
Player management
#####################"""

# Callback from SceneTree.
func _player_connected(id):
	# When a player connects to the server we are already connected on, this slot is activated
	# We have to tell the newly connected player that we are here.
	# -> This signal is also emitted server-side when a new clients made a connection
	rpc_id(id, "register_player", player_name)

# Callback from SceneTree.
func _player_disconnected(id):
	if has_node("/root/World"): # Game is in progress.
		if get_tree().is_network_server():
			emit_signal("game_error", "Player " + players[id] + " disconnected")
			end_game()
	else: # Game is not in progress.
		# Unregister this player.
		unregister_player(id)

# When a player joins the game
# Called on every peer (server + the currently connecting client + the others clients)
remote func register_player(new_player_name):
	var id = get_tree().get_rpc_sender_id()
	if id == 0: # If sender == reciever
		id = get_tree().get_network_unique_id()
	
	# Add the player to the players list
	players[id] = new_player_name
	print("New player registered with id " + str(id))
	emit_signal("player_list_changed")

func unregister_player(id):
	players.erase(id)
	emit_signal("player_list_changed")

"""#####################
Start / stop game
#####################"""

remote func pre_start_game(players_init: Dictionary, base_time: int):
	# Disable the main menu
	get_node("/root/MenuContainer").queue_free()
	# Preload the game scene
	var game = preload("res://game.tscn").instance()
	get_tree().get_root().add_child(game)
	
	# Init the Game node
	game.init(players_init)
	self.base_time = base_time
	
	# Tell server we are ready to start
	if not get_tree().is_network_server():
		rpc_id(1, "ready_to_start")
	else:
		ready_to_start()

remote func post_start_game():
	var game = get_node("/root/Game")
	get_tree().set_pause(false) # Unpause and unleash the game!

remote func end_game():
	if has_node("/root/Game"): # Game is in progress.
		get_node("/root/Game").queue_free() # End it
		get_tree().get_root().add_child(load("res://ui/menu/menuContainer.tscn").instance())
	players.clear()
	emit_signal("game_ended")

"""#####################
Getters and setters
#####################"""

func get_players_list():
	return self.players

# Returns the player list except the server (id = 1) if it's present
func get_clients_list():
	var clients = self.players.duplicate()
	clients.erase(1)
	return clients

func get_player_name():
	return self.player_name

"""#################################################
				THIS INSTANCE AS A CLIENT
#################################################"""

func join_game(username, ip):
	self.players.clear()
	
	var peer = NetworkedMultiplayerENet.new()
	peer.set_compression_mode(COMPRESSION)
	peer.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(peer)
	
	self.player_name = username
	self.register_player(self.player_name)
	print("Connecting to the server ", ip, ":", DEFAULT_PORT)

func cancel_join_game():
	self.players.clear()
	get_tree().set_network_peer(null) # Remove peer
	
# Callback from SceneTree, only for clients (not server).
func _connected_ok():
	# We've just connected to a server
	emit_signal("connection_succeeded")
	print("We are connected!")
	print(get_tree().get_network_connected_peers())

# Callback from SceneTree, only for clients (not server).
func _server_disconnected():
	print("server disconnected")
	end_game()
	emit_signal("game_error", "Server disconnected")

# Callback from SceneTree, only for clients (not server).
func _connected_fail():
	get_tree().set_network_peer(null) # Remove peer
	emit_signal("connection_failed")

"""#################################################
				THIS INSTANCE AS THE SERVER
#################################################"""

# This instance clicked the "host" button
func host_and_play_game(username):
	
	self.players.clear()
	# Create the network peer as a server
	var peer = NetworkedMultiplayerENet.new()
	peer.set_compression_mode(COMPRESSION)
	peer.create_server(DEFAULT_PORT, MAX_PEERS)
	print("Server created")
	get_tree().set_network_peer(peer)
	
	self.player_name = username
	self.register_player(self.player_name)

# Called by a client to tell the server he's ready
remote func ready_to_start():
	assert(get_tree().is_network_server())

	var id = get_tree().get_rpc_sender_id()
	if not id in id_players_ready:
		id_players_ready.append(id)
	# Wait for every player to be ready
	if id_players_ready.size() == players.size():
		# If everyone is ready
		for player_id in self.get_clients_list():
			rpc_id(player_id, "post_start_game")
		post_start_game()
		
		id_players_ready = []

# This instance (the server) pressed on the button "START"
func begin_game():
	assert(get_tree().is_network_server())
	
	randomize()
	
	# setup teams and player genders
	var all_players = players.duplicate(false)
	# all_players[1] = player_name
	var players_init: Dictionary = {}
	
	for i in range(all_players.size()):
		var id = all_players.keys()[i]
		players_init[id] = {
			"name": all_players[id],
			"color_id": i
		}
	
	# Determine a base epoch time
	var base_time = OS.get_system_time_msecs()

	# tell everyone to get readyD
	for id in self.get_clients_list():
		rpc_id(id, "pre_start_game", players_init, base_time)
	pre_start_game(players_init, base_time)

remote func player_reached_finish(): # When a player reaches the end of the game
	assert(get_tree().is_network_server())
	var id = get_tree().get_rpc_sender_id()
	
	if not id in id_players_ready:
		id_players_ready.append(id)
	
	if id_players_ready.size() == players.size():
		# If everyone has finished the game
		for player_id in self.get_clients_list():
			rpc_id(player_id, "end_game")
		end_game()
		
		id_players_ready = []
