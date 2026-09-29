extends SceneTree
## Mide la espalda de la camiseta (tipo 1, normal hacia -z) en jugador.glb y golero.glb: dónde va el dorsal.

func _init() -> void:
	for ruta in ["res://assets/3d/jugador.glb", "res://assets/3d/golero.glb"]:
		var escena: Node = (load(ruta) as PackedScene).instantiate()
		var mi: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
		var d := mi.mesh.surface_get_arrays(0)
		var pos: PackedVector3Array = d[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = d[Mesh.ARRAY_TEX_UV]
		var nor: PackedVector3Array = d[Mesh.ARRAY_NORMAL]
		var mn := Vector3.INF
		var mx := -Vector3.INF
		var tipos := {}
		for i in pos.size():
			var t := roundi(uv[i].x)
			if nor[i].z < -0.3:
				tipos[t] = tipos.get(t, 0) + 1
			if t == 1 and nor[i].z < -0.3:
				mn = mn.min(pos[i]); mx = mx.max(pos[i])
		print(ruta, " tipos atras=", tipos, " camiseta atras min=", mn, " max=", mx)
		# Perfil: por franja de y, x mínimo/máximo y z de la espalda.
		for y in range(50, 125, 5):
			var xs := [9.0, -9.0]
			var zs := [9.0, -9.0]
			var otros := {}
			for i in pos.size():
				if absf(pos[i].y - y / 100.0) < 0.025 and nor[i].z < -0.3:
					var t := roundi(uv[i].x)
					if t == 1:
						xs = [minf(xs[0], pos[i].x), maxf(xs[1], pos[i].x)]
						if absf(pos[i].x) < 0.15:
							zs = [minf(zs[0], pos[i].z), maxf(zs[1], pos[i].z)]
					else:
						otros[t] = otros.get(t, 0) + 1
			print("  y=%.2f x=%s z(centro)=%s otros=%s" % [y / 100.0, xs, zs, otros])
		escena.free()
	quit()
