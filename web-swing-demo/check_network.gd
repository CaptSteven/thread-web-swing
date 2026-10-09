extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	var net = world.get_node("Network")
	var hosting := "--host" in OS.get_cmdline_user_args()
	var start := Time.get_ticks_msec()
	var saw_web := false
	var saw_damage := false
	var saw_death := false
	var ready_time := 0.0
	while Time.get_ticks_msec() - start < 18000:
		await physics_frame
		if net.actors.size() != 2:
			continue
		ready_time += 1.0 / 120.0
		if hosting:
			for id in net.actors:
				net.actors[id].set_physics_process(false)
				net.actors[id].position = Vector2(680 if id == 1 else 1020, 400)
				net.stats[id].shield = 0.0
				if id != 1 and net.actors[id].attached:
					saw_web = true
			if net.stats[1].hp < 100:
				saw_damage = true
			if net.stats[1].dead > 0:
				saw_death = true
			if saw_death and net.stats[1].hp == 100:
				assert(saw_web and saw_damage, "Must receive web controls and remote gun damage")
				print("PASS NETWORK HOST: remote web input, authoritative bullet hit, kill, timed respawn")
				await create_timer(0.3).timeout
				quit(0)
				return
		else:
			var id: int = multiplayer_id(net)
			if ready_time < 0.25:
				net.submit.rpc_id(1, Vector2(900, 207), true, false)
			else:
				net.submit.rpc_id(1, Vector2(680, 388), false, net.stats[id].kills == 0)
			if net.stats[1].dead > 0:
				saw_death = true
			if saw_death and net.stats[1].hp == 100:
				assert(net.stats[id].kills == 1, "Kill score must synchronize")
				print("PASS NETWORK CLIENT: snapshots, remote health, score and respawn synchronized")
				quit(0)
				return
	push_error("NETWORK TEST TIMEOUT")
	quit(1)

func multiplayer_id(net: Node) -> int:
	return net.multiplayer.get_unique_id()
