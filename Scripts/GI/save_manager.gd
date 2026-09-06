class_name save_manager
extends Node
##Klasa save_manager
##
##zarząda procesem zapisu i wczytywania gry

signal coins_changed(new_amount: int)
signal upgrades_changed


const SAVE_DIR := "user://saved_games"##ścieżka katalogu z zapisami gry
const SAVE_PATH := "user://saved_games/savegame.json"##ścieżka do zapisu gry

const DAMAGE_PER_LEVEL: int = 2##dodatkowe zadawane obrażenia za poziom ulepszenia
const DAMAGE_UPGRADE_BASE_COST: int = 10##dodatkowy koszt za każdy poziom ulepszenia dmg

const BASE_MAX_HP: int = 100##początkowa wartość maksymalnego hp
const MAX_HP_PER_LEVEL: int = 20##dodatkowe punkty życia za poziom ulepszenia
const MAX_HP_UPGRADE_BASE_COST: int = 20##dodatkowy koszt za każdy poziom ulepszenia hp


# Stałe dane profilu:
# - monety
# - ulepszenia
var profile_data: Dictionary = {}##pola do zapisu profilu gracza

# Aktualna rozgrywka:
# - poziom
# - pozycja
# - HP
# - broń
# - pokonani przeciwnicy
# - zebrane pickupy
var playthrough_data: Dictionary = {}##pola do zapisu rozgrywki


# Potrzebne podczas ładowania poziomu.
# Coiny i przeciwnicy wykonują _ready() zanim GameManager
# dostanie scene_changed.
var active_scene_path: String = ""##ścieżka do aktualnego poziomu


var transition_player_state: Dictionary = {}## Tymczasowy stan gracza używany podczas przejścia np. level_01 -> level_02 itd.


func _ready() -> void:
	reset_runtime_data()


# ============================================================
# DOMYŚLNE DANE
# ============================================================

func create_default_profile() -> Dictionary:##stwórz podstawowy profil gracza
	return {
		"coins": 0,
		"damage_level": 0,
		"max_hp_level": 0
		}


func create_default_playthrough() -> Dictionary:##stwórz profil gracza do rozgrywki
	return {
		"exists": false,

		"scene_path": "",

		"player": {
			"position_x": 0.0,
			"position_y": 0.0,
			"hp": 100,
			"weapon_path": ""
		},
		
		"powerups": {
			"damage_bonus": 0
		},

		"world": {
			"defeated_enemies": {},
			"collected_pickups": {}
		}
	}


func reset_runtime_data() -> void:##usuń profil i zapisane detale rozgrywki
	profile_data = create_default_profile()
	playthrough_data = create_default_playthrough()

	active_scene_path = ""
	transition_player_state.clear()


# ============================================================
# NEW GAME
# ============================================================

func create_new_game() -> void:##zresetuj zapisane pliki i stwórz nowe pod nową rozgrywkę
	reset_runtime_data()

	delete_save()

	coins_changed.emit(get_coins())
	upgrades_changed.emit()

	print("Utworzono kompletnie nową grę.")


# ============================================================
# PROFILE - MONETY
# ============================================================

func get_coins() -> int:##sprawdż zapisaną ilosć monet
	return int(profile_data.get("coins", 0))


func add_coins(amount: int) -> void:##dodaj monety do profilu  gracza
	if amount <= 0:
		return

	profile_data["coins"] = get_coins() + amount

	coins_changed.emit(get_coins())

	print("Coins: ", get_coins())


func spend_coins(amount: int) -> bool:##wydaj monety na ulepszenia
	if amount <= 0:
		return false

	if get_coins() < amount:
		return false

	profile_data["coins"] = get_coins() - amount

	coins_changed.emit(get_coins())

	return true


# ============================================================
# PROFILE - DAMAGE UPGRADE
# ============================================================

func get_damage_level() -> int:##zwróć level ulepszenia dmg
	return int(
		profile_data.get(
			"damage_level",
			0
		)
	)


func get_damage_bonus() -> int:##dodaj bonusowy dmg z ulepszeń
	return get_damage_level() * DAMAGE_PER_LEVEL


func get_damage_upgrade_cost() -> int:##zmień koszt następnego poziomu ulepszenia
	return DAMAGE_UPGRADE_BASE_COST * (
		get_damage_level() + 1
	)


