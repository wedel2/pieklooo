extends Area2D


@export var speed: float = 500.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


var direction: Vector2 = Vector2.RIGHT
var damage: int = 10

var is_flying: bool = true


func _ready() -> void:
	if animated_sprite.sprite_frames.has_animation("fly"):
		animated_sprite.play("fly")


func setup(
	new_direction: Vector2,
	new_damage: int
) -> void:##upewnia sie że strzała leci w dobrym kierunku

	direction = new_direction.normalized()
	damage = new_damage

	# Obróć cały pocisk w kierunku lotu.
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if not is_flying:
		return

	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if not is_flying:
		return

	# TRAFIENIE PLAYERA
	if body.is_in_group("player"):

		if body.has_method("take_damage"):
			body.take_damage(damage)

		hit_target()
		return


	# Wszystko inne traktujemy jako teren.
	hit_terrain()


func hit_target() -> void:##jak strzała uderza w gracza to zadaj dmg i ją usuń
	if not is_flying:
		return

	is_flying = false

	collision_shape.set_deferred(
		"disabled",
		true
	)

	queue_free()


func hit_terrain() -> void:##jak strzała uderzy w teren to ją usuń po animacji uderzania w teren
	if not is_flying:
		return

	is_flying = false

	collision_shape.set_deferred(
		"disabled",
		true
	)

	if animated_sprite.sprite_frames.has_animation("hit"):

		animated_sprite.play("hit")

		await animated_sprite.animation_finished

	queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
