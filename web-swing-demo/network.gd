extends Node2D

const PORT := 24816
var active := false
var actors: Dictionary = {}
var stats: Dictionary = {}
var controls: Dictionary = {}
var shots: Array[Dictionary] = []
var remote: CharacterBody2D
var world: Node2D
var panel: PanelContainer
var address: LineEdit
var message: Label
var score: Label
var clock := 0.0
var sync_time := 0.0
var test_mode := false

func _ready() -> void:
	world = get_parent()
	multiplayer.peer_connected.connect(peer_joined)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(func(): message.text = "已连接，等待房主同步…")
	multiplayer.connection_failed.connect(func(): leave("连接失败，请检查 IP、Wi-Fi 和防火墙"))
	multiplayer.server_disconnected.connect(func(): leave("房主已离开，返回练习模式"))
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(380, 240)
	panel.custom_minimum_size = Vector2(510, 280)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "THREAD · 双人局域网对战"
	box.add_child(title)
	address = LineEdit.new()
	address.placeholder_text = "输入房主 IP，例如 192.168.1.20"
	box.add_child(address)
	for item in [["创建房间", host], ["加入房间", join_room], ["单人练习", practice]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		box.add_child(button)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = 490
	message.text = "左键蛛丝 / 右键射击 · 100 血 · 5 发击杀 · 2 秒复活\n同一 Wi-Fi，房主创建后分享 IP；Esc 打开房间菜单"
	box.add_child(message)
	score = Label.new()
	score.position = Vector2(390, 25)
	score.add_theme_font_size_override("font_size", 18)
	layer.add_child(score)
	var exit_button := Button.new()
	exit_button.text = "离开房间"
	exit_button.pressed.connect(func(): leave("已离开房间"))
	box.add_child(exit_button)
	var args := OS.get_cmdline_user_args()
	test_mode = "--net-test" in args
	if "--host" in args:
		host()
	elif "--join-local" in args:
		address.text = "127.0.0.1"
		join_room()

func practice() -> void:
	if active:
		leave("单人练习")
	panel.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		panel.visible = not panel.visible

func host() -> void:
	if active:
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 1)
	if error != OK:
		message.text = "无法创建房间：端口可能已占用（%s）" % error
		return
	multiplayer.multiplayer_peer = peer
	active = true
	world.combat.firing = false
	world.combat.bullets.clear()
	register(1, world.player)
	var ips: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			ips.append(ip)
	message.text = "房间已创建，等待另一位玩家\n房主 IP：%s\nUDP 端口：%d" % [", ".join(ips), PORT]
	print("NET HOST READY")

func join_room() -> void:
	if active:
		return
	var ip := address.text.strip_edges()
	if not ip.is_valid_ip_address():
		message.text = "请输入有效的房主 IP 地址"
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, PORT)
	if error != OK:
		message.text = "创建连接失败：%s" % error
		return
	multiplayer.multiplayer_peer = peer
	active = true
	clock = 0
	world.combat.firing = false
	world.combat.bullets.clear()
	world.player.set_physics_process(false)
	message.text = "正在连接…"

func register(id: int, actor: CharacterBody2D) -> void:
	actors[id] = actor
	actor.set_meta("peer_id", id)
	stats[id] = {"hp": 100, "kills": 0, "dead": 0.0, "shield": 1.0, "cooldown": 0.0}
	controls[id] = {"aim": Vector2.ZERO, "left": false, "right": false, "stamp": clock}
	spawn(id)

func spawn(id: int) -> void:
	var actor: CharacterBody2D = actors[id]
	actor.detach_web("复活")
	actor.position = Vector2(680 if id == 1 else 1020, 390)
	actor.velocity = Vector2.ZERO
	actor.trail.clear()
	actor.visible = true
	actor.collision_layer = 2
	actor.set_physics_process(true)
	stats[id].hp = 100
	stats[id].shield = 1.0
	controls[id].left = false

