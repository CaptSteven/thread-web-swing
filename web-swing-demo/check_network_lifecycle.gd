extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	var net = world.get_node("Network")
	var host := "--host" in OS.get_cmdline_user_args()
	var stage := 0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 12000:
		await physics_frame
		if host:
			if stage == 0 and net.actors.size() == 2:
				stage = 1
			elif stage == 1 and net.actors.size() == 1:
				assert(net.stats.size() == 1 and net.controls.size() == 1, "Disconnected peer must be cleaned up")
				stage = 2
			elif stage == 2 and net.actors.size() == 2:
				print("PASS NETWORK LIFECYCLE HOST: peer cleanup and rejoin")
				await create_timer(0.5).timeout
				quit()
				return
		else:
			if stage == 0 and net.actors.size() == 2:
				net.leave("test leave")
				assert(not net.active and net.actors.is_empty() and world.player.is_physics_processing(), "Leave must restore practice")
				await create_timer(0.4).timeout
				net.join_room()
				stage = 1
			elif stage == 1 and net.actors.size() == 2:
				print("PASS NETWORK LIFECYCLE CLIENT: leave, practice restore, reconnect")
				quit()
				return
	push_error("LIFECYCLE TIMEOUT")
	quit(1)
