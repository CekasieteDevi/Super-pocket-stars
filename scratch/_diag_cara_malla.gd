extends SceneTree
## Mide dónde están los ojos, la boca, el flequillo y el contorno de la cara en la malla del GLB.
const SEED := 0

func _init() -> void:
	var escena: Node = (load("res://assets/3d/jugador.glb") as PackedScene).instantiate()
	var mi: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var d := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = d[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = d[Mesh.ARRAY_TEX_UV]
	var col: PackedColorArray = d[Mesh.ARRAY_COLOR]
	var nor: PackedVector3Array = d[Mesh.ARRAY_NORMAL]
	var ojo_i := [Vector3.INF, -Vector3.INF]
	var ojo_d := [Vector3.INF, -Vector3.INF]
	for i in pos.size():
		if roundi(uv[i].x) == 5 and col[i].to_html(false) == "3a2016" and pos[i].y > 1.4:
			var c: Array = ojo_i if pos[i].x < 0 else ojo_d
			c[0] = (c[0] as Vector3).min(pos[i]); c[1] = (c[1] as Vector3).max(pos[i])
	print("ojo x<0 ", ojo_i, " ojo x>0 ", ojo_d)
	# Flequillo: pelo más bajo al frente, por franja de x.
	for x in range(-45, 50, 5):
		var ymin := 9.0
		for i in pos.size():
			if roundi(uv[i].x) == 3 and nor[i].z > 0.3 and absf(pos[i].x - x / 100.0) < 0.025:
				ymin = minf(ymin, pos[i].y)
		var piel_y := [9.0, -9.0]
		for i in pos.size():
			if roundi(uv[i].x) == 4 and pos[i].z > 0.1 and pos[i].y > 1.15 and absf(pos[i].x - x / 100.0) < 0.025:
				piel_y = [minf(piel_y[0], pos[i].y), maxf(piel_y[1], pos[i].y)]
		print("x=%.2f flequillo_y=%.3f piel_y=%s" % [x / 100.0, ymin, piel_y])
	var n_frente := 0
	for i in pos.size():
		if roundi(uv[i].x) == 4 and pos[i].y > 1.15:
			n_frente += 1
	print("verts piel cabeza=", n_frente)
	escena.free()
	quit()
