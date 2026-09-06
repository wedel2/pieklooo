class_name coin
extends Area2D
##Klasa coin
##
##monety które można zebrać i kupić za nie ulepszenia gracza


@export var value: int = 1##wartość monet
@export var save_id: String = ""##id monet służące do sprawdzenia czy monety były już zebrane 
var collected: bool = false##pole pomocniczne służące do znikania zebranych monet

func _ready() -> void:
	if SaveManager.is_pickup_collected(save_id):
		queue_free()
		return

func _on_body_entered(body: Node2D) -> void:##przy zebraniu monety dodaj ją do monet gracza, usuń monetę i dodaj do zapisu jako zebraną
	if collected:
		return

	if not body.is_in_group("player"):
		return

	collected = true

	SaveManager.mark_pickup_collected(save_id)
	SaveManager.add_coins(value)
	queue_free()
