extends SceneTree
## Remates de un partido: por dónde llegan al arco y qué hace el arquero.
## Para "más direcciones en los tiros y más atajadas" (BUGS_1.1.00, Para más adelante).
##   -- division=1 semilla=5 [semillas=1,2,3]
## Por remate: tick del golpe, acción, resultado, y de la pelota en la línea
## (o donde termina), y del arquero, distancia lateral, z máx del motor, y
## qué graba el arquero (vuela / agarra) y cómo termina (agarra o rechazo).
func _initialize() -> void:
	var division := 0
	var semillas: Array = [PrototipoVista.SEMILLA]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("semilla="): semillas = [int(a.trim_prefix("semilla="))]
		if a.begins_with("semillas="):
			semillas = []
			for s in a.trim_prefix("semillas=").split(","): semillas.append(int(s))
	var cuenta := {}
	for semilla in semillas:
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
		var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
		var fs: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		print("== semilla %d (%d fotogramas)" % [semilla, fs.size()])
		var k := 1
		while k < fs.size():
			var p: Dictionary = fs[k]["pelota"]
			if not bool(p.get("es_remate", false)) or bool(fs[k - 1]["pelota"].get("es_remate", false)):
				k += 1
				continue
			var inicio := k - 1
			var fin := k
			while fin + 1 < fs.size() and bool(fs[fin + 1]["pelota"].get("es_remate", false)):
				fin += 1
			var llega := mini(fin + 1, fs.size() - 1)
			var tirador := -1
			var accion := "?"
			for kk in [inicio, k]:
				for a in fs[kk].get("acciones", []):
					if str(a["accion"]) in ["patea", "volea", "chilena", "cabecea", "palomita"]:
						tirador = int(a["clave"]); accion = str(a["accion"])
			var resultado := "?"
			var travesano := false
			for kk in range(fin, mini(llega + 2, fs.size())):
				for ev in fs[kk].get("eventos", []):
					if str(ev.get("tipo", "")) in ["tiro", "tiro_puerta", "penal"]:
						resultado = str(ev.get("resultado", "?"))
						travesano = bool(ev.get("travesano", false))
			var zmax := 0.0
			for kk in range(k, llega + 1):
				zmax = maxf(zmax, float(fs[kk]["pelota"].get("z", 0.0)))
			var fin_p := Vector2(fs[fin]["pelota"]["x"], fs[fin]["pelota"]["y"])
			var local_tira := true
			var jt := VistaPartido._jugador_en(fs[inicio], tirador)
			if not jt.is_empty(): local_tira = bool(jt["equipo_local"])
			var arq := -1
			for j in fs[fin]["jugadores"]:
				if str(j["rol"]) == "ARQ" and bool(j["equipo_local"]) != local_tira:
					arq = int(j["id"])
			var ja := VistaPartido._jugador_en(fs[fin], arq)
			var ji := VistaPartido._jugador_en(fs[inicio], arq)
			var arq_y := float(ja.get("y", 0.0))
			var arq_y0 := float(ji.get("y", 0.0))
			var graba := []
			for kk in range(inicio, mini(llega + 3, fs.size())):
				for a in fs[kk].get("acciones", []):
					if int(a["clave"]) == arq:
						graba.append("%s@%d" % [a["accion"], kk - inicio])
			var queda := "-"
			if resultado == "atajada":
				queda = "agarra" if int(fs[llega]["pelota"].get("poseedor_id", -1)) == arq \
					or int(fs[mini(llega + 1, fs.size() - 1)]["pelota"].get("poseedor_id", -1)) == arq else "rechazo"
			var dy := fin_p.y - arq_y
			var clave_c := "%s/%s" % [resultado, queda]
			cuenta[clave_c] = int(cuenta.get(clave_c, 0)) + 1
			print("REMATE t%d min%d %s %s%s | arq %d | vuelo %d | pelota y %.2f | arq y0 %.2f y %.2f | dy %.2f | zmax %.2f | %s | %s" % [
				inicio, int(fs[inicio].get("minuto", 0)), accion, resultado, " (travesaño)" if travesano else "", arq,
				fin - inicio, fin_p.y, arq_y0, arq_y, dy, zmax, queda, ",".join(graba)])
			k = fin + 1
	print("TOTAL ", cuenta)
	quit()
