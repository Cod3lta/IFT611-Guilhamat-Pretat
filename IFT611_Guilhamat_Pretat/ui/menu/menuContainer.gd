extends Control


onready var current_menu = $Margin/Container.get_child(0)
var old_menu = null

# Called when the node enters the scene tree for the first time.
func _ready():
	connect_current_menu()


func set_menu(path: String, parameters: Array = []):
	old_menu = current_menu
	current_menu = load(path).instance()
	
	if current_menu.has_method("init") and not parameters.empty():
		current_menu.init(parameters)
	
	$Margin/Container.add_child(current_menu)
	old_menu.queue_free()
	connect_current_menu()


func connect_current_menu():
	current_menu.connect("set_menu", self, "set_menu")
