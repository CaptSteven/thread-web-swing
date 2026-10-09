extends Node2D

const HERO = preload("res://player.gd")
const CYAN = Color("74f6dc")
var buildings: Array[Rect2] = []
var player: CharacterBody2D
var combat: Node2D
var camera: Camera2D
var status: Label
var telemetry: Label
var hint: Label
var elapsed := 0.0
var best_distance := 0.0
var font := ThemeDB.fallback_font
var loose_webs: Array[Dictionary] = []

func shed_web(start: Vector2, end: Vector2, momentum: Vector2) -> void:
	# Detached visual remnants have no collision or influence on the player.
	for half in 2:
		var points := PackedVector2Array()
		var speeds := PackedVector2Array()
		for i in 13:
			var t := half * 0.5 + i / 24.0
			points.append(start.lerp(end, t))
			var recoil := (start - end).normalized() * (1.0 if half == 0 else -1.0) * 45.0
			speeds.append(momentum * (1.0 - t) * 0.18 + recoil + Vector2(sin(t * 18) * 25, sin(t * PI) * 60))
		loose_webs.append({"points": points, "speeds": speeds, "age": 0.0})

func update_loose_webs(delta: float) -> void:
	for index in range(loose_webs.size() - 1, -1, -1):
		var thread := loose_webs[index]
		thread.age += delta
		if thread.age >= 1.2:
			loose_webs.remove_at(index)
			continue
		for i in thread.points.size():
			thread.speeds[i] += Vector2(sin(thread.age * 6 + i * 0.5) * 28, 280) * delta
			thread.points[i] += thread.speeds[i] * delta

func _ready() -> void:
	buildings = [Rect2(-100, 670, 450, 48)]
	# Alternating ceiling/floor islands leave the center open for long arcs.
	for i in 12:
		var x := 400.0 + i * 380.0
		buildings.append(Rect2(x, 145 + (i % 3) * 20, 220, 42))
		buildings.append(Rect2(x + 130, 640 + (i % 2) * 30, 210, 42))
	for obstacle in [Rect2(1470, 390, 35, 75), Rect2(2780, 320, 45, 65), Rect2(3910, 445, 40, 65)]:
		buildings.append(obstacle)
	for rect in buildings:
		var body := StaticBody2D.new()
		body.position = rect.position
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.size / 2.0
		body.add_child(shape)
		add_child(body)
	player = CharacterBody2D.new()
	player.set_script(HERO)
	add_child(player)
	combat = Node2D.new()
	combat.set_script(preload("res://combat.gd"))
	add_child(combat)
	camera = Camera2D.new()
	camera.position = Vector2(460, 390)
	add_child(camera)
	make_ui()
	var network := Node2D.new()
	network.name = "Network"
	network.set_script(preload("res://network.gd"))
	add_child(network)
	queue_redraw()

