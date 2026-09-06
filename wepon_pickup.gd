extends Area2D


@export var weapon: WeaponData


@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_label: Label = $InteractionLabel


var player: CharacterBody2D = null


func _ready() -> void:
	interaction_label.visible = false

	if weapon != null:
		sprite.texture = weapon.pickup_texture

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player == null:
		return

	if Input.is_action_just_pressed("interact"):
		pick_up_weapon()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		interaction_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		interaction_label.visible = false


func pick_up_weapon() -> void:##dodaj broń dla gracza po interakcji z obiektem
	if weapon == null:
		return

	if player == null:
		return

	player.equip_weapon(weapon)

	#queue_free()
