extends Menu

onready var ip_address = $IpAddress
onready var error_label = $ErrorLabel
onready var username_label = $Username

var connecting:bool = false

func _ready():
	Gamestate.connect("connection_succeeded", self, "on_connection_success")

func init(parameters):
	var error_message = parameters['error_message']
	$ErrorLabel.set_text(error_message) # _ready not yet called -> can't use the error_label var

func _on_Create_pressed():
	emit_signal("set_menu", "res://ui/menu/connect/connect.tscn")
	Gamestate.host_and_play_game(username_label.get_text())


func _on_Join_pressed():
	if connecting:
		$Join.set_text("Rejoindre une partie")
		error_label.text = ""
		Gamestate.cancel_join_game()
		connecting = false
	else:
		if not ip_address.text.is_valid_ip_address():
			error_label.text = "L'adresse IP est invalide"
			return

		error_label.text = "Connexion..."
		$Join.set_text("Annuler")
		Gamestate.join_game(username_label.get_text(), ip_address.text)
		connecting = true


func on_connection_success():
	emit_signal("set_menu", "res://ui/menu/connect/connect.tscn")