func buy_damage_upgrade() -> bool:##kup ulepszenie dmg
	var cost := get_damage_upgrade_cost()

	if not spend_coins(cost):
		print("Za mało monet na ulepszenie.")
		return false

	profile_data["damage_level"] = (
		get_damage_level() + 1
	)

	upgrades_changed.emit()

	print(
		"Damage level: ",
		get_damage_level(),
		" bonus: ",
		get_damage_bonus()
	)

	return true

# ============================================================
# POWERUP DAMAGE BONUS
# ============================================================
func get_playthrough_damage_bonus() -> int:##sprawdź jaki jest dodatkowy dmg z powerupów
	var powerups: Dictionary = playthrough_data.get(
		"powerups",
		{}
	)

	return int(
		powerups.get(
			"damage_bonus",
			0
		)
	)


func add_playthrough_damage_bonus(amount: int) -> void:##dodaj dmg z powerupu
	if amount <= 0:
		return

	var powerups: Dictionary = playthrough_data.get(
		"powerups",
		{}
	)

	powerups["damage_bonus"] = (
		get_playthrough_damage_bonus()
		+ amount
	)

	playthrough_data["powerups"] = powerups

	print(
		"Playthrough damage bonus: +",
		get_playthrough_damage_bonus()
	)


# ============================================================
# PROFILE - MAX HP UPGRADE
# ============================================================
func get_max_hp_level() -> int:##zwróć level ulepszenia hp
	return int(
		profile_data.get(
			"max_hp_level",
			0
		)
	)
func get_max_hp() -> int:##zwróć maksymalne hp po ulepszeniach
	return (
		BASE_MAX_HP
		+ get_max_hp_level() * MAX_HP_PER_LEVEL
	)


func get_max_hp_upgrade_cost() -> int:##sprawdź koszt następnego levelupu dla hp
	return MAX_HP_UPGRADE_BASE_COST * (
		get_max_hp_level() + 1
	)


func buy_max_hp_upgrade() -> bool:##kup nowy level ulepszenia hp
	var cost := get_max_hp_upgrade_cost()

	if not spend_coins(cost):
		print("Za mało monet na ulepszenie HP.")
		return false

	profile_data["max_hp_level"] = (
		get_max_hp_level() + 1
	)

	upgrades_changed.emit()

	print("Max HP level: ", get_max_hp_level())
	print("Max HP: ", get_max_hp())

	return true
# ============================================================
# CURRENT PLAYTHROUGH
# ============================================================

func start_new_playthrough() -> void:##restartuje aktualną rozgrywkę, ulepszenia i monety zostają

	playthrough_data = create_default_playthrough()

	playthrough_data["exists"] = true

	var player_data: Dictionary = playthrough_data["player"]

	player_data["hp"] = get_max_hp()

	playthrough_data["player"] = player_data

	active_scene_path = ""
	transition_player_state.clear()

	print(
		"Rozpoczęto nowy playthrough. Max HP: ",
		get_max_hp()
	)


func has_current_playthrough() -> bool:##sprawdza czy jest zapisana rogrywka
	return bool(
		playthrough_data.get(
			"exists",
			false
		)
	)


func get_playthrough_scene_path() -> String:##zwraca ścieżkę do sceny z playthrough_data
	return str(
		playthrough_data.get(
			"scene_path",
			""
		)
	)


# ============================================================
# AKTUALNY POZIOM
# ============================================================

func get_current_level_path() -> String:##zwraca ścieżkę do teraźniejszego poziomu
	if not active_scene_path.is_empty():
		return active_scene_path

	if get_tree().current_scene != null:
		return get_tree().current_scene.scene_file_path

	return ""


# ============================================================
# PRZECIWNICY
# ============================================================

func mark_enemy_defeated(enemy_id: String) -> void:##zapisz wrogów jako pokonanych 
	if enemy_id.is_empty():
		push_warning("Przeciwnik nie posiada save_id.")
		return

	var level_path := get_current_level_path()

	if level_path.is_empty():
		push_warning("Nie można określić poziomu przeciwnika.")
		return

	var world: Dictionary = playthrough_data.get(
		"world",
		{}
	)

	var defeated_enemies: Dictionary = world.get(
		"defeated_enemies",
		{}
	)

	var enemies: Array = defeated_enemies.get(
		level_path,
		[]
	)

	if not enemies.has(enemy_id):
		enemies.append(enemy_id)

	defeated_enemies[level_path] = enemies
	world["defeated_enemies"] = defeated_enemies
	playthrough_data["world"] = world

	print("Pokonano: ", enemy_id)


