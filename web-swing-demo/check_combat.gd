extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var hero = world.player
	var gun = world.combat
	hero.set_physics_process(false)
	hero.position = Vector2(500, 432)
	hero.velocity = Vector2(450, -80)
	hero.attach_web(Vector2(600, 187))
	var anchor: Vector2 = hero.anchor
	var speed: Vector2 = hero.velocity
	for shot in 3:
		gun.fire_at(Vector2(720, 420))
		for i in 30:
			await physics_frame
	assert(gun.destroyed == 1, "Three bullets must destroy target")
	assert(hero.attached and hero.anchor == anchor and hero.velocity == speed, "Shooting must not change web or inertia")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	gun._unhandled_input(event)
	var count: int = gun.shots_fired
	for i in 60:
		await physics_frame
	assert(gun.shots_fired - count >= 3 and gun.shots_fired - count <= 4, "Holding right button must fire at controlled rate")
	event.pressed = false
	gun._unhandled_input(event)
	count = gun.shots_fired
	for i in 25:
		await physics_frame
	assert(gun.shots_fired == count, "Releasing right button must stop firing")
	gun.bullets.clear()
	hero.position = Vector2(1450, 437)
	gun.fire_at(Vector2(1700, 425))
	for i in 5:
		await physics_frame
	assert(gun.bullets.is_empty(), "Obstacle must stop bullet")
	print("PASS: three-hit target, simultaneous web and gun, no recoil, held fire rate, release, wall collision")
	quit()
