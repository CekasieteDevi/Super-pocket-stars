extends SceneTree
## Bug 3D-07: un cambio antes de cobrar una falta y la cámara se queda con el
## jugador del cambio (el `foco` del fotograma) y no muestra el cobro.
##   -- division=1 semilla=N [corte_viejo]
## Lista cada tramo con `foco` (tick de inicio y fin, detenido, eventos y
## acciones del tramo) y marca FOCO_EN_JUEGO los ticks con foco en que la
## pelota se mueve o alguien la patea (el juego ya se reanudó).
var _p: Prototipo3D
var _n := 0
func _initialize() -> void:
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null or _n < 3: return
	var fotos: Array = rep.fotogramas
	var en_juego := 0
	var tramos := 0
	var k := 0
	while k < fotos.size():
		if fotos[k].get("foco", null) == null:
			k += 1
			continue
		var ini := k
		var eventos := []
		var acciones := []
		var jugado := 0
		var primer_jugado := -1
		while k < fotos.size() and fotos[k].get("foco", null) != null:
			var f: Dictionary = fotos[k]
			for e in f.get("eventos", []):
				eventos.append("%d:%s" % [k, str(e.get("tipo", e)) if e is Dictionary else str(e)])
			for a in f.get("acciones", []):
				acciones.append("%d:%s" % [k, str(a.get("accion", ""))])
			var mueve := false
			if k + 1 < fotos.size():
				var p0 := Vector2(float(f["pelota"]["x"]), float(f["pelota"]["y"]))
				var p1 := Vector2(float(fotos[k + 1]["pelota"]["x"]), float(fotos[k + 1]["pelota"]["y"]))
				mueve = p0.distance_to(p1) > 0.5
			if mueve or not f.get("acciones", []).is_empty():
				jugado += 1
				if primer_jugado < 0: primer_jugado = k
			k += 1
		tramos += 1
		if jugado > 0: en_juego += 1
		var foco: Dictionary = fotos[ini]["foco"]
		var pel: Dictionary = fotos[ini]["pelota"]
		print("%s tramo %d-%d min %d detenido %d->%d foco (%.1f,%.1f) pelota (%.1f,%.1f) jugados %d desde %d" % [
			"FOCO_EN_JUEGO" if jugado > 0 else "ok", ini, k - 1, int(fotos[ini].get("minuto", 0)),
			int(fotos[ini].get("detenido", 0)), int(fotos[k - 1].get("detenido", 0)),
			float(foco["x"]), float(foco["y"]), float(pel["x"]), float(pel["y"]), jugado, primer_jugado])
		print("   eventos ", eventos.slice(0, 12))
		print("   acciones ", acciones.slice(0, 12))
		# Lo que viene después: el evento que corta el juego antes y el saque.
		var antes := []
		for q in range(maxi(ini - 3, 0), ini):
			for e in fotos[q].get("eventos", []):
				antes.append("%d:%s" % [q, str(e.get("tipo", e)) if e is Dictionary else str(e)])
		print("   antes ", antes)
	print("RESUMEN FOCO_EN_JUEGO ", en_juego, " de ", tramos)
	quit()
