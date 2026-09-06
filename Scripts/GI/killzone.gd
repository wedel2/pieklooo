extends Area2D

@onready var timer: Timer = $Timer
@onready var player: CharacterBody2D = $"../Player"


func _on_body_entered(body):
	if body==player:
		timer.start()


func _on_timer_timeout():
	get_tree().reload_current_scene()
