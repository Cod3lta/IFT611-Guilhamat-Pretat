extends Menu

onready var ip_address = $IpAddress
onready var error_label = $ErrorLabel


func _on_Create_pressed():
	emit_signal("set_menu", "res://ui/menu/connect/connect.tscn")
	Gamestate.host_and_play_game()


func _on_Join_pressed():
	if not ip_address.text.is_valid_ip_address():
		error_label.text = "L'adresse IP est invalide"
		return

	error_label.text = "Connexion..."
	Gamestate.join_game(ip_address.text)
	$Join.set_disabled(true)


func on_connection_success():
	emit_signal("set_menu", "res://src/ui/menus/waiting-room/WaitingRoom.tscn", Vector2.RIGHT)
