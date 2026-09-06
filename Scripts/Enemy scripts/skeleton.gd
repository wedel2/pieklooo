class_name Skeleton
extends Node2D
##Klasa skeleton
##
##Przeciwnik patrolujący teren i zadający obrażenia na krótkim dystansie

@export var save_id: String = ""##zmienna do zapisu pokonanych przeciwników
@export var speed: float = 75.0 ##szybkosc szkieletu
@export var patrol_distance: float = 250.0 ##odleglosc jaka patroluje szkielet w obie strony od pkt spawnu
@export var max_hp: int = 30 ##maksymalne pkt życia szkieletu
@export var floor_ray_offset: float = 20.0 ##odleglosc od srodka body przewidujace krawedz platformy
@export var wait_time: float = 3.0 ##czas na idle na krawedzi patrolu
@export var player_detector_offset: float = 10.0##przesunięcie wykrycia gracza
@export var hit_detector_offset: float = 10.0##przesunięcie obszaru w którym szkielet zadaje dmg przy ataku 
@export var attack_damage: int = 15##obrażenia jakie zadaje szkielet
@export var attack_hit_frames: Array[int] = [9, 10, 11]##klatki animacji ataku w których gracz może dostać dmg
var is_waiting: bool = false##czy czeka na końcu patrolowanego obszaru
var hp: int##aktualne punkty życia szkieletu
var direction: int = 1##kierunek ruchu
var start_x: float ##startowa wspolzedna
var is_dead: bool = false##czy jest martwy
var player_in_attack_range: bool = false##czy gracz jest w zasięgu ataku
var is_attacking: bool = false##czy właśnie atakuje
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")##grawitacja
var attack_has_hit: bool = false##czy atak trafił
@onready var body: CharacterBody2D = $CharacterBody2D
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
@onready var floor_ray: RayCast2D = $CharacterBody2D/FloorRay
@onready var player_detector: Area2D = $CharacterBody2D/PlayerDetector
@onready var hit_detector: Area2D = $CharacterBody2D/HitDetector
var is_hurt: bool = false##czy właśnie dostał obrażenia

var attack_generation: int = 0##pole pomocnicze do powrotu do ataku
var hurt_generation: int = 0##pole pomocnicze do powrotu do poprzedniej czynności po otrzymaniu dmg
var wait_generation: int = 0##pole pomocnicze do powrotu do czekania na końcu patrolu

##funkcja nadaje wartość hp, zapisuje pozycję poziomą na której szkielet zaczyna, podłącza sygnał zmienianej klatki, oraz sprawdza czy nie był wcześniej pokonany przy wczytaniu
func _ready() -> void:
	hp = max_hp

	start_x = body.global_position.x

	sprite.frame_changed.connect(
		_on_sprite_frame_changed
	)

	change_direction(direction)

	if SaveManager.is_enemy_defeated(save_id):
		restore_dead_state()
		return

	sprite.play("skeleton_walk")


func restore_dead_state() -> void:##funkcja przywraca szkielet do stanu pokonanego
	is_dead = true
	is_attacking = false
	is_hurt = false
	is_waiting = false
	attack_has_hit = false

	hp = 0

	body.velocity = Vector2.ZERO

	player_detector.set_deferred(
		"monitoring",
		false
	)

	hit_detector.set_deferred(
		"monitoring",
		false
	)

	
	var body_collision: CollisionShape2D = $CharacterBody2D/Skeletal_body# Wyłączenie kolizji
	body_collision.set_deferred("disabled", true)
	# Wyłącz detektory
	player_detector.set_deferred("monitoring", false)
	hit_detector.set_deferred("monitoring", false)
	# Wyłącz kolizje Area2D
	var hit_collision: CollisionShape2D = $CharacterBody2D/HitDetector/CollisionShape2D
	hit_collision.set_deferred("disabled", true)

	sprite.stop()

	sprite.animation = "skeleton_dead"

	var last_frame := (
		sprite.sprite_frames.get_frame_count(
			"skeleton_dead"
		) - 1
	)

	sprite.frame = last_frame

func _physics_process(delta: float) -> void:##Procesy fizyczne dla szkieletu
	if is_dead:
		return

	# GRAWITACJA
	if not body.is_on_floor():
		body.velocity.y += gravity * delta
	# HURT
	if is_hurt:
		body.velocity.x = 0
		body.move_and_slide()
		return

	
	if is_attacking:
		body.velocity.x = 0
		body.move_and_slide()
		return
	# CZEKANIE NA KOŃCU PATROLU
	if is_waiting:
		body.velocity.x = 0
		body.move_and_slide()
		return
	# RUCH
	body.velocity.x = direction * speed#gdy skonczy czekac

	# GRANICE PATROLU
	# Prawa granica - sprawdzaj tylko gdy idziemy w prawo
	if direction > 0 and body.global_position.x >= start_x + patrol_distance:
		stop_and_turn()
		return

	# Lewa granica - sprawdzaj tylko gdy idziemy w lewo
	elif direction < 0 and body.global_position.x <= start_x - patrol_distance:
		stop_and_turn()
		return


	# KRAWĘDŹ PLATFORMY
	floor_ray.position.x = floor_ray_offset * direction
	# Jeżeli nie ma podłogi przed szkieletem -> zawróć
	if body.is_on_floor() and not floor_ray.is_colliding():
		stop_and_turn()

	# RUCH FIZYCZNY
	body.move_and_slide()


	# ŚCIANA
	if body.is_on_wall():
		change_direction(-direction)
		

