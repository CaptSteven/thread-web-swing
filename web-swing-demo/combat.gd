extends Node2D

const SHOT_INTERVAL := 0.14
const BULLET_SPEED := 1500.0
var firing := false
var cooldown := 0.0
var flash := 0.0
var destroyed := 0
var shots_fired := 0
var bullets: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var targets: Array[StaticBody2D] = []
var hero: CharacterBody2D

func _ready() -> void:
	hero = get_parent().player
	for point in [Vector2(720, 420), Vector2(1190, 300), Vector2(1880, 490), Vector2(2470, 350), Vector2(3250, 440), Vector2(4270, 340)]:
		var target := StaticBody2D.new()
		target.position = point
		target.collision_layer = 4
		target.collision_mask = 0
		target.set_meta("hp", 3)
		target.set_meta("respawn", 0.0)
		var collider := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 22
		collider.shape = circle
		target.add_child(collider)
		add_child(target)
		targets.append(target)

func _unhandled_input(event: InputEvent) -> void:
	if get_parent().has_node("Network") and get_parent().get_node("Network").active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		firing = event.pressed

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		firing = false

func fire_at(point: Vector2) -> void:
	var origin: Vector2 = hero.hand_position()
	var direction := origin.direction_to(point)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	bullets.append({"position": origin, "velocity": direction * BULLET_SPEED, "life": 0.0})
	flash = 0.055
	shots_fired += 1

func _physics_process(delta: float) -> void:
	if get_parent().has_node("Network") and get_parent().get_node("Network").active:
		queue_redraw()
		return
	cooldown = maxf(0, cooldown - delta)
	flash = maxf(0, flash - delta)
	if firing and cooldown <= 0:
		fire_at(get_global_mouse_position())
		cooldown = SHOT_INTERVAL
	for target in targets:
		if int(target.get_meta("hp")) <= 0:
			var remaining := float(target.get_meta("respawn")) - delta
			target.set_meta("respawn", remaining)
			if remaining <= 0:
				target.set_meta("hp", 3)
				target.collision_layer = 4
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i]
		var next: Vector2 = bullet.position + bullet.velocity * delta
		var query := PhysicsRayQueryParameters2D.create(bullet.position, next, 5)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		bullet.life += delta
		if not hit.is_empty():
			var body: Object = hit.collider
			if body.has_meta("hp"):
				var hp := int(body.get_meta("hp")) - 1
				body.set_meta("hp", hp)
				if hp == 0:
					body.collision_layer = 0
					body.set_meta("respawn", 5.0)
					destroyed += 1
			sparks.append({"position": hit.position, "age": 0.0})
			bullets.remove_at(i)
		elif bullet.life > 1.4:
			bullets.remove_at(i)
		else:
			bullet.position = next
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].age += delta
		if sparks[i].age > 0.25:
			sparks.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if get_parent().has_node("Network") and get_parent().get_node("Network").active:
		return
	for target in targets:
		var hp := int(target.get_meta("hp"))
		if hp <= 0:
			continue
		draw_circle(target.position, 22, Color("392e38"))
		draw_arc(target.position, 22, 0, TAU, 32, Color("ff846b"), 2, true)
		draw_line(target.position - Vector2(9, 0), target.position + Vector2(9, 0), Color("ff846b"), 3, true)
		for pip in hp:
			draw_rect(Rect2(target.position + Vector2(-14 + pip * 11, -34), Vector2(8, 3)), Color("ffcf80"))
	for bullet in bullets:
		draw_line(bullet.position - bullet.velocity.normalized() * 17, bullet.position, Color("ffdf93"), 3, true)
	for spark in sparks:
		for i in 8:
			var dir := Vector2.from_angle(i * TAU / 8)
			draw_line(spark.position + dir * spark.age * 70, spark.position + dir * (spark.age * 100 + 5), Color(1, 0.65, 0.35, 1 - spark.age / 0.25), 2, true)
	if is_instance_valid(hero):
		var hand: Vector2 = hero.hand_position()
		var direction := hand.direction_to(get_global_mouse_position())
		draw_line(hand, hand + direction * 17, Color("ffcf80"), 5, true)
		if flash > 0:
			draw_circle(hand + direction * 23, 5, Color("fff1bd"))
