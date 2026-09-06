extends Node2D


@export var save_id: String = ""

@export var max_hp: int = 25

@export var attack_damage: int = 10

@export var shoot_frame: int = 5

@export var shoot_cooldown: float = 2.0

@export var arrow_scene: PackedScene

@export var arrow_spawn_offset: Vector2 = Vector2(
	25,
	-15
)


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var player_detector: Area2D = $PlayerDetector
@onready var body_collision: CollisionShape2D = (
	$Body/CollisionShape2D
)
@onready var hurtbox: Area2D = $hitBox

@onready var hurtbox_collision: CollisionShape2D = (
	$hitBox/CollisionShape2D
)

@onready var arrow_spawn_point: Marker2D = (
	$ArrowSpawnPoint
)

@onready var shoot_timer: Timer = $ShootTimer


var hp: int

var player: Node2D = null

var facing_direction: int = 1


var is_dead: bool = false

var is_hurt: bool = false

var is_attacking: bool = false


var arrow_shot_this_attack: bool = false


var attack_generation: int = 0
var hurt_generation: int = 0


func _ready() -> void:##funkcja przy powołaniu obiektu do życia
	hp = max_hp

	shoot_timer.wait_time = shoot_cooldown
	shoot_timer.one_shot = false

	if not shoot_timer.timeout.is_connected(
		_on_shoot_timer_timeout
	):
		shoot_timer.timeout.connect(
			_on_shoot_timer_timeout
		)

	if not sprite.frame_changed.is_connected(
		_on_sprite_frame_changed
	):
		sprite.frame_changed.connect(
			_on_sprite_frame_changed
		)

	if SaveManager.is_enemy_defeated(save_id):
		restore_dead_state()
		return

	sprite.play("Archer_idle")

func _on_player_detector_body_entered(body: Node2D) -> void:##namierzanie gracza
	if not body.is_in_group("player"):
		return

	if is_dead:
		return

	player = body

	update_facing()

	print("PLAYER ENTERED ARCHER RANGE")

	try_attack()

	shoot_timer.start()


func _on_player_detector_body_exited(body: Node2D) -> void:##koniec namierzania gracza
	if body != player:
		return

	print("PLAYER LEFT ARCHER RANGE")

	player = null

	shoot_timer.stop()

	if not is_dead and not is_hurt and not is_attacking:
		sprite.play("archer_idle")


func _on_shoot_timer_timeout() -> void:##timer między atakami
	try_attack()


func update_facing() -> void:##obracanie w stronę gracza
	if player == null:
		return

	if player.global_position.x > global_position.x:
		facing_direction = 1

	elif player.global_position.x < global_position.x:
		facing_direction = -1


	sprite.flip_h = facing_direction < 0


	arrow_spawn_point.position = Vector2(
		arrow_spawn_offset.x * facing_direction,
		arrow_spawn_offset.y
	)

func _process(_delta: float) -> void:
	if is_dead:
		return

	if player == null:
		return

	if not is_attacking:
		update_facing()



func try_attack() -> void:##próba wykonania ataku
	if is_dead:
		return

	if is_hurt:
		return

	if is_attacking:
		return

	if player == null:
		return

	if not is_instance_valid(player):
		player = null
		return


	update_facing()


	is_attacking = true

	arrow_shot_this_attack = false


	attack_generation += 1

	var this_attack := attack_generation


	sprite.play("Archer_attack")


	await sprite.animation_finished


	# Atak został przerwany np. przez otrzymanie damage.
	if this_attack != attack_generation:
		return


	if is_dead or is_hurt:
		return


	is_attacking = false

	arrow_shot_this_attack = false


	if player != null and is_instance_valid(player):
		update_facing()

		sprite.play("Archer_idle")
	else:
		player = null

		sprite.play("Archer_idle")


func _on_sprite_frame_changed() -> void:##sprawdza kiedy archer moze wypuscic strzale
	if is_dead:
		return

	if is_hurt:
		return

	if not is_attacking:
		return

	if sprite.animation != "Archer_attack":
		return

	if sprite.frame != shoot_frame:
		return

	if arrow_shot_this_attack:
		return


	arrow_shot_this_attack = true

	shoot_arrow()


func shoot_arrow() -> void:##tworzy obiekt enemy arrow
	if arrow_scene == null:
		push_error("Archer: arrow_scene == null")
		return

	if player == null:
		return

	if not is_instance_valid(player):
		player = null
		return

	var arrow = arrow_scene.instantiate()

	get_tree().current_scene.add_child(arrow)

	arrow.global_position = (
		arrow_spawn_point.global_position
	)

	var target_point := player.get_node_or_null(
		"TargetPoint"
	) as Marker2D

	var target_position := player.global_position

	if target_point != null:
		target_position = target_point.global_position

	var shoot_direction := (
		target_position
		- arrow_spawn_point.global_position
	).normalized()

	arrow.setup(
		shoot_direction,
		attack_damage
	)
	
func take_damage(damage: int) -> void:##przyjmowanie obrażeń
	if is_dead:
		return


	hp = max(
		hp - damage,
		0
	)


	print(
		"Archer HP: ",
		hp
	)


	if hp <= 0:
		die()
		return


	# Przerwij aktualny strzał.
	attack_generation += 1

	is_attacking = false

	arrow_shot_this_attack = false


	is_hurt = true


	hurt_generation += 1

	var this_hurt := hurt_generation


	sprite.stop()


	if this_hurt != hurt_generation:
		return


	if is_dead:
		return


	is_hurt = false


	if player != null and is_instance_valid(player):
		update_facing()


	sprite.play("Archer_idle")



func die() -> void:##umieranko
	if is_dead:
		return


	is_dead = true

	hp = 0


	SaveManager.mark_enemy_defeated(
		save_id
	)


	attack_generation += 1

	hurt_generation += 1


	is_attacking = false

	is_hurt = false

	arrow_shot_this_attack = false


	player = null


	shoot_timer.stop()


	disable_collisions()
	

	sprite.play("Archer_dead")


	await sprite.animation_finished
	
func disable_collisions() -> void:##usuwa kolizje z graczem po smierci
	# Archer przestaje wykrywać Playera
	player_detector.set_deferred(
		"monitoring",
		false
	)

	# Nie można już trafić martwego Archera
	hurtbox.set_deferred(
		"monitoring",
		false
	)

	hurtbox.set_deferred(
		"monitorable",
		false
	)

	hurtbox_collision.set_deferred(
		"disabled",
		true
	)

	# Player może przejść przez zwłoki
	body_collision.set_deferred(
		"disabled",
		true
	)

func restore_dead_state() -> void:##jeśli był zabity to przy wczytaniu wróć do bycia martwym
	is_dead = true

	is_hurt = false

	is_attacking = false

	hp = 0


	player = null


	shoot_timer.stop()


	disable_collisions()


	sprite.stop()

	sprite.animation = "Archer_dead"


	var frame_count := (
		sprite.sprite_frames.get_frame_count(
			"Archer_dead"
		)
	)


	if frame_count > 0:
		sprite.frame = frame_count - 1