func is_enemy_defeated(enemy_id: String) -> bool:##sprawdź czy przeciwnik jest pokonany
	if enemy_id.is_empty():
		return false

	var level_path := get_current_level_path()

	if level_path.is_empty():
		return false

	var world: Dictionary = playthrough_data.get(
		"world",
		{}
	)

	var defeated_enemies: Dictionary = world.get(
		"defeated_enemies",
		{}
	)

	var enemies: Array = defeated_enemies.get(
		level_path,
		[]
	)

	return enemies.has(enemy_id)


# ============================================================
# PICKUPY / MONETY
# ============================================================

func mark_pickup_collected(pickup_id: String) -> void:##zapisz pickupy jako zebrane
	if pickup_id.is_empty():
		push_warning("Pickup nie posiada save_id.")
		return

	var level_path := get_current_level_path()

	if level_path.is_empty():
		push_warning("Nie można określić poziomu pickupu.")
		return

	var world: Dictionary = playthrough_data.get(
		"world",
		{}
	)

	var collected_pickups: Dictionary = world.get(
		"collected_pickups",
		{}
	)

	var pickups: Array = collected_pickups.get(
		level_path,
		[]
	)

	if not pickups.has(pickup_id):
		pickups.append(pickup_id)

	collected_pickups[level_path] = pickups
	world["collected_pickups"] = collected_pickups
	playthrough_data["world"] = world

	print("Zebrano pickup: ", pickup_id)


func is_pickup_collected(pickup_id: String) -> bool:##sprawdź czy pickup jest zebrany
	if pickup_id.is_empty():
		return false

	var level_path := get_current_level_path()

	if level_path.is_empty():
		return false

	var world: Dictionary = playthrough_data.get(
		"world",
		{}
	)

	var collected_pickups: Dictionary = world.get(
		"collected_pickups",
		{}
	)

	var pickups: Array = collected_pickups.get(
		level_path,
		[]
	)

	return pickups.has(pickup_id)


# ============================================================
# ZAPAMIĘTANIE CURRENT PLAYTHROUGH
# ============================================================

func capture_current_playthrough() -> bool:##zapisz teraźniejszą rozgrywkę
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		return false

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return false

	var weapon_path := ""

	if player.equipped_weapon != null:
		weapon_path = player.equipped_weapon.resource_path

	playthrough_data["exists"] = true
	playthrough_data["scene_path"] = current_scene.scene_file_path

	playthrough_data["player"] = {
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"hp": player.hp,
		"weapon_path": weapon_path
	}

	active_scene_path = current_scene.scene_file_path

	return true


# ============================================================
# WCZYTANIE GRACZA CURRENT PLAYTHROUGH
# ============================================================

func restore_current_playthrough_player() -> void:##wczytaj zapisaną rozgrywkę
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error("LOAD: Nie znaleziono Playera.")
		return

	var player_data: Dictionary = playthrough_data.get(
		"player",
		{}
	)

	var position_x := float(
		player_data.get(
			"position_x",
			player.global_position.x
		)
	)

	var position_y := float(
		player_data.get(
			"position_y",
			player.global_position.y
		)
	)

	player.global_position = Vector2(
		position_x,
		position_y
	)

	player.hp = int(
		player_data.get(
			"hp",
			player.hp
		)
	)

	var weapon_path: String = player_data.get(
		"weapon_path",
		""
	)

	if weapon_path.is_empty():
		player.equipped_weapon = null
	else:
		var weapon := load(weapon_path) as WeaponData

		if weapon != null:
			player.equip_weapon(weapon)
		else:
			push_error(
				"Nie udało się wczytać broni: "
				+ weapon_path
			)

	player.velocity = Vector2.ZERO


# ============================================================
# PRZEJŚCIE MIĘDZY POZIOMAMI
# ============================================================

func capture_player_transition_state() -> bool:##zapisz w jakim stanie jest postać gracza
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		return false

	var weapon_path := ""

	if player.equipped_weapon != null:
		weapon_path = player.equipped_weapon.resource_path

	transition_player_state = {
		"hp": player.hp,
		"weapon_path": weapon_path
	}

	return true


