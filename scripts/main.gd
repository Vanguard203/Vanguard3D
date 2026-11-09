extends Node3D

const PLAYER_COLOR := Color(0.18, 0.55, 1.0)
const ENEMY_COLOR := Color(1.0, 0.28, 0.25)
const UNIT_NAMES := ["ブレード・ドラゴン", "スターライト・ナイト", "アストラル・ウィッチ"]

var player_units: Array[MeshInstance3D] = []
var enemy_units: Array[MeshInstance3D] = []
var player_power: Array[int] = []
var enemy_power: Array[int] = []
var player_life := 5
var enemy_life := 5
var turn_number := 1
var summoned_this_turn := false
var game_over := false
var status_label: Label
var life_label: Label
var turn_label: Label
var summon_button: Button
var attack_button: Button
var end_button: Button
var unit_root: Node3D

func _ready() -> void:
	_build_world()
	_build_ui()
	_update_ui()
	_set_status("あなたのターン！ユニットを召喚して攻撃しよう。")

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.055, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.65, 0.85)
	environment.ambient_light_energy = 0.7
	world_env.environment = environment
	add_child(world_env)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 8.5, 13)
	camera.rotation_degrees = Vector3(-28, 0, 0)
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.4
	add_child(light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(15, 12)
	floor.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.07, 0.12, 0.19)
	floor_mat.metallic = 0.25
	floor_mat.roughness = 0.65
	floor.material_override = floor_mat
	floor.position.y = -0.15
	add_child(floor)

	unit_root = Node3D.new()
	add_child(unit_root)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 116
	layer.add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 22)
	top.add_child(turn_label)
	life_label = Label.new()
	life_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	life_label.add_theme_font_size_override("font_size", 20)
	top.add_child(life_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	column.add_child(status_label)

	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	summon_button = Button.new()
	summon_button.text = "ユニット召喚"
	summon_button.custom_minimum_size = Vector2(170, 42)
	summon_button.pressed.connect(_on_summon_pressed)
	buttons.add_child(summon_button)

	attack_button = Button.new()
	attack_button.text = "攻撃"
	attack_button.custom_minimum_size = Vector2(130, 42)
	attack_button.pressed.connect(_on_attack_pressed)
	buttons.add_child(attack_button)

	end_button = Button.new()
	end_button.text = "ターン終了"
	end_button.custom_minimum_size = Vector2(150, 42)
	end_button.pressed.connect(_on_end_turn_pressed)
	buttons.add_child(end_button)

func _make_unit(is_player: bool, index: int, power: int) -> MeshInstance3D:
	var unit := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.48
	mesh.height = 1.65
	unit.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAYER_COLOR if is_player else ENEMY_COLOR
	mat.metallic = 0.35
	mat.roughness = 0.3
	unit.material_override = mat
	var side_z := 2.2 if is_player else -2.2
	var x_pos := float(index - 1) * 2.0
	unit.position = Vector3(x_pos, 0.72, side_z)
	unit_root.add_child(unit)

	var label := Label3D.new()
	label.text = str(power) + " POW"
	label.position = Vector3(0, 1.25, 0)
	label.font_size = 48
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	unit.add_child(label)
	return unit

func _on_summon_pressed() -> void:
	if game_over or summoned_this_turn:
		return
	if player_units.size() >= 3:
		_set_status("前列がいっぱいだ！攻撃するかターンを終了しよう。")
		return
	var index := player_units.size()
	var power := 10000 + (index * 2000) + ((turn_number - 1) * 500)
	var unit := _make_unit(true, index, power)
	player_units.append(unit)
	player_power.append(power)
	summoned_this_turn = true
	_set_status(UNIT_NAMES[(turn_number - 1) % UNIT_NAMES.size()] + "を召喚！")
	_update_ui()

func _on_attack_pressed() -> void:
	if game_over:
		return
	if player_units.is_empty():
		_set_status("まずユニットを召喚しよう！")
		return
	if enemy_units.is_empty():
		enemy_life -= 1
		_set_status("ダイレクトアタック！相手のライフに1ダメージ！")
	else:
		var target := enemy_units.pop_front()
		enemy_power.pop_front()
		unit_root.remove_child(target)
		target.queue_free()
		_set_status("アタック成功！相手ユニットを退却させた！")
	_check_winner()
	_update_ui()

func _on_end_turn_pressed() -> void:
	if game_over:
		return
	turn_number += 1
	if enemy_units.size() < 3:
		var power := 9000 + (turn_number * 500)
		enemy_units.append(_make_unit(false, enemy_units.size(), power))
		enemy_power.append(power)
	if not player_units.is_empty():
		if enemy_units.is_empty():
			player_life -= 1
		else:
			var target := player_units.pop_front()
			player_power.pop_front()
			unit_root.remove_child(target)
			target.queue_free()
	_set_status("相手のターン終了。あなたのターンだ！")
	summoned_this_turn = false
	_check_winner()
	_update_ui()

func _check_winner() -> void:
	if enemy_life <= 0:
		game_over = true
		_set_status("勝利！相手のライフを削り切った！")
	elif player_life <= 0:
		game_over = true
		_set_status("敗北……もう一度挑戦しよう！")

func _set_status(message: String) -> void:
	if status_label:
		status_label.text = message

func _update_ui() -> void:
	if turn_label:
		turn_label.text = "TURN " + str(turn_number)
	if life_label:
		life_label.text = "あなた ♥ " + str(player_life) + "    相手 ♥ " + str(enemy_life)
	if summon_button:
		summon_button.disabled = game_over or summoned_this_turn or player_units.size() >= 3
	if attack_button:
		attack_button.disabled = game_over or player_units.is_empty()
	if end_button:
		end_button.disabled = game_over
