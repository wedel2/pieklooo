extends CharacterBody2D


@export var save_id: String = ""

@export var max_hp: int = 15
@export var speed: float = 180.0
@export var contact_damage: int = 25


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var body_collision: CollisionShape2D = (
	$CollisionShape2D
)

@onready var player_detector: Area2D = (
	$PlayerDetector
)

@onready var player_detector_collision: CollisionShape2D = (
	$PlayerDetector/CollisionShape2D
)

@onready var damage_area: Area2D = (
	$DamageArea
)

@onready var damage_collision: CollisionShape2D = (
	$DamageArea/CollisionShape2D
)

@onready var hurtbox: Area2D = (
	$hitBox
)

@onready var hurtbox_collision: CollisionShape2D = (
	$hitBox/CollisionShape2D
)


var hp: int

var player: Node2D = null

var facing_direction: int = 1

var is_dead: bool = false
var is_hurt: bool = false

var has_exploded: bool = false

var hurt_generation: int = 0


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	hp = max_hp

	# Podłączamy sygnały z kodu, żeby uniknąć problemów
	# z brakującymi połączeniami w edytorze.

	if not player_detector.body_entered.is_connected(
		_on_player_detector_body_entered
	):
		player_detector.body_entered.connect(
			_on_player_detector_body_entered
		)


	if not player_detector.body_exited.is_connected(
		_on_player_detector_body_exited
	):
		player_detector.body_exited.connect(
			_on_player_detector_body_exited
		)


	if not damage_area.body_entered.is_connected(
		_on_damage_area_body_entered
	):
		damage_area.body_entered.connect(
			_on_damage_area_body_entered
		)


	# Jeśli Imp został już zabity w obecnym playthrough,
	# nie pojawia się ponownie.
	if SaveManager.is_enemy_defeated(save_id):
		queue_free()
		return


	sprite.play("imp_idle")


# ============================================================
# RUCH
# ============================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return


	# GRAWITACJA
	if not is_on_floor():
		velocity += get_gravity() * delta


	# IMP OTRZYMUJE OBRAŻENIA
	if is_hurt:
		velocity.x = 0

		move_and_slide()

		check_player_collision()

		return


	# BRAK PLAYERA W DETEKTORZE
	if player == null:
		velocity.x = 0

		if is_on_floor():
			if sprite.animation != "imp_idle":
				sprite.play("imp_idle")

		move_and_slide()

		return


	# PLAYER JUŻ NIE ISTNIEJE
	if not is_instance_valid(player):
		player = null

		velocity.x = 0

		move_and_slide()

		return


	# ========================================================
	# SZARŻA NA PLAYERA
	# ========================================================

	update_facing()


	velocity.x = facing_direction * speed


	if sprite.animation != "imp_walk":
		sprite.play("imp_walk")


	move_and_slide()


	# Dodatkowe zabezpieczenie.
	# Jeśli DamageArea nachodzi na Playera, Imp eksploduje.
	check_player_collision()


# ============================================================
# PLAYER DETECTOR
# ============================================================

func _on_player_detector_body_entered(
	body: Node2D
) -> void:##namierzanie gracza

	if is_dead:
		return

	if not body.is_in_group("player"):
		return


	player = body


	update_facing()


func _on_player_detector_body_exited(
	body: Node2D
) -> void:##koniec namierzania gracza

	if body != player:
		return


	player = null

	velocity.x = 0


	if not is_dead and not is_hurt:
		sprite.play("imp_idle")


# ============================================================
# OBRACANIE W STRONĘ PLAYERA
# ============================================================

func update_facing() -> void:##obracanie impa
	if player == null:
		return

	if not is_instance_valid(player):
		return


	if player.global_position.x > global_position.x:
		facing_direction = 1

	elif player.global_position.x < global_position.x:
		facing_direction = -1


	sprite.flip_h = facing_direction < 0


# ============================================================
# DAMAGE AREA
# ============================================================

func _on_damage_area_body_entered(
	body: Node2D
) -> void:##sprawdz czy gracz jest w zasięgu eksplozji

	if not body.is_in_group("player"):
		return


	explode_on_player(body)


# ============================================================
# DODATKOWE SPRAWDZANIE DAMAGE AREA
# ============================================================

func check_player_collision() -> void:##sprawdza czy może wybuchnąć na graczu
	if is_dead:
		return

	if has_exploded:
		return


	for detected_body in damage_area.get_overlapping_bodies():

		if detected_body.is_in_group("player"):
			explode_on_player(detected_body)
			return


# ============================================================
# EKSPLOZJA NA PLAYERZE
# ============================================================

func explode_on_player(
	body: Node2D
) -> void:##wybuchnij

	if is_dead:
		return

	if has_exploded:
		return

	if not body.is_in_group("player"):
		return


	has_exploded = true


	velocity = Vector2.ZERO


	print("IMP KAMIKAZE EXPLODES")


	if body.has_method("take_damage"):
		body.take_damage(
			contact_damage
		)


	die()


# ============================================================
# OTRZYMYWANIE OBRAŻEŃ
# ============================================================

func take_damage(
	damage: int
) -> void:##otrzymanie obrażeń

	if is_dead:
		return

	if has_exploded:
		return


	hp = max(
		hp - damage,
		0
	)


	print(
		"Imp Kamikaze HP: ",
		hp
	)


	if hp <= 0:
		die()
		return


	# ========================================================
	# HURT
	# ========================================================

	is_hurt = true

	hurt_generation += 1

	var this_hurt := hurt_generation


	velocity.x = 0


	sprite.stop()

	sprite.play("imp_hurt")


	await sprite.animation_finished


	# Inna animacja hurt została uruchomiona
	# albo Imp zdążył umrzeć.
	if this_hurt != hurt_generation:
		return

	if is_dead:
		return


	is_hurt = false


	if player != null and is_instance_valid(player):

		update_facing()

		sprite.play("imp_walk")

	else:

		sprite.play("imp_idle")


# ============================================================
# ŚMIERĆ
# ============================================================

func die() -> void:##umieranko
	if is_dead:
		return

	is_dead = true
	hp = 0
	velocity = Vector2.ZERO

	hurt_generation += 1

	SaveManager.mark_enemy_defeated(save_id)

	player = null

	disable_collisions()

	print("IMP DIE")
	print("Animations: ", sprite.sprite_frames.get_animation_names())
	print("Has imp_dead: ", sprite.sprite_frames.has_animation("imp_dead"))

	if not sprite.sprite_frames.has_animation("imp_dead"):
		push_error("ImpKamikaze: brak animacji imp_dead")
		queue_free()
		return

	sprite.stop()

	sprite.play("imp_dead")

	print("Current animation: ", sprite.animation)
	print("Is playing: ", sprite.is_playing())

	await sprite.animation_finished

	print("IMP DEAD ANIMATION FINISHED")

	queue_free()

# ============================================================
# WYŁĄCZENIE KOLIZJI
# ============================================================

func disable_collisions() -> void:##usuń kolizje po śnierci

	# Główna kolizja fizyczna
	body_collision.set_deferred(
		"disabled",
		true
	)


	# Player Detector
	player_detector.set_deferred(
		"monitoring",
		false
	)

	player_detector_collision.set_deferred(
		"disabled",
		true
	)


	# Damage Area
	damage_area.set_deferred(
		"monitoring",
		false
	)

	damage_collision.set_deferred(
		"disabled",
		true
	)


	# Hurtbox
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
