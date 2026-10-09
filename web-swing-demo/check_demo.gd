extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	for i in 80:
		await physics_frame
	var hero = world.player
	assert(hero.is_on_floor(), "Player must land on the launch pad")
	assert(absf(hero.position.y - 643.0) < 2.0, "Roof collision must hold")
	# Pull must lift a stationary player off the launch pad without keyboard input.
	var start: Vector2 = hero.position
	hero.attach_web(Vector2(570, 187))
	for i in 100:
		await physics_frame
	assert(hero.attached, "Unobstructed rope must remain attached")
	assert(hero.position.x > start.x + 40, "Web must pull forward from rest")
	assert(hero.position.y < start.y - 10, "Web must lift without jumping")
	assert(hero.position.distance_to(hero.anchor) < start.distance_to(hero.anchor) - 40, "Holding must shorten distance to anchor")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	var speed_before: Vector2 = hero.velocity
	var fragments_before: int = world.loose_webs.size()
	hero._unhandled_input(release)
	assert(world.loose_webs.size() == fragments_before + 2, "Manual release must animate the thread")
	hero._unhandled_input(release)
	assert(world.loose_webs.size() == fragments_before + 2, "Repeated release must not duplicate fragments")
	assert(not hero.attached, "Mouse release must detach")
	assert(hero.velocity == speed_before, "Release must preserve momentum")
	for i in 10:
		await physics_frame
	assert(absf(hero.velocity.x - speed_before.x) < 0.1, "Free flight must preserve horizontal inertia")
	assert(hero.velocity.y > speed_before.y, "Gravity must continue after release")
	# Holding the pull into a solid building must not pass through its wall.
	hero.position = Vector2(1410, 425)
	hero.velocity = Vector2.ZERO
	hero.attach_web(Vector2(1470, 425))
	for i in 50:
		await physics_frame
		assert(hero.position.x <= 1460.1, "Web pull must respect wall collision")
	hero.reset()
	for i in 80:
		await physics_frame
	var grounded: Vector2 = hero.position
	for key in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_SPACE]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		for i in 5:
			await physics_frame
		event.pressed = false
		Input.parse_input_event(event)
	assert(hero.position.distance_to(grounded) < 0.1, "Keyboard must not move or jump")
	# Isolate elastic dynamics from buildings: verify curvature and angular inertia.
	hero.set_physics_process(false)
	hero.position = Vector2(1000, 400)
	hero.velocity = Vector2(0, 1000)
	hero.attach_web(Vector2(1000, 100))
	hero.web_age = 0.4
	var overload_velocity: Vector2 = hero.velocity
	hero.update_web(1.0 / 120.0)
	assert(hero.attached, "One overload spike must not snap thread")
	for i in 24:
		hero.velocity = overload_velocity
		hero.update_web(1.0 / 120.0)
		if not hero.attached:
			break
	assert(not hero.attached and hero.web_force > hero.BREAK_FORCE, "Sustained radial overload must snap thread")
	assert(hero.velocity == overload_velocity, "Force break must retain momentum")
	assert(world.loose_webs.size() >= 2, "Force break must create two falling thread fragments")
	var fragment_index: int = world.loose_webs.size() - 1
	var fragment_y: float = world.loose_webs[fragment_index].points[6].y
	world.update_loose_webs(0.2)
	assert(world.loose_webs[fragment_index].points[6].y > fragment_y, "Thread fragments must fall")
	assert(hero.rotation == 0, "Character must not tumble")
	hero.attach_web(Vector2(1200, 180))
	world.update_loose_webs(1.3)
	assert(world.loose_webs.is_empty(), "Faded thread fragments must be cleaned up")
	hero.position = Vector2(1000, 400)
	hero.velocity = Vector2.ZERO
	hero.attach_web(Vector2(1000, 100))
	hero.web_age = 0.4
	hero.update_web(1.0 / 120.0)
	assert(hero.attached, "Ordinary tension must remain below break threshold")
	# Crossing upper/lower anchors in either direction detaches without a kick.
	for direction in [-1.0, 1.0]:
		for height in [180.0, 660.0]:
			hero.position = Vector2(1000, 400)
			hero.velocity = Vector2(direction * 600, 0)
			hero.attach_web(Vector2(1000 + direction * 100, height))
			hero.position.x = hero.anchor.x - direction
			assert(not hero.passed_anchor(), "Do not release before passing anchor")
			hero.position.x = hero.anchor.x + direction * 20
			var before: Vector2 = hero.velocity
			hero.update_web(1.0 / 120.0)
			assert(not hero.attached, "Release after passing upper/lower anchor")
			assert(hero.velocity == before, "Automatic release must preserve velocity")
	# Same-direction high-speed shots must survive while approaching the target.
	for distance in [70.0, 150.0, 400.0]:
		hero.position = Vector2.ZERO
		hero.velocity = Vector2(1200, 0)
		hero.attach_web(Vector2(distance, -50))
		hero.web_age = 0.4
		for i in 30:
			hero.update_web(1.0 / 120.0)
		assert(hero.attached, "Fast forward attachment must not overload")
	hero.position = Vector2(110, 200)
	hero.velocity = Vector2(700, -400)
	hero.attach_web(Vector2(200, 100))
	hero.position = Vector2(220, 200)
	assert(not hero.passed_anchor(), "Crossing horizontal plane while approaching must not detach")
	hero.position = Vector2(0, 400)
	hero.velocity = Vector2.ZERO
	hero.attach_web(Vector2(200, 200))
	hero.web_age = hero.WEB_LIFETIME - 0.01
	hero.update_web(0.02)
	assert(not hero.attached and hero.velocity == Vector2.ZERO, "Expired thread must disappear without a kick")
	hero.position = Vector2(0, 400)
	hero.velocity = Vector2(250, 0)
	hero.attach_web(Vector2.ZERO)
	var initial_momentum: float = hero.position.cross(hero.velocity)
	for i in 180:
		hero.update_web(1.0 / 120.0)
		hero.position += hero.velocity / 120.0
	assert(absf(hero.position.cross(hero.velocity) - initial_momentum) < 10.0, "Radial tension must preserve angular momentum")
	assert(hero.position.y < 300, "Trajectory must curve around anchor")
	assert(hero.spring_strength(750) < hero.spring_strength(250), "Long webs must be softer")
	var lifetimes: Array[float] = []
	for length in [650.0, 850.0]:
		hero.position = Vector2(0, length)
		hero.velocity = Vector2.ZERO
		hero.attach_web(Vector2.ZERO)
		var duration := 0.0
		while hero.attached and duration < 30:
			hero.update_web(1.0 / 120.0)
			duration += 1.0 / 120.0
		assert(not hero.attached, "Overlong thread must break")
		lifetimes.append(duration)
	assert(lifetimes[1] < lifetimes[0], "Longer thread must break sooner")
	hero.set_physics_process(true)
	hero.position.y = 1400
	await physics_frame
	await physics_frame
	assert(hero.position.distance_to(Vector2(220, 635)) < 10, "Falling must reset")
	print("PASS: new-map lift, inertia, obstacles, keyboard disabled, upper/lower anchor crossing in both directions, lifetime expiry, elastic swing, breakage, reset")
	hero.reset()
	for i in 90:
		await process_frame
	world.loose_webs.clear()
	world.best_distance = 0
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview.png")
	quit()