func restore_player_transition_state() -> void:##wczytaj zapisaną postać gracza 
	if transition_player_state.is_empty():
		return

	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error(
			"Nie znaleziono Playera po zmianie poziomu."
		)
		return

	player.hp = int(
		transition_player_state.get(
			"hp",
			player.hp
		)
	)

	var weapon_path: String = transition_player_state.get(
		"weapon_path",
		""
	)

	if weapon_path.is_empty():
		player.equipped_weapon = null
	else:
		var weapon := load(weapon_path) as WeaponData

		if weapon != null:
			player.equip_weapon(weapon)

	player.velocity = Vector2.ZERO

	transition_player_state.clear()


# ============================================================
# SAVE
# ============================================================

func save_all() -> void:##zapisz wszytkie informacje
	# Jeśli jesteśmy aktualnie w poziomie,
	# pobieramy najświeższy stan Playera.
	capture_current_playthrough()

	var directory_error := ensure_save_directory()

	if directory_error != OK:
		push_error(
			"Nie udało się utworzyć katalogu zapisów."
		)
		return

	var save_data := {
		"version": 2,
		"profile": profile_data,
		"current_playthrough": playthrough_data
	}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Nie udało się otworzyć savegame.json."
		)
		return

	file.store_string(
		JSON.stringify(
			save_data,
			"\t"
		)
	)

	file.flush()

	print("Gra zapisana.")
	print(
		ProjectSettings.globalize_path(SAVE_PATH)
	)


func ensure_save_directory() -> Error:##upewnij się że jest gdzie zapisać
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return OK

	return DirAccess.make_dir_recursive_absolute(
		SAVE_DIR
	)


# ============================================================
# LOAD Z DYSKU
# ============================================================

func load_from_disk() -> bool:##wczytaj z dysku
	if not has_save():
		print("Brak zapisu gry.")
		return false

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error("Nie udało się otworzyć zapisu.")
		return false

	var json := JSON.new()

	var parse_error := json.parse(
		file.get_as_text()
	)

	if parse_error != OK:
		push_error(
			"Uszkodzony zapis: "
			+ json.get_error_message()
		)

		return false

	var data = json.data

	if typeof(data) != TYPE_DICTIONARY:
		push_error("Nieprawidłowy format zapisu.")
		return false


	# ------------------------
	# PROFILE
	# ------------------------

	var loaded_profile: Dictionary = data.get(
		"profile",
		{}
	)

	profile_data = create_default_profile()
	profile_data.merge(
		loaded_profile,
		true
	)


	# ------------------------
	# CURRENT PLAYTHROUGH
	# ------------------------

	var loaded_playthrough: Dictionary = data.get(
		"current_playthrough",
		{}
	)

	playthrough_data = create_default_playthrough()

	playthrough_data["exists"] = bool(
		loaded_playthrough.get(
			"exists",
			false
		)
	)

	playthrough_data["scene_path"] = str(
		loaded_playthrough.get(
			"scene_path",
			""
		)
	)


	var default_player: Dictionary = (
		playthrough_data["player"]
	)

	var loaded_player: Dictionary = (
		loaded_playthrough.get(
			"player",
			{}
		)
	)

	default_player.merge(
		loaded_player,
		true
	)

	playthrough_data["player"] = default_player

	var default_powerups: Dictionary = (
		playthrough_data["powerups"]
	)

	default_powerups.merge(
		loaded_playthrough.get(
			"powerups",
			{}
		),
		true
	)

	playthrough_data["powerups"] = default_powerups


	var default_world: Dictionary = (
		playthrough_data["world"]
	)

	var loaded_world: Dictionary = (
		loaded_playthrough.get(
			"world",
			{}
		)
	)

	default_world.merge(
		loaded_world,
		true
	)

	playthrough_data["world"] = default_world


	active_scene_path = ""
	transition_player_state.clear()

	coins_changed.emit(get_coins())
	upgrades_changed.emit()

	print("Save wczytany do SaveManager.")

	return true


# ============================================================
# PLIK SAVE
# ============================================================

func has_save() -> bool:##sprawdź czy już jest zapis
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:##usuń zapis
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var error := DirAccess.remove_absolute(
		SAVE_PATH
	)

	if error != OK:
		push_error(
			"Nie udało się usunąć savegame.json."
		)
		return

	print("Stary zapis został usunięty.")
