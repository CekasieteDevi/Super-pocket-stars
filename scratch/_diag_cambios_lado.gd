extends SceneTree
## Bug 3D-06: por qué banda sale el que se va en un cambio.
##   -- division=1 semilla=N
## Por cada cambio (campo `cambios` del fotograma): el que sale, dónde está
## al empezar y dónde está el último cuadro que se lo ve; y el que entra, dónde
## aparece. ARRIBA si sale o entra por la banda de arriba (y < 0): el cuarto
## árbitro está siempre abajo (+y).
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
	var vistos := {}
	var arriba := 0
	var total := 0
	for k in fotos.size():
		for c in fotos[k].get("cambios", []):
			var sal := int(c.get("saliente_clave", -1))
			var ent := int(c.get("entrante_clave", -1))
			var llave := "%d-%d" % [sal, ent]
			if vistos.has(llave): continue
			vistos[llave] = true
			var j0 := VistaPartido._jugador_en(fotos[k], sal)
			var ult := {}
			var kk := k
			while kk < fotos.size():
				var j := VistaPartido._jugador_en(fotos[kk], sal)
				if j.is_empty(): break
				ult = j
				kk += 1
			var je := {}
			for q in range(k, mini(k + 200, fotos.size())):
				je = VistaPartido._jugador_en(fotos[q], ent)
				if not je.is_empty(): break
			var y_sal := float(ult.get("y", 0.0))
			var y_ent := float(je.get("y", 0.0))
			var mal := y_sal < 0.0 or y_ent < 0.0
			total += 1
			if mal: arriba += 1
			print("%s tick %d min %d sale %d desde (%.1f,%.1f) ultimo (%.1f,%.1f) tick %d | entra %d en (%.1f,%.1f)" % [
				"ARRIBA" if mal else "abajo", k, int(fotos[k].get("minuto", 0)), sal,
				float(j0.get("x", 0.0)), float(j0.get("y", 0.0)), float(ult.get("x", 0.0)), y_sal, kk - 1,
				ent, float(je.get("x", 0.0)), y_ent])
	print("RESUMEN ARRIBA ", arriba, " de ", total)
	quit()
