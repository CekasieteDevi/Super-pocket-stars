extends SceneTree
## Altura y corrimiento de las manos del golero en cada animación (sin el
## salto del 2D), cuadro a cuadro: para calzar la pelota de la atajada.
##   -- [anims=Atajar_Volando,Agarrar] [paso=0.0417]
func _initialize() -> void:
	var anims := ["Atajar_Volando", "Agarrar", "Arquero_Sostiene"]
	var paso := 1.0 / 24.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("anims="): anims = Array(a.trim_prefix("anims=").split(","))
		if a.begins_with("paso="): paso = float(a.trim_prefix("paso="))
	var j := Jugador3D.new(load(VistaCancha3D.ESCENA_GOLERO) as PackedScene)
	root.add_child(j)
	await process_frame
	for anim in anims:
		if not j.tiene(anim):
			print("NO TIENE ", anim)
			continue
		var dur := j.duracion(anim)
		print("== %s (%.3f s)" % [anim, dur])
		var t := 0.0
		while t <= dur + 0.0001:
			j.poner(anim, t)
			var m := (j.ancla("Mano_L") + j.ancla("Mano_R")) * 0.5
			var cab := j.hueso("Cabeza").origin
			print("  t %.3f (%.2f)  manos x %.2f y %.2f z %.2f | cabeza y %.2f" % [t, t / dur, m.x, m.y, m.z, cab.y])
			t += paso
	quit()
