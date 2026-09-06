extends Node


const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_RESOLUTION := Vector2i(1280, 720)


const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]


var current_resolution: Vector2i = DEFAULT_RESOLUTION


func _ready() -> void:
	load_settings()
	apply_resolution(
		current_resolution,
		false
	)


func apply_resolution(
	resolution: Vector2i,
	save: bool = true
) -> void:##zmień rozdzielczość
	if not RESOLUTIONS.has(resolution):
		push_warning(
			"Nieobsługiwana rozdzielczość: "
			+ str(resolution)
		)
		return

	current_resolution = resolution

	var window := get_window()

	# Zmiana rozdzielczości dotyczy trybu okienkowego.
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED

	window.size = resolution

	center_window()

	if save:
		save_settings()

	print(
		"Ustawiono rozdzielczość: ",
		resolution.x,
		" x ",
		resolution.y
	)


func center_window() -> void:##ustaw okienko na środku
	var screen := DisplayServer.window_get_current_screen()

	var usable_rect := DisplayServer.screen_get_usable_rect(
		screen
	)

	var window_size := current_resolution

	var new_position := (
		usable_rect.position
		+ (
			usable_rect.size
			- window_size
		) / 2
	)

	DisplayServer.window_set_position(
		new_position
	)


func save_settings() -> void:##zapisz w jakiej rozdzielczości jest gra
	var config := ConfigFile.new()

	config.set_value(
		"display",
		"resolution_width",
		current_resolution.x
	)

	config.set_value(
		"display",
		"resolution_height",
		current_resolution.y
	)

	var error := config.save(
		SETTINGS_PATH
	)

	if error != OK:
		push_error(
			"Nie udało się zapisać ustawień."
		)


func load_settings() -> void:##wczytaj ustawienia
	var config := ConfigFile.new()

	var error := config.load(
		SETTINGS_PATH
	)

	if error != OK:
		current_resolution = DEFAULT_RESOLUTION
		return

	var width := int(
		config.get_value(
			"display",
			"resolution_width",
			DEFAULT_RESOLUTION.x
		)
	)

	var height := int(
		config.get_value(
			"display",
			"resolution_height",
			DEFAULT_RESOLUTION.y
		)
	)

	var loaded_resolution := Vector2i(
		width,
		height
	)

	if RESOLUTIONS.has(
		loaded_resolution
	):
		current_resolution = loaded_resolution
	else:
		current_resolution = DEFAULT_RESOLUTION
