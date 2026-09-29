extends SceneTree
## Lista las mallas de jugador.glb y golero.glb: nodos, superficies, vertices.
func _init() -> void:
	for ruta in OS.get_cmdline_user_args() if OS.get_cmdline_user_args().size() > 0 else ["res://assets/3d/jugador.glb", "res://assets/3d/golero.glb"]:
		var m: Node = (load(ruta) as PackedScene).instantiate()
		var tot_s := 0
		var tot_v := 0
		print("== ", ruta)
		for n in m.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var s := mi.mesh.get_surface_count()
			var v := 0
			var mats := []
			for i in s:
				v += (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var mt := mi.mesh.surface_get_material(i)
				mats.append(mt.resource_name if mt else "-")
			tot_s += s
			tot_v += v
			print("  %s skin=%s surf=%d verts=%d %s" % [mi.name, mi.skin != null, s, v, mats])
		print("  TOTAL surf=%d verts=%d" % [tot_s, tot_v])
		m.free()
	quit()
