extends CharacterBody2D

const REACH := 820.0
const GRAVITY := 500.0
const MAX_TENSION := 1800.0
const BREAK_FORCE := 2900.0
const OVERLOAD_GRACE := 0.16
const SAFE_LENGTH := 580.0
const BREAK_LENGTH := 1050.0
const WEB_LIFETIME := 2.4
var anchor := Vector2.ZERO
var rest_length := 0.0
var initial_length := 0.0
var web_age := 0.0
var web_damage := 0.0
var tension := 0.0
var web_force := 0.0
var overload_time := 0.0
var break_time := 0.0
var break_reason := ""
var pass_axis := Vector2.RIGHT
var attached := false
var miss_time := 0.0
var gait := 0.0
var facing := 1.0
var trail: Array[Vector2] = []

func _ready() -> void:
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 10.0
	capsule.height = 54.0
	collider.shape = capsule
	add_child(collider)
	collision_layer = 2
	collision_mask = 1
	position = Vector2(220, 635)
	floor_snap_length = 6.0

func hand_position() -> Vector2:
	return position + Vector2(0, -12)

func aim_hit() -> Dictionary:
	var start := hand_position()
	var direction := start.direction_to(get_global_mouse_position())
	var query := PhysicsRayQueryParameters2D.create(start, start + direction * REACH, 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)

func _unhandled_input(event: InputEvent) -> void:
	if get_parent().has_node("Network") and get_parent().get_node("Network").active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit := aim_hit()
			if not hit.is_empty():
				attach_web(hit.position)
			else:
				miss_time = 1.0
		else:
			detach_web("已主动松开蛛丝")
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset()

func reset() -> void:
	if get_parent().has_node("Network") and get_parent().get_node("Network").active:
		get_parent().get_node("Network").fell(self)
		return
	detach_web("已重置")
	position = Vector2(220, 635)
	velocity = Vector2.ZERO
	attached = false
	web_damage = 0.0
	break_time = 0.0
	trail.clear()

func attach_web(point: Vector2) -> void:
	detach_web("已切换粘着点")
	anchor = point
	var offset := anchor - position
	# A side-scrolling pass means crossing the anchor's vertical plane.
	# Near-vertical shots instead use the shot's vertical direction.
	pass_axis = Vector2(signf(offset.x), 0) if absf(offset.x) > 40 else Vector2(0, signf(offset.y))
	initial_length = position.distance_to(anchor)
	rest_length = maxf(40.0, initial_length * 0.55)
	web_age = 0.0
	overload_time = 0.0
	web_force = 0.0
	web_damage = 0.0
	tension = 0.0
	attached = true
	break_time = 0.0

func detach_web(reason: String) -> void:
	if not attached:
		return
	get_parent().shed_web(hand_position(), anchor, velocity)
	attached = false
	tension = 0.0
	break_time = 1.8
	break_reason = reason

func passed_anchor() -> bool:
	var offset := position - anchor
	return offset.dot(pass_axis) >= 12.0 and velocity.dot(pass_axis) > 0.0 and offset.normalized().dot(velocity) > 25.0

func spring_strength(length: float) -> float:
	return clampf(4000.0 / maxf(length, 120.0), 4.0, 18.0)

func update_web(delta: float) -> void:
	web_age += delta
	if web_age >= WEB_LIFETIME:
		detach_web("蛛丝已消散")
		return
	if passed_anchor():
		detach_web("已越过粘着点，自动松丝")
		return
	var radial := position - anchor
	var length := radial.length()
	var outward := radial / maxf(length, 0.001)
	# Gentle contraction leaves a substantial orbit instead of pulling to zero.
	rest_length = maxf(maxf(40.0, initial_length * 0.48), rest_length - 16.0 * delta)
	var stretch := maxf(0.0, length - rest_length)
	tension = 0.0
	web_force = 0.0
	if stretch > 0.0:
		# A tension-only elastic thread: no position snapping, no tangential damping.
		# Short threads absorb attachment shocks instead of multiplying tiny turns
		# into the same damping load as a long thread. Inward motion reduces load.
		var damping := 1.8 * clampf(initial_length / 300.0, 0.25, 1.0)
		web_force = maxf(0.0, stretch * spring_strength(initial_length) + velocity.dot(outward) * damping)
		web_force *= smoothstep(0.0, 0.32, web_age)
		tension = minf(web_force, MAX_TENSION)
	# A transient force spike is absorbed; sustained overload still breaks silk.
	if web_force > BREAK_FORCE:
		overload_time += delta
	else:
		overload_time = maxf(0.0, overload_time - delta * 2.0)
	if overload_time >= OVERLOAD_GRACE:
		detach_web("蛛丝持续受力过大，断裂")
		return
	var excess := maxf(0.0, (length - SAFE_LENGTH) / 220.0)
	web_damage += excess * excess * delta * 0.55
	if length >= BREAK_LENGTH or web_damage >= 1.0:
		detach_web("蛛丝过长，已经断裂")
		return
	velocity -= outward * tension * delta

func _physics_process(delta: float) -> void:
	miss_time = maxf(0, miss_time - delta)
	break_time = maxf(0, break_time - delta)
	velocity.y += GRAVITY * delta
	if attached:
		update_web(delta)
	if absf(velocity.x) > 5.0:
		facing = signf(velocity.x)
	move_and_slide()
	if attached and passed_anchor():
		detach_web("已越过粘着点，自动松丝")
	if attached:
		# Release a rope obstructed by another rooftop (no wrapping in this demo).
		var query := PhysicsRayQueryParameters2D.create(hand_position(), anchor, 1, [get_rid()])
		var obstruction := get_world_2d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty() and obstruction.position.distance_to(anchor) > 20:
			detach_web("蛛丝被障碍挡断")
	if position.y > 1300 or position.x < -650 or position.x > 5300:
		reset()
	gait += delta * absf(velocity.x) * 0.035
	trail.append(position)
	if trail.size() > 24:
		trail.pop_front()
	queue_redraw()

func _draw() -> void:
	for i in range(1, trail.size()):
		if velocity.length() > 450:
			draw_line(trail[i - 1] - position, trail[i] - position, Color(0.45, 0.96, 0.86, float(i) / trail.size() * 0.13), 3, true)
	var ink := Color("f2f7ff")
	var lean := clampf(velocity.x / 110.0, -6, 6)
	var head := Vector2(lean, -21)
	var shoulder := Vector2(lean * 0.6, -10)
	var hip := Vector2(0, 6)
	draw_circle(head, 7.5, ink, false, 2.5, true)
	draw_line(shoulder, hip, ink, 3, true)
	var step := sin(gait) * 10.0 if is_on_floor() else 8.0
	draw_line(hip, Vector2(-7 - step, 24), ink, 3, true)
	draw_line(hip, Vector2(7 + step, 24 if is_on_floor() else 18), ink, 3, true)
	if attached:
		var arm := (anchor - position).normalized() * 18.0
		draw_line(shoulder, shoulder + arm, ink, 3, true)
		draw_line(shoulder, Vector2(-facing * 12, 3), ink, 3, true)
	else:
		draw_line(shoulder, Vector2(-12, 3 + step * 0.5), ink, 3, true)
		draw_line(shoulder, Vector2(12, 3 - step * 0.5), ink, 3, true)
	draw_line(shoulder + Vector2(-3, 1), shoulder + Vector2(-facing * 19, -1), Color("74f6dc"), 4, true)
