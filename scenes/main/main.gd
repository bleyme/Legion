extends Node2D

const KILL_LIMIT := 10

var scores    := {1: 0, 2: 0}
var game_over := false

@onready var score_label  := $ScoreHUD/ScoreLabel
@onready var end_screen   := $EndScreen
@onready var end_label    := $EndScreen/WinLabel
@onready var restart_hint := $EndScreen/RestartHint

func _ready() -> void:
	var p1 := $Player1
	var p2 := $Player2

	p1.player_id         = 1
	p1.move_left_action  = "move_left"
	p1.move_right_action = "move_right"
	p1.jump_action       = "jump"
	p1.jetpack_action    = "jetpack"
	p1.shoot_action      = "shoot"
	p1.reload_action     = "reload"
	p1.died.connect(_on_player_died)

	p2.player_id         = 2
	p2.move_left_action  = "p2_move_left"
	p2.move_right_action = "p2_move_right"
	p2.jump_action       = "p2_jump"
	p2.jetpack_action    = "p2_jetpack"
	p2.shoot_action      = "p2_shoot"
	p2.reload_action     = "p2_reload"
	p2.get_node("Body").modulate = Color(1.0, 0.4, 0.1, 1.0)
	p2.get_node("HUD").offset   = Vector2(1060, 0)
	p2.died.connect(_on_player_died)

	end_screen.visible = false
	_update_score()

func _process(_delta: float) -> void:
	if game_over and Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()

func _on_player_died(player_node: Node) -> void:
	if game_over:
		return
	var killer_id       := 2 if player_node.player_id == 1 else 1
	scores[killer_id]  += 1
	_update_score()
	if scores[killer_id] >= KILL_LIMIT:
		_show_end_screen(killer_id)

func _update_score() -> void:
	score_label.text = "P1  %d — %d  P2" % [scores[1], scores[2]]

func _show_end_screen(winner_id: int) -> void:
	game_over            = true
	end_screen.visible   = true
	end_label.text       = "PLAYER %d WINS!" % winner_id
	end_label.modulate   = Color(1.0, 0.85, 0.2) if winner_id == 1 else Color(1.0, 0.4, 0.1)
