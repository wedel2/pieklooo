extends Area2D


@export var damage_bonus: int = 5

@export var save_id: String = ""

@export var animation_name: StringName = &"idle"


@onready var animated_sprite: AnimatedSprite2D = (
	$AnimatedSprite2D
)


var collected: bool = false


func _ready() -> void:
	if save_id.is_empty():
		push_warning(
			"DamagePowerup nie posiada save_id: "
			+ str(get_path())
		)

	if SaveManager.is_pickup_collected(save_id):
		queue_free()
		return

	if animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		animated_sprite.play(
			animation_name
		)


func _on_body_entered(body: Node2D) -> void:##po zebraniu dodaj dmg do dmg gracza i usun powerup
	if collected:
		return

	if not body.is_in_group("player"):
		return


	collected = true


	SaveManager.add_playthrough_damage_bonus(
		damage_bonus
	)


	SaveManager.mark_pickup_collected(
		save_id
	)


	print(
		"Damage Powerup collected! +",
		damage_bonus,
		" DMG"
	)


	queue_free()
