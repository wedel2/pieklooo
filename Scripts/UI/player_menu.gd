extends Control


@onready var coins_label: Label = (
	$CenterContainer/VBoxContainer/CoinsLabel
)

@onready var damage_label: Label = (
	$CenterContainer/VBoxContainer/DamageLabel
)

@onready var play_button: Button = (
	$CenterContainer/VBoxContainer/Play
)

@onready var upgrade_button: Button = (
	$CenterContainer/VBoxContainer/UpgradeDamage
)

@onready var load_current_button: Button = (
	$CenterContainer/VBoxContainer/LoadCurrentPlaythru
)

@onready var save_button: Button = (
	$CenterContainer/VBoxContainer/Save
)

@onready var main_menu_button: Button = (
	$CenterContainer/VBoxContainer/MainMenu
)
@onready var max_hp_label: Label = (
	$CenterContainer/VBoxContainer/MaxHPLabel
)

@onready var upgrade_max_hp_button: Button = (
	$CenterContainer/VBoxContainer/UpgradeMaxHP
)

func _ready() -> void:
	print("PLAYER MENU READY")

	# PRZYCISKI

	if not play_button.pressed.is_connected(
		_on_play_button_pressed
	):
		play_button.pressed.connect(
			_on_play_button_pressed
		)

	if not upgrade_button.pressed.is_connected(
		_on_upgrade_damage_button_pressed
	):
		upgrade_button.pressed.connect(
			_on_upgrade_damage_button_pressed
		)

	if not load_current_button.pressed.is_connected(
		_on_load_current_button_pressed
	):
		load_current_button.pressed.connect(
			_on_load_current_button_pressed
		)

	if not save_button.pressed.is_connected(
		_on_save_button_pressed
	):
		save_button.pressed.connect(
			_on_save_button_pressed
		)

	if not main_menu_button.pressed.is_connected(
		_on_main_menu_button_pressed
	):
		main_menu_button.pressed.connect(
			_on_main_menu_button_pressed
		)
	if not upgrade_max_hp_button.pressed.is_connected(
		_on_upgrade_max_hp_button_pressed
	):
		upgrade_max_hp_button.pressed.connect(
			_on_upgrade_max_hp_button_pressed
		)

	# SAVE MANAGER SIGNALS

	if not SaveManager.coins_changed.is_connected(
		_on_coins_changed
	):
		SaveManager.coins_changed.connect(
			_on_coins_changed
		)

	if not SaveManager.upgrades_changed.is_connected(
		_on_upgrades_changed
	):
		SaveManager.upgrades_changed.connect(
			_on_upgrades_changed
		)

	refresh()


func refresh() -> void:##odśwież
	var coins := SaveManager.get_coins()

	var damage_level := SaveManager.get_damage_level()

	var damage_bonus := SaveManager.get_damage_bonus()

	var upgrade_cost := SaveManager.get_damage_upgrade_cost()
	var max_hp_level := SaveManager.get_max_hp_level()

	var max_hp := SaveManager.get_max_hp()

	var max_hp_upgrade_cost := (
		SaveManager.get_max_hp_upgrade_cost()
	)
	max_hp_label.text = (
	"Max HP level: "
	+ str(max_hp_level)
	+ "  ("
	+ str(max_hp)
	+ " HP)"
	)
	coins_label.text = (
		"Coins: "
		+ str(coins)
	)

	damage_label.text = (
		"Damage level: "
		+ str(damage_level)
		+ " (+"
		+ str(damage_bonus)
		+ " DMG)"
	)

	upgrade_button.text = (
		"Upgrade Damage - "
		+ str(upgrade_cost)
		+ " coins"
	)

	upgrade_button.disabled = (
		coins < upgrade_cost
	)
	upgrade_max_hp_button.text = (
	"Upgrade Max HP - "
	+ str(max_hp_upgrade_cost)
	+ " coins"
	)

	upgrade_max_hp_button.disabled = (
	coins < max_hp_upgrade_cost
	)
	load_current_button.disabled = (
		not SaveManager.has_current_playthrough()
	)


func _on_play_button_pressed() -> void:
	print("PLAY BUTTON PRESSED")

	GameManager.start_play()


func _on_upgrade_damage_button_pressed() -> void:
	print("UPGRADE BUTTON PRESSED")

	SaveManager.buy_damage_upgrade()

	refresh()


func _on_load_current_button_pressed() -> void:
	print("LOAD CURRENT BUTTON PRESSED")

	GameManager.load_current_playthrough()


func _on_save_button_pressed() -> void:
	print("SAVE BUTTON PRESSED")

	GameManager.save_game()


func _on_main_menu_button_pressed() -> void:
	print("MAIN MENU BUTTON PRESSED")

	GameManager.go_to_main_menu()


func _on_coins_changed(
	_new_amount: int
) -> void:
	refresh()


func _on_upgrades_changed() -> void:
	refresh()
func _on_upgrade_max_hp_button_pressed() -> void:
	print("MAX HP UPGRADE BUTTON PRESSED")

	SaveManager.buy_max_hp_upgrade()

	refresh()
