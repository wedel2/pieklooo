extends Area2D

@export var speed: float = 700.0

var direction: int = 1
var damage: int = 5
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var is_flying: bool = true

func _ready() -> void:##zaczyna przy powołaniu obiektu do życia
	animated_sprite.play("fly")

func _physics_process(delta: float) -> void:
	if not is_flying:
		return

	global_position.x += speed * direction * delta

func setup(new_direction: int, new_damage: int) -> void:
	direction = new_direction
	damage = new_damage

	animated_sprite.flip_h = direction < 0



func _on_area_entered(area: Area2D) -> void:

	if not is_flying:
		return

	var enemy: Node = area

	while enemy != null:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
			hit_enemy()
			return
		enemy = enemy.get_parent()

	print("Nie znaleziono take_damage()")


func hit_enemy() -> void:##jak trafi to usuń strzałę
	is_flying = false
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:##poza ekranem usun strzałę
	queue_free()


func _on_body_entered(body: Node2D) -> void:##jak uderzy w teren 
	if not is_flying:
		return

	hit_terrain()


func hit_terrain() -> void:##jak uderzy w teren to puść animację uderzania w teren po czym usun strzałę
	is_flying = false

	collision_shape.set_deferred("disabled", true)

	animated_sprite.play("hit")

	await animated_sprite.animation_finished

	queue_free()
