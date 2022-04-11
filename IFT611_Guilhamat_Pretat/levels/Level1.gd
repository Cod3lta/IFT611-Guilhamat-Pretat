extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	$Death.set_visible(false)

func player_checkpoint(world_position: Vector2):
	var pos = $Checkpoint.world_to_map(world_position)
	$Checkpoint.set_cell(pos.x, pos.y, 0)