func make_label(parent: Node, text: String, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["PingFang SC", "Helvetica Neue"])
	label.add_theme_font_override("font", ui_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	make_label(layer, "T H R E A D", Vector2(38, 25), 31, Color.WHITE)
	make_label(layer, "02  /  上下蛛丝 · 开放通道", Vector2(40, 68), 14, CYAN)
	status = make_label(layer, "", Vector2(40, 112), 15, Color.WHITE)
	telemetry = make_label(layer, "", Vector2(960, 32), 16, CYAN)
	hint = make_label(layer, "", Vector2(40, 690), 19, Color.WHITE)
	make_label(layer, "左键按住  蛛丝移动    右键按住  连发射击    鼠标  瞄准    可同时摆荡与开火    R  重来", Vector2(40, 744), 17, Color("a2b3ca"))

func _process(delta: float) -> void:
	elapsed += delta
	update_loose_webs(delta)
	var target := Vector2(player.position.x + 170, 400)
	camera.position = camera.position.lerp(target, 1.0 - exp(-4.0 * delta))
	best_distance = maxf(best_distance, player.position.x - 220.0)
	status.text = "●  蛛丝已附着" if player.attached else "○  自由移动"
	status.modulate = CYAN if player.attached else Color("a2b3ca")
	if player.attached:
		status.text = "●  剩余 %.1f 秒  /  长度 %d  /  损伤 %d%%" % [maxf(0, player.WEB_LIFETIME - player.web_age), int(player.position.distance_to(player.anchor)), int(minf(player.web_damage, 1.0) * 100)]
		status.modulate = CYAN.lerp(Color("ff846b"), minf(player.web_damage, 1.0))
	telemetry.text = "速度  %03d\n最远  %04d m\n击毁  %02d" % [int(player.velocity.length() / 10.0), int(best_distance / 30.0), combat.destroyed]
	hint.text = "连接上方或下方的平台，在通道中央借惯性前进。"
	if player.attached:
		hint.text = "越过粘着点会自动松丝；每根蛛丝最多持续 2.4 秒。"
	elif player.break_time > 0:
		hint.text = player.break_reason + "。松开左键，再连接下一个平台。"
	elif player.miss_time > 0:
		hint.text = "蛛丝没有附着到平台。"
	elif player.position.x > 4300:
		hint.text = "到达城市尽头！按 R 再来一次。"
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(camera):
		return
	var left := camera.position.x - 720.0
	var top := camera.position.y - 450.0
	# Background stays behind the skyline and moves at a slower rate.
	for i in range(-6, 32):
		var x := i * 185.0 + camera.position.x * 0.72
		var height := 130.0 + fposmod(i * 97.0, 240.0)
		draw_rect(Rect2(x, 730 - height, 135, 1200), Color("101d30"))
	for i in range(75):
		var star := Vector2(left + fposmod(i * 173.7 - camera.position.x * 0.08, 1450), top + fposmod(i * 89.3, 470))
		draw_circle(star, 1.2, Color(0.5, 0.65, 0.8, 0.3))
	draw_circle(Vector2(camera.position.x * 0.85 + 280, 70), 40, Color("24394b"))
	draw_circle(Vector2(camera.position.x * 0.85 + 291, 61), 35, Color("0d1828"))
	for i in buildings.size():
		var rect := buildings[i]
		draw_rect(rect, Color("1d3043"))
		draw_rect(Rect2(rect.position + Vector2(7, 8), Vector2(rect.size.x - 14, rect.size.y - 8)), Color("172638"))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), CYAN, 3, true)
		draw_line(rect.position, rect.position + Vector2(0, rect.size.y), Color("365166"), 2)
		for col in maxi(0, int(rect.size.x / 36.0) - 1):
			for row in maxi(0, int((rect.size.y - 10) / 22.0)):
				var lit := (col * 3 + row * 7 + i) % 5 < 2
				var color := Color("466a72") if lit else Color("21394b")
				draw_rect(Rect2(rect.position + Vector2(22 + col * 36, 12 + row * 22), Vector2(11, 12)), color)
		if rect.position.y < 250:
			draw_line(rect.position + Vector2(0, rect.size.y), rect.end, CYAN, 3, true)
		elif rect.position.y < 600:
			draw_rect(rect, Color("ff846b"), false, 2)
		if i > 0:
			draw_string(font, rect.position + Vector2(15, -15), "%02d" % i, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CYAN)
	draw_string(font, Vector2(70, 715), "LAUNCH PAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CYAN)
	for thread in loose_webs:
		var color := Color("e3fff7")
		color.a = pow(1.0 - thread.age / 1.2, 0.7)
		draw_polyline(thread.points, color, 1.5, true)
	if player.attached:
		var stress := maxf(player.web_damage, clampf((player.web_force / player.BREAK_FORCE - 0.55) / 0.45, 0, 1))
		var web_color := Color("e3fff7").lerp(Color("ff846b"), minf(stress, 1.0))
		web_color.a = clampf((player.WEB_LIFETIME - player.web_age) / 0.5, 0.15, 1.0)
		var web_start: Vector2 = player.hand_position()
		var slack := maxf(0.0, player.rest_length - player.position.distance_to(player.anchor))
		var previous := web_start
		for segment in range(1, 25):
			var fraction := segment / 24.0
			var point := web_start.lerp(player.anchor, fraction)
			point.y += sin(fraction * PI) * minf(slack * 0.3, 55.0)
			draw_line(previous, point, web_color, 1.5, true)
			previous = point
		draw_circle(player.anchor, 5, CYAN)
		draw_arc(player.anchor, 11 + sin(elapsed * 6) * 2, 0, TAU, 32, Color(CYAN, 0.4), 1.5, true)
