extends Node


const MAIN_MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const PLAYER_MENU_SCENE := "res://Scenes/UI/player_menu.tscn"
const START_SCENE := "res://Scenes/levels/level_01.tscn"


var is_changing_scene: bool = false


# ============================================================
# MAIN MENU
# ============================================================

func has_save_game() -> bool:##sprawdz czy istnieje zapisana gra
	return SaveManager.has_save()


#func new_game() -> void:##włącza nową grę
#	if is_changing_scene:
#		return

#	get_tree().paused = false

#	
#	SaveManager.create_new_game()
#	SaveManager.start_new_playthrough()
#	await change_scene(
#		PLAYER_MENU_SCENE
#	)
func new_game() -> void:##włącza nową grę
	get_tree().paused = false

	var error := get_tree().change_scene_to_file(
		PLAYER_MENU_SCENE
	)

func load_game() -> void:##wczytuje poprzedni profil gracza
	if is_changing_scene:
		return

	get_tree().paused = false

	if not SaveManager.load_from_disk():
		print("Nie udało się wczytać gry.")
		return

	await change_scene(
		PLAYER_MENU_SCENE
	)


# ============================================================
# PLAYER MENU
# ============================================================

func start_play() -> void:##zaczyna nową grę z nowym profilem gracza
	if is_changing_scene:
		return

	get_tree().paused = false

	# Nowy playthrough.
	# Profil, monety i permanentne ulepszenia zostają.
	# Powerupy bieżącego playthrough zostają wyzerowane.
	SaveManager.start_new_playthrough()

	SaveManager.active_scene_path = START_SCENE

	var success := await change_scene(
		START_SCENE
	)

	if not success:
		return


	# Nowy Play zaczyna z pełnym HP.
	var player := get_tree().get_first_node_in_group(
		"player"
	)

	if player != null:
		player.hp = SaveManager.get_max_hp()


	# Zapamiętujemy początkowy stan level_01.
	SaveManager.capture_current_playthrough()


func load_current_playthrough() -> void:##wczytuje zapisany profil gracza
	if is_changing_scene:
		return

	if not SaveManager.has_current_playthrough():
		print("Brak current playthrough.")
		return


	var scene_path := (
		SaveManager.get_playthrough_scene_path()
	)


	if scene_path.is_empty():
		print(
			"Current playthrough nie posiada sceny."
		)
		return


	get_tree().paused = false


	# Musi być ustawione przed zmianą sceny.
	# Dzięki temu przeciwnicy i pickupy podczas _ready()
	# wiedzą, dla którego poziomu sprawdzać save_id.
	SaveManager.active_scene_path = scene_path


	var success := await change_scene(
		scene_path
	)


	if not success:
		return


	SaveManager.restore_current_playthrough_player()


# ============================================================
# SAVE
# ============================================================

func save_game() -> void:##przekieruj do zapisu z savemanager 
	SaveManager.save_all()


# ============================================================
# ZMIANA POZIOMU
# ============================================================

func change_level(
	next_level_path: String
) -> void:##zmienia level zapisując statystyki gracza między poziomami

	if is_changing_scene:
		return

	if next_level_path.is_empty():
		push_error(
			"GameManager: next_level_path jest pusty."
		)
		return


	get_tree().paused = false


	# Zapamiętujemy HP i broń Playera na czas
	# przejścia pomiędzy scenami.
	SaveManager.capture_player_transition_state()


	# Zachowujemy stan aktualnego poziomu.
	SaveManager.capture_current_playthrough()


	# Nowa scena musi znać swoją ścieżkę już
	# podczas wykonywania _ready().
	SaveManager.active_scene_path = (
		next_level_path
	)


	var success := await change_scene(
		next_level_path
	)


	if not success:
		return


	# Przywracamy HP i broń.
	SaveManager.restore_player_transition_state()


	# Current playthrough wskazuje teraz nowy poziom.
	SaveManager.capture_current_playthrough()


# ============================================================
# POWRÓT DO PLAYER MENU
# ============================================================

func go_to_player_menu() -> void:##przejdź do player menu
	if is_changing_scene:
		return

	get_tree().paused = false


	# Jeśli jesteśmy aktualnie w poziomie,
	# zapisujemy stan playthrough do RAM.
	SaveManager.capture_current_playthrough()


	SaveManager.active_scene_path = ""


	await change_scene(
		PLAYER_MENU_SCENE
	)


# ============================================================
# POWRÓT DO MAIN MENU
# ============================================================

func go_to_main_menu() -> void:##przejdź do mainmenu
	if is_changing_scene:
		return

	get_tree().paused = false


	# Najpierw zapamiętaj aktualny poziom, pozycję,
	# HP oraz broń.
	SaveManager.capture_current_playthrough()


	# WAŻNE:
	# zapis fizycznie na dysku.
	SaveManager.save_all()


	SaveManager.active_scene_path = ""


	await change_scene(
		MAIN_MENU_SCENE
	)


# ============================================================
# SCENE CHANGER
# ============================================================

func change_scene(
	scene_path: String
) -> bool:##zmienia scenę

	if is_changing_scene:
		return false


	if scene_path.is_empty():
		push_error(
			"GameManager: scene_path jest pusty."
		)
		return false


	is_changing_scene = true


	var error := get_tree().change_scene_to_file(
		scene_path
	)


	if error != OK:
		push_error(
			"Nie udało się wczytać sceny: "
			+ scene_path
		)

		is_changing_scene = false

		return false


	# Godot 4.4:
	# czekamy, aż nowa scena faktycznie zostanie
	# utworzona i przypisana jako current_scene.
	await get_tree().process_frame


	while get_tree().current_scene == null:
		await get_tree().process_frame


	is_changing_scene = false

	return true


# ============================================================
# QUIT
# ============================================================

func quit_game() -> void:##kończy grę
	get_tree().quit()
