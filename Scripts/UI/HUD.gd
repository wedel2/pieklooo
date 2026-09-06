extends CanvasLayer

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var coin_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/CoinLabel

var player: CharacterBody2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group(
		"player"
	) as CharacterBody2D

	if player == null:
		push_error(
			"UserInterface: Nie znaleziono Playera."
		)
		return


	if not player.hp_changed.is_connected(
		_on_player_hp_changed
	):
		player.hp_changed.connect(
			_on_player_hp_changed
		)


	if not SaveManager.coins_changed.is_connected(
		_on_coins_changed
	):
		SaveManager.coins_changed.connect(
			_on_coins_changed
		)


	update_hp()
	update_coins()



func update_hp() -> void:##zmienia hp gracza i poprawia pasek hp
	if player == null:
		return

	progress_bar.max_value = SaveManager.get_max_hp()
	progress_bar.value = player.hp


func update_coins() -> void:##zmienia ilość monet gracza
	coin_label.text = ("× "+ str(SaveManager.get_coins()))


func _on_player_hp_changed() -> void:
	update_hp()


func _on_coins_changed(_new_amount: int) -> void:
	update_coins()
