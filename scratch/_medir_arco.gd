extends SceneTree
## Cajas (AABB global) de las mallas del arco en estadio.glb, como las pone la vista 3D.
var _n := 0
var _e: Node3D
func _initialize() -> void:
	_e = (load("res://assets/3d/estadio.glb") as PackedScene).instantiate()
	root.add_child(_e)
	process_frame.connect(_cuadro)
func _cuadro() -> void:
	_n += 1
	if _n < 2: return
	_ver(_e)
	quit()
func _ver(n: Node) -> void:
	if n is MeshInstance3D and "Arco" in n.name:
		var mi := n as MeshInstance3D
		print(n.name, " ", mi.global_transform * mi.get_aabb(), " escala ", mi.global_transform.basis.get_scale())
		var m := mi.mesh
		# Vértices del marco: el alto y el ancho del travesaño/postes.
		if not "Red" in n.name:
			var xs := {}
			for s in m.get_surface_count():
				var arr: Array = m.surface_get_arrays(s)
				for v in arr[Mesh.ARRAY_VERTEX]:
					var g: Vector3 = mi.global_transform * v
					xs[snappedf(g.y, 0.01)] = true
			var ys := xs.keys(); ys.sort()
			print("  alturas ", ys.slice(0, 12), " ... ", ys.slice(ys.size() - 12))
	for c in n.get_children(): _ver(c)
