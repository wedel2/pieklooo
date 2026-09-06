class_name WeaponData
extends Resource


enum WeaponType {
	SWORD,
	BOW
}


@export var weapon_name: String = ""
@export var weapon_type: WeaponType

@export_group("Graphics")
@export var pickup_texture: Texture2D
@export var animation_suffix: String = ""

@export_group("Combat")
@export var damage: int = 10
