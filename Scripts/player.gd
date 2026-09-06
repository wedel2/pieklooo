extends CharacterBody2D


const SPEED = 350.0
const JUMP_VELOCITY = -350.0
const BOW_SHOOT_FRAME := 9
signal hp_changed
signal coins_changed(new_amount: int)
@export var wait_time: float = 3.0 #czas wyświetlania zdechlaka
var is_dead: bool = false
var hp: int =100:
	set(value):
		hp=clamp(value, 0, get_max_hp())
		hp_changed.emit()
var coins: int = 0:
	set(value):
		coins = max(value, 0)
		coins_changed.emit(coins)
var facing_direction: int = 1

var equipped_weapon: WeaponData = null
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_attacking: bool = false
@onready var sword_hitbox: Area2D = $SwordHitbox
@export var sword_hitbox_offset: Vector2 = Vector2(32, -25)
@onready var sword_shape: CollisionShape2D = $SwordHitbox/CollisionShape2D
var sword_hit_enemies: Array[Node] = []
@onready var arrow_spawn_point: Marker2D = $ArrowSpawnPoint
@export var arrow_scene: PackedScene
@export var arrow_spawn_offset := Vector2(35, -27)
var arrow_shot_this_attack: bool = false

func _ready() -> void:
	sword_shape.disabled = true

	print("AnimatedSprite: ", animated_sprite)
	print("Path: ", animated_sprite.get_path())

	animated_sprite.frame_changed.connect(
		_on_animated_sprite_2d_frame_changed)
	
func _physics_process(delta: float) -> void:
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if is_dead:
		return
	# checks direction [-1,0,1] moves the player and changes animation accordingly
	var direction := Input.get_axis("move_left", "move_right")
	if not is_attacking:
	# Handle jump.
		if  Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
	
	
		#movement animation
		if is_on_floor():
			if direction == 0:
				play_animation("idle")
			else:
				play_animation("run")
		else:
			play_animation("jump")
		#character movement
		if direction:
			velocity.x = direction * SPEED
			update_facing(direction)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)


	if Input.is_action_just_pressed("attack"):
		attack()
	move_and_slide()
	
##Kierunek
func update_facing(direction: float) -> void:##obracanie gracza
	if direction > 0:
		facing_direction = 1
	elif direction < 0:
		facing_direction = -1
	else:
		return

	animated_sprite.flip_h = facing_direction < 0

	sword_hitbox.position = Vector2(
		sword_hitbox_offset.x * facing_direction,
		sword_hitbox_offset.y
	)
	arrow_spawn_point.position = Vector2(
		arrow_spawn_offset.x * facing_direction,
		arrow_spawn_offset.y
	)

func get_animation_name(base_animation: String) -> String:##zwraca odpowiednią nazwę animacji w zależności od broni gracza
	if equipped_weapon == null:
		return base_animation

	return base_animation + "_" + equipped_weapon.animation_suffix

func play_animation(animation_name: String) -> void:##Odtwórz animację
	var final_animation := get_animation_name(animation_name)

	if animated_sprite.animation != final_animation:
		animated_sprite.play(final_animation)

func get_max_hp() -> int:##Do ulepszeń MaxHP
	return SaveManager.get_max_hp()

func take_damage(damage: int) -> void:##Dostań obrażenia
	hp -= damage

	print("Player HP: ", hp)


func _on_hp_changed() -> void:##Przy zmianie HP sprawdź czy żyje
	if is_dead:
		return
	if hp==0:
		is_dead=true
		animated_sprite.play("die")
		await animated_sprite.animation_finished
		await get_tree().create_timer(wait_time).timeout
		get_tree().reload_current_scene()

func add_coins(amount: int) -> void:##Dodaj monety
	coins += amount

	print("Coins: ", coins)


func equip_weapon(weapon: WeaponData) -> void:##Załóż broń
	equipped_weapon = weapon


func attack() -> void:##Atak ogólny przechodzi na atak dla wybranej broni
	if equipped_weapon == null:
		return
	if is_attacking:
		return
	match equipped_weapon.weapon_type:
		WeaponData.WeaponType.SWORD:
			
			attack_sword()

		WeaponData.WeaponType.BOW:
			velocity.x =0
			attack_bow()

func get_attack_damage() -> int:##zyskaj Atack damage razem z obrażeniami broni, ulepszeniami i powerupami
	if equipped_weapon == null:
		return 0

	return (
		equipped_weapon.damage
		+ SaveManager.get_damage_bonus()
		+ SaveManager.get_playthrough_damage_bonus()
	)


func attack_bow() -> void:##atak łukiem
	if equipped_weapon == null:
		return

	if is_attacking:
		return

	is_attacking = true
	arrow_shot_this_attack = false
	play_animation("attack")

	await animated_sprite.animation_finished

	is_attacking = false


func attack_sword() -> void:##Atak mieczem 
	if equipped_weapon == null:
		return

	if is_attacking:
		return

	is_attacking = true
	sword_hit_enemies.clear()

	sword_shape.set_deferred("disabled", true)

	play_animation("attack")


	await animated_sprite.animation_finished

	sword_shape.set_deferred("disabled", true)
	is_attacking = false



func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	if not is_attacking:
		return

	if equipped_weapon == null:
		return

	var enemy: Node = area

	while enemy != null and not enemy.has_method("take_damage"):
		enemy = enemy.get_parent()

	if enemy == null:
		print("Nie znaleziono obiektu z take_damage()")
		return

	if enemy in sword_hit_enemies:
		return

	sword_hit_enemies.append(enemy)

	print("HIT ENEMY: ", enemy.name)
	print("DAMAGE: ", equipped_weapon.damage)

	enemy.take_damage(get_attack_damage())





func _on_animated_sprite_2d_frame_changed() -> void:
	if equipped_weapon == null:
		return
	match equipped_weapon.weapon_type:

		WeaponData.WeaponType.SWORD:
			handle_sword_attack_frame()

		WeaponData.WeaponType.BOW:
			handle_bow_attack_frame()

	
func handle_sword_attack_frame() -> void:##zadaj dmg w odpowiedniej klatce animacji
	if animated_sprite.animation != "attack_sword":
		return

	if animated_sprite.frame in [4, 5, 6]:
		sword_shape.set_deferred("disabled", false)
	else:
		sword_shape.set_deferred("disabled", true)
		
		
		
func handle_bow_attack_frame() -> void:##stwórz strzałę w odpowiedniej klatce animacji
	if animated_sprite.animation != get_animation_name("attack"):
		return

	if animated_sprite.frame == 9 and not arrow_shot_this_attack:
		arrow_shot_this_attack = true
		shoot_arrow()
		
func shoot_arrow() -> void:##stwórz strzałę
	if arrow_scene == null:
		print("ERROR: Arrow Scene is null")
		return

	if equipped_weapon == null:
		return

	var arrow = arrow_scene.instantiate()

	get_tree().current_scene.add_child(arrow)

	arrow.global_position = arrow_spawn_point.global_position

	arrow.setup(
		facing_direction,
		get_attack_damage()
	)

	print("ARROW FIRED")
