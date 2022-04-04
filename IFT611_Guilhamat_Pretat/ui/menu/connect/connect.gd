extends Menu


onready var players_list = $HBoxContainer/VBoxContainer2/ItemList
onready var start_button = $HBoxContainer/VBoxContainer/Start

const MIN_PLAYERS = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	Gamestate.connect("player_list_changed", self, "refresh_waiting_room")
	Gamestate.connect("game_error", self, "game_error")


func refresh_waiting_room():
	var players = Gamestate.get_players_list()
	players_list.clear()
	for id in players:
		var p = players[id]
		if id == get_tree().get_network_unique_id():
			p += " (You)"
		players_list.add_item(p)

	if get_tree().is_network_server():
		if players.size() < MIN_PLAYERS:
			start_button.text = "Encore " + str(MIN_PLAYERS - players.size()) + " joueur"
			start_button.disabled = true
		else:
			start_button.text = "Démarrer la partie"
			start_button.disabled = false
	else:
		start_button.hide()


func leave_game():
	get_tree().network_peer = null
	emit_signal("set_menu", "res://ui/menu/main/main.tscn")

func game_error(error):
	if error == "Server disconnected":
		get_tree().network_peer = null
		emit_signal(
			"set_menu", 
			"res://ui/menu/main/main.tscn", 
			{"error_message": "The server was disconnected"})

# The server instance pressed the "start" button
func _on_Start_pressed():
	Gamestate.begin_game()