func peer_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	remote = CharacterBody2D.new()
	remote.set_script(world.HERO)
	world.add_child(remote)
	remote.modulate = Color("ff947c")
	register(id, remote)
	panel.hide()
	print("NET PEER JOINED ", id)

func peer_left(id: int) -> void:
	if multiplayer.is_server() and actors.has(id):
		actors[id].queue_free()
		actors.erase(id)
		stats.erase(id)
		controls.erase(id)
		shots.clear()
		message.text = "对手已离开，等待新玩家加入"
		panel.show()

func leave(reason: String) -> void:
	active = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if is_instance_valid(remote):
		remote.queue_free()
	actors.clear()
	stats.clear()
	controls.clear()
	shots.clear()
	world.player.visible = true
	world.player.collision_layer = 2
	world.player.set_physics_process(true)
	world.player.reset()
	world.combat.firing = false
	world.combat.bullets.clear()
	panel.show()
	message.text = reason
	score.text = ""

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit(aim: Vector2, left: bool, right: bool) -> void:
	if not multiplayer.is_server() or not aim.is_finite():
		return
	var id := multiplayer.get_remote_sender_id()
	if controls.has(id):
		apply_controls(id, aim, left, right)

func apply_controls(id: int, aim: Vector2, left: bool, right: bool) -> void:
	var actor: CharacterBody2D = actors[id]
	var old: Dictionary = controls[id]
	if stats[id].dead <= 0:
		if left and not old.left:
			var origin: Vector2 = actor.hand_position()
			var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(origin, origin + origin.direction_to(aim) * actor.REACH, 1))
			if not hit.is_empty():
				actor.attach_web(hit.position)
		elif not left and old.left:
			actor.detach_web("已主动松开蛛丝")
	controls[id] = {"aim": aim, "left": left, "right": right, "stamp": clock}

func fell(actor: CharacterBody2D) -> void:
	if multiplayer.is_server() and actor.has_meta("peer_id"):
		kill_player(int(actor.get_meta("peer_id")), 0)

func kill_player(victim: int, attacker: int) -> void:
	if stats[victim].dead > 0:
		return
	stats[victim].hp = 0
	stats[victim].dead = 2.0
	actors[victim].detach_web("被击败")
	actors[victim].hide()
	actors[victim].collision_layer = 0
	actors[victim].set_physics_process(false)
	if attacker != victim and stats.has(attacker):
		stats[attacker].kills += 1
	print("NET KILL ", attacker, " -> ", victim)

func _physics_process(delta: float) -> void:
	if not active:
		return
	clock += delta
	sync_time += delta
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		if clock > 10:
			leave("连接超时，请检查房主 IP、同一网络以及 UDP 24816 端口")
		return
	var aim := get_global_mouse_position()
	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not panel.visible and DisplayServer.window_is_focused()
	var right := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not panel.visible and DisplayServer.window_is_focused()
	if multiplayer.is_server():
		if not test_mode:
			apply_controls(1, aim, left, right)
		for id in actors:
			var state: Dictionary = stats[id]
			state.shield = maxf(0, state.shield - delta)
			state.cooldown = maxf(0, state.cooldown - delta)
			if state.dead > 0:
				state.dead = maxf(0, state.dead - delta)
				if state.dead == 0:
					spawn(id)
				continue
			var input: Dictionary = controls[id]
			if clock - input.stamp > 0.4:
				input.right = false
				input.left = false
				actors[id].detach_web("输入中断")
			if input.right and state.cooldown <= 0:
				var origin: Vector2 = actors[id].hand_position()
				shots.append({"position": origin, "velocity": origin.direction_to(input.aim) * 1500, "owner": id, "age": 0.0})
				state.cooldown = 0.14
		update_shots(delta)
		if sync_time >= 1.0 / 30.0:
			sync_time = 0
			var data: Dictionary = {}
			for id in actors:
				data[id] = {"position": actors[id].position, "velocity": actors[id].velocity, "anchor": actors[id].anchor, "attached": actors[id].attached, "age": actors[id].web_age, "rest": actors[id].rest_length, "damage": actors[id].web_damage, "force": actors[id].web_force, "stats": stats[id].duplicate(), "aim": controls[id].aim}
			if multiplayer.get_peers().size() > 0:
				snapshot.rpc(data, shots)
	else:
		if sync_time >= 1.0 / 60.0 and not test_mode:
			sync_time = 0
			submit.rpc_id(1, aim, left, right)
	var local_id := multiplayer.get_unique_id()
	if stats.has(local_id):
		var s: Dictionary = stats[local_id]
		var enemy_kills := 0
		for id in stats:
			if id != local_id:
				enemy_kills = stats[id].kills
		score.text = "血量 %d / 100    击杀 %d : %d" % [s.hp, s.kills, enemy_kills]
		if s.dead > 0:
			score.text += "    %.1f 秒后复活" % s.dead
	queue_redraw()

