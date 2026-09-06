extends Area2D

@export var value: int = 1
@export var save_id: String = ""
var collected: bool = false

func _ready() -> void:
	if SaveManager.is_pickup_collected(save_id):
		queue_free()
		return

func _on_body_entered(body: Node2D) -> void:##przy zebraniu monety dodaj ją do monet gracza i usuń monetę
	if collected:
		return

	if not body.is_in_group("player"):
		return

	collected = true

	if not body.has_method("add_coins"):
		return
	collected = true

	SaveManager.mark_pickup_collected(save_id)
	SaveManager.add_coins(value)
	queue_free()
