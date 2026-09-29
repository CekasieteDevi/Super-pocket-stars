extends SceneTree
func _initialize() -> void:
	var n: Node3D = load("res://assets/3d/jugador.glb").instantiate()
	root.add_child(n)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.get_aabb()
		print("malla ", m.name, " y ", a.position.y, " .. ", a.end.y, " x escala ", Jugador3D.ESCALA_CHIBI, " = ", a.end.y * Jugador3D.ESCALA_CHIBI)
	for s in n.find_children("*", "Skeleton3D", true, false):
		for nombre in ["Frente", "Pecho", "Cabeza"]:
			var i: int = s.find_bone(nombre)
			if i >= 0:
				print(nombre, " ", s.get_bone_global_rest(i).origin.y * Jugador3D.ESCALA_CHIBI)
	for b in n.find_children("*", "BoneAttachment3D", true, false):
		print("anclaje ", b.name)
	quit()
