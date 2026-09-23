class_name PlayerInput
extends RefCounted
## One frame of intent for a Player, filled by a controller (human or bot).

var move := 0.0              # -1..1
var jump_pressed := false    # edge
var jump_held := false
var down := false
var shoot := false
var grenade := false         # edge
var reload := false          # edge
var swap := false            # edge
var aim := Vector2.RIGHT     # normalised

func clear_edges() -> void:
	jump_pressed = false
	grenade = false
	reload = false
	swap = false
