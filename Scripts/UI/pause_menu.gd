extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()

		get_viewport().set_input_as_handled()


func toggle_pause() -> void:##włącz pauzę
	if get_tree().paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:##pokaż menu pauzy
	show()
	get_tree().paused = true


func resume_game() -> void:##wznów grę
	hide()
	get_tree().paused = false



func _on_resume_pressed() -> void:
	resume_game()


func _on_save_pressed() -> void:
	GameManager.save_game()


func _on_main_menu_pressed() -> void:##zamień na player menu
	resume_game()
	GameManager.go_to_player_menu()


func _on_exit_pressed() -> void:
	get_tree().paused = false
	GameManager.quit_game()
