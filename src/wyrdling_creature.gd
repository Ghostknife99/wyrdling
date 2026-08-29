class_name WyrdlingCreature
extends RefCounted

var species_id: String = ""
var display_name: String = ""
var type_id: String = ""
var max_hp: int = 1
var hp: int = 1
var atk: int = 1
var def: int = 1
var spd: int = 1
var description: String = ""
var moves: Array[String] = []


func is_ko() -> bool:
	return hp <= 0


func hp_ratio() -> float:
	return float(hp) / float(maxi(1, max_hp))


func take_damage(amount: int) -> int:
	var applied: int = mini(hp, maxi(0, amount))
	hp -= applied
	return applied


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + maxi(0, amount))