func change_direction(new_direction: int) -> void:##zmiana kierunku szkieleta i wszystkich jego podzespołów
	direction = new_direction

	sprite.flip_h = direction < 0
	#zmiana kierunku zeby nie rotowal caly czas gdy dojdzie do krawedzi
	floor_ray.position.x = floor_ray_offset * direction
	floor_ray.force_raycast_update()
	player_detector.position.x = player_detector_offset * direction
	hit_detector.position.x = hit_detector_offset * direction
	

func stop_and_turn() -> void:##funkcja do czekania na końcu patrolowanego obszaru
	if is_waiting:
		return
	if is_dead or is_hurt or is_attacking:
		return
	
	is_waiting = true
	# Zatrzymaj szkielet
	body.velocity.x = 0

	# Animacja bezczynności
	sprite.play("skeleton_idle")
	wait_generation += 1
	var this_wait := wait_generation
	# Czekaj wait_time
	await get_tree().create_timer(wait_time).timeout
	# W międzyczasie stan został zmieniony
	if this_wait != wait_generation:
		return
	if is_dead or is_hurt or is_attacking:
		return
	change_direction(-direction)

	is_waiting = false
	sprite.play("skeleton_walk")


func cancel_wait() -> void:##funkcja pomocnicza do stop_and_turn()
	is_waiting = false
	wait_generation += 1



func take_damage(amount: int) -> void:##otrzymywanie obrażeń
	if is_dead:
		return

	hp = max(hp - amount, 0)

	print("Skeleton otrzymane obrażenia: ", amount)
	print("Skeleton HP: ", hp)

	if hp <= 0:
		die()
		return

	# Przerwij wcześniejsze zachowania
	attack_generation += 1
	is_attacking = false
	attack_has_hit = false

	cancel_wait()

	is_hurt = true

	hurt_generation += 1
	var this_hurt := hurt_generation

	body.velocity.x = 0

	# Restart animacji hurt także przy kolejnym trafieniu
	sprite.stop()
	sprite.play("skeleton_hurt")

	await sprite.animation_finished

	# Jeśli w międzyczasie dostał kolejny cios,
	# ta stara funkcja nie może niczego zmieniać.
	if this_hurt != hurt_generation:
		return

	if is_dead:
		return

	is_hurt = false

	resume_behavior()


func resume_behavior() -> void:##po otrzymanych obrażeniach wróć do poprzedniej czynności
	if is_dead or is_hurt:
		return

	if is_player_in_detector():
		attack()
	else:
		sprite.play("skeleton_walk")


func die() -> void:##umieranko
	if is_dead:
		return
	SaveManager.mark_enemy_defeated(save_id)
	is_dead = true

	attack_generation += 1
	hurt_generation += 1
	wait_generation += 1

	is_attacking = false
	is_hurt = false
	is_waiting = false
	attack_has_hit = false

	body.velocity = Vector2.ZERO

	player_detector.set_deferred("monitoring", false)
	hit_detector.set_deferred("monitoring", false)
	# Wyłączenie kolizji
	var body_collision: CollisionShape2D = $CharacterBody2D/Skeletal_body
	body_collision.set_deferred("disabled", true)
	sprite.play("skeleton_dead")
	# Wyłącz detektory
	player_detector.set_deferred("monitoring", false)
	hit_detector.set_deferred("monitoring", false)
	# Wyłącz kolizje Area2D
	var hit_collision: CollisionShape2D = $CharacterBody2D/HitDetector/CollisionShape2D
	hit_collision.set_deferred("disabled", true)
	await sprite.animation_finished

	#queue_free()


func _on_player_detector_body_entered(body_entered: Node2D) -> void:##rozpocznij atak gdy gracza wejdzie w strefę ataku
	if body_entered.is_in_group("player"):
		player_in_attack_range = true
	if is_dead or is_hurt:
		return
	attack()

func _on_player_detector_body_exited(body_exited: Node2D) -> void:##przestań rozpoczynać ataki gdy nie ma kogo atakować
	player_in_attack_range = false


func attack() -> void:##atak
	if is_dead:
		return

	if is_hurt:
		return

	if is_attacking:
		return

	if not is_player_in_detector():
		return

	cancel_wait()

	is_attacking = true
	attack_has_hit = false

	attack_generation += 1
	var this_attack := attack_generation

	body.velocity.x = 0

	sprite.play("skeleton_attack")

	await sprite.animation_finished

	# Atak został przerwany np. przez take_damage()
	if this_attack != attack_generation:
		return

	if is_dead or is_hurt:
		return

	# Dodatkowe zabezpieczenie
	if sprite.animation != "skeleton_attack":
		is_attacking = false
		return

	is_attacking = false
	attack_has_hit = false

	if is_player_in_detector():
		attack()
	else:
		sprite.play("skeleton_walk")


func is_player_in_detector() -> bool:##sprawdź czy gracz jest w detektorze
	for detected_body in player_detector.get_overlapping_bodies():
		if detected_body.is_in_group("player"):
			return true

	return false


func _on_sprite_frame_changed() -> void:##funkcja do sprawdzania czy gracz jest na linii ataku w odpowiednich klatakch animacji ataku
	# Interesuje nas tylko animacja ataku
	if sprite.animation != "skeleton_attack":
		return

	if not is_attacking:
		return

	# Czy aktualna klatka jest klatką uderzenia?
	if sprite.frame not in attack_hit_frames:
		return

	# Ten zamach już kogoś trafił
	if attack_has_hit:
		return

	check_attack_hit()

func check_attack_hit() -> void:
	for detected_body in hit_detector.get_overlapping_bodies():##funkcja pomocnicza do sprawdzania czy to na pewno gracz a nie jakiś inny obiekt

		if detected_body.is_in_group("player"):
			if detected_body.has_method("take_damage"):
				detected_body.take_damage(attack_damage)
				attack_has_hit = true
				return
