extends Control


@onready var new_game_button: Button = (
	$CenterContainer/VBoxContainer/NewGame
)

@onready var continue_button: Button = (
	$CenterContainer/VBoxContainer/Loadgame
)

@onready var resolution_option: OptionButton = (
	$CenterContainer/VBoxContainer/ResolutionOption
)

@onready var quit_button: Button = (
	$CenterContainer/VBoxContainer/Exit
)


func _ready() -> void:
	setup_resolution_options()

	new_game_button.pressed.connect(
		_on_new_game_button_pressed
	)

	continue_button.pressed.connect(
		_on_continue_button_pressed
	)

	resolution_option.item_selected.connect(
		_on_resolution_selected
	)

	quit_button.pressed.connect(
		_on_quit_button_pressed
	)

	continue_button.disabled = (
		not GameManager.has_save_game()
	)

	print("MAIN MENU READY")


func setup_resolution_options() -> void:##zmień rozmiar okna gry
	resolution_option.clear()

	var selected_index := 0

	for index in range(
		SettingsManager.RESOLUTIONS.size()
	):
		var resolution := (
			SettingsManager.RESOLUTIONS[index]
		)

		resolution_option.add_item(
			str(resolution.x)
			+ " x "
			+ str(resolution.y)
		)

		if (
			resolution
			== SettingsManager.current_resolution
		):
			selected_index = index

	resolution_option.select(
		selected_index
	)


func _on_new_game_button_pressed() -> void:
	print("NEW GAME CLICK")

	GameManager.new_game()


func _on_continue_button_pressed() -> void:
	print("CONTINUE CLICK")

	GameManager.load_game()


func _on_quit_button_pressed() -> void:
	print("QUIT CLICK")

	GameManager.quit_game()


func _on_resolution_selected(
	index: int
) -> void:
	print(
		"RESOLUTION CLICK: ",
		index
	)

	if index < 0:
		return

	if index >= SettingsManager.RESOLUTIONS.size():
		return

	var resolution := (
		SettingsManager.RESOLUTIONS[index]
	)

	# Nie zmieniamy rozmiaru okna podczas
	# aktywnej obsługi PopupMenu OptionButton.
	SettingsManager.call_deferred(
		"apply_resolution",
		resolution
	)
