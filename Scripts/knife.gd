extends Area3D

@export var damage := 50
var attacking := false
var attacker: Node = null
var hit_bodies := []

func _ready() -> void:
	# Store the first CharacterBody3D ancestor as the attacker
	var node = self
	while node:
		if node is CharacterBody3D:
			attacker = node
			break
		node = node.get_parent()

func _on_body_entered(body: Node3D) -> void:
	if not attacking or not visible:
		return
	if body in hit_bodies:
		return  # Already damaged this body during this attack
	if attacker and body == attacker:
		return
	if attacker and body.is_in_group("Player") and attacker.is_in_group("Player"):
		return
	if attacker and body.is_in_group("NPC") and attacker.is_in_group("NPC"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
		hit_bodies.append(body)  # mark as hit

# Call this at the start of an attack animation
func start_attack():
	attacking = true
	hit_bodies.clear()  # reset for this attack

# Call this at the end of an attack animation
func end_attack():
	attacking = false
