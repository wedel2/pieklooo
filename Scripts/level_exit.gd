extends Area2D


enum Destination {
	NEXT_LEVEL,
	PLAYER_MENU,
	MAIN_MENU
}


@export var destination: Destination = (
	Destination.NEXT_LEVEL
)

@export_file("*.tscn")
var next_level_path: String



@onready var interaction_label: Label = (
	$InteractionLabel
)


var player_inside: bool = false

var is_transitioning: bool = false


func _ready() -> void:
	interaction_label.visible = false


func _on_body_entered(
	body: Node2D
) -> void:

	if not body.is_in_group("player"):
		return

	player_inside = true

	interaction_label.visible = true


func _on_body_exited(
	body: Node2D
) -> void:

	if not body.is_in_group("player"):
		return

	player_inside = false

	interaction_label.visible = false


func _unhandled_input(
	event: InputEvent
) -> void:

	if is_transitioning:
		return

	if not player_inside:
		return

	if event.is_action_pressed(
		"interact"
	):
		enter_door()


func enter_door() -> void:##przy interakcji przenieś do odpowiedniej ścieżki
	if is_transitioning:
		return

	is_transitioning = true

	interaction_label.visible = false




	match destination:

		Destination.NEXT_LEVEL:

			if next_level_path.is_empty():
				push_error(
					"LevelExit: brak next_level_path"
				)

				is_transitioning = false
				return
			GameManager.save_game()
			await GameManager.change_level(
				next_level_path
			)


		Destination.PLAYER_MENU:

			GameManager.go_to_player_menu()


		Destination.MAIN_MENU:

			GameManager.go_to_main_menu()