func update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		var next: Vector2 = shot.position + shot.velocity * delta
		var excluded: Array[RID] = []
		if actors.has(shot.owner):
			excluded.append(actors[shot.owner].get_rid())
		var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(shot.position, next, 3, excluded))
		shot.age += delta
		if not hit.is_empty():
			if hit.collider.has_meta("peer_id"):
				var victim := int(hit.collider.get_meta("peer_id"))
				if stats.has(victim) and stats[victim].shield <= 0 and stats[victim].dead <= 0:
					stats[victim].hp -= 20
					if stats[victim].hp <= 0:
						kill_player(victim, shot.owner)
			shots.remove_at(i)
		elif shot.age > 1.4:
			shots.remove_at(i)
		else:
			shot.position = next

@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(data: Dictionary, projectiles: Array) -> void:
	if multiplayer.is_server():
		return
	var local_id := multiplayer.get_unique_id()
	for id in data:
		if not actors.has(id):
			if id == local_id:
				actors[id] = world.player
			else:
				remote = CharacterBody2D.new()
				remote.set_script(world.HERO)
				world.add_child(remote)
				remote.modulate = Color("ff947c")
				actors[id] = remote
			actors[id].set_physics_process(false)
		var actor: CharacterBody2D = actors[id]
		var state: Dictionary = data[id]
		if actor.attached and not state.attached:
			world.shed_web(actor.hand_position(), actor.anchor, actor.velocity)
		actor.position = state.position
		actor.velocity = state.velocity
		actor.anchor = state.anchor
		actor.attached = state.attached
		actor.web_age = state.age
		actor.rest_length = state.rest
		actor.web_damage = state.damage
		actor.web_force = state.force
		actor.visible = state.stats.dead <= 0
		actor.queue_redraw()
		stats[id] = state.stats
		controls[id] = {"aim": state.aim}
	shots.assign(projectiles)
	if panel.visible and message.text.begins_with("已连接"):
		panel.hide()

func _draw() -> void:
	if not active:
		return
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		if not actor.visible:
			continue
		if actor != world.player and actor.attached:
			draw_line(actor.hand_position(), actor.anchor, Color("ffc0ab"), 1.5, true)
		var aim: Vector2 = controls[id].aim
		draw_line(actor.hand_position(), actor.hand_position() + actor.hand_position().direction_to(aim) * 19, Color("ffcf80"), 4, true)
		draw_rect(Rect2(actor.position + Vector2(-22, -43), Vector2(44, 4)), Color("443a47"))
		draw_rect(Rect2(actor.position + Vector2(-22, -43), Vector2(44 * stats[id].hp / 100.0, 4)), Color("74f6dc"))
	for shot in shots:
		draw_line(shot.position - shot.velocity.normalized() * 17, shot.position, Color("ffdf93"), 3, true)
