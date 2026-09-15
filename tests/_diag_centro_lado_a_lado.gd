extends SceneTree

## El reclamo: en el ultimo cuarto el extremo la cruza de banda a banda por
## encima del area y nunca se la da al 9 o al MCO que estan adentro.
##
## Mide cada envio (centro o pelotazo) que sale ABIERTO y a menos de 30 m del
## arco rival: a que rol va, si el receptor estaba en el area o en la otra
## banda, quien estaba en el area, y si la jugada termino en remate.

const SEED := 4400
const PARTIDOS := 30
const DIST_ARCO := 30.0
const ANCHO_BANDA := 11.0
## Tres segundos para rematar despues del envio.
const TICKS_REMATE := 12


func _init() -> void:
	var t := {"envios": {}, "goles": 0, "tiros": 0,
		"centros_intentos": 0, "centros_caidos": 0, "centros_ganados": 0, "cabezazos": 0,
		"en_area_roles": {}, "fotos": 0, "por_rol": {}}
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("A", rng, 0)
		var visita := Team.generar("B", rng, 400)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		_correr(casa, visita, r2, t)
	for tipo in t["envios"]:
		var s: Dictionary = t["envios"][tipo]
		var n: int = maxi(int(s["n"]), 1)
		print("%s: %.2f por partido" % [tipo, float(s["n"]) / PARTIDOS])
		print("  receptor en la otra banda %.0f%%, en el area %.0f%%, remate en 3 s %.0f%%, la pierde %.0f%%" % [
			100.0 * s["otra_banda"] / n, 100.0 * s["area"] / n, 100.0 * s["remate"] / n, 100.0 * s["pierde"] / n])
		print("  a que rol: %s" % str(s["roles"]))
	print("companeros en el area por envio: %s (sobre %d envios)" % [str(t["en_area_roles"]), int(t["fotos"])])
	print("centros por partido: intentos %.2f caidos %.2f ganados %.2f cabezazos %.2f" % [
		float(t["centros_intentos"]) / PARTIDOS, float(t["centros_caidos"]) / PARTIDOS,
		float(t["centros_ganados"]) / PARTIDOS, float(t["cabezazos"]) / PARTIDOS])
	print("con la pelota abierta en zona de centro (%d ticks), donde estan:" % int(t.get("ticks_banda", 0)))
	for rol in t["por_rol"]:
		var r: Dictionary = t["por_rol"][rol]
		var n: int = maxi(int(r["n"]), 1)
		print("  %-9s en el area %3.0f%%  a %4.1f m del fondo  |y| %4.1f" % [
			rol, 100.0 * r["area"] / n, r["x"] / n, r["y"] / n])
	print("goles por partido: %.2f" % [float(t["goles"]) / PARTIDOS])
	quit()


func _correr(home: Team, away: Team, rng: RandomNumberGenerator, t: Dictionary) -> void:
	home.reset_partido()
	away.reset_partido()
	home.local = true
	away.local = false
	home.forma_partido = 0.0
	away.forma_partido = 0.0
	home.clima_partido = Clima.generar(rng)
	away.clima_partido = home.clima_partido
	home.arbitro_partido = Arbitro.generar(rng)
	away.arbitro_partido = home.arbitro_partido
	var estado := MotorEspacial.crear_estado(home, away, rng)
	var pendientes := []
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		for _k in range(MotorEspacial.TICKS_POR_MITAD):
			var quien: int = int(estado["pelota"].get("poseedor_id", -1))
			var fotos := {}
			var pos := Vector2.ZERO
			var local := true
			if quien != -1 and estado["jugadores"].has(quien):
				pos = estado["jugadores"][quien]["pos"]
				local = estado["jugadores"][quien]["equipo_local"]
				for id in estado["jugadores"]:
					fotos[id] = estado["jugadores"][id]["pos"]
			if not fotos.is_empty() and absf(pos.y) >= ANCHO_BANDA and MotorEspacial.valor_posicion(pos, local) >= 0.55:
				t["ticks_banda"] = int(t.get("ticks_banda", 0)) + 1
				for id in fotos:
					var c: Dictionary = estado["jugadores"][id]
					if id == quien or c["equipo_local"] != local or c["rol"] == "ARQ":
						continue
					var dueno_x := absf(MotorEspacial.arco_rival(local).x - pos.x)
					var clave_rol := str(c["rol"])
					if clave_rol == "EXT":
						clave_rol = "EXT_mismo" if fotos[id].y * pos.y > 0.0 else "EXT_otro"
					clave_rol = ("<20 " if dueno_x < 20.0 else ("20-32 " if dueno_x < 32.0 else "32+ ")) + clave_rol
					var r: Dictionary = t["por_rol"].get(clave_rol, {"n": 0, "area": 0, "x": 0.0, "y": 0.0})
					r["n"] += 1
					if MotorEspacial._en_el_area(fotos[id], local):
						r["area"] += 1
					r["x"] += absf(MotorEspacial.arco_rival(local).x - fotos[id].x)
					r["y"] += absf(fotos[id].y)
					t["por_rol"][clave_rol] = r
			var tiros_antes := _tiros(estado)
			estado["ultima_decision"] = {}
			MotorEspacial._tick(estado, false)
			# Cierra los envios que ya tuvieron su ventana.
			var tiros_ahora := _tiros(estado)
			for p in pendientes:
				if tiros_ahora[p["local"]] > int(p["tiros"]):
					p["remate"] = true
				var duenio := int(estado["pelota"].get("poseedor_id", -1))
				if duenio != -1 and not p.has("primer_duenio"):
					p["primer_duenio"] = bool(estado["jugadores"][duenio]["equipo_local"]) == bool(p["local"])
			var siguen := []
			for p in pendientes:
				if int(estado["tick"]) - int(p["tick"]) >= TICKS_REMATE:
					var s: Dictionary = t["envios"][p["tipo"]]
					if bool(p.get("remate", false)):
						s["remate"] += 1
					if p.has("primer_duenio") and not bool(p["primer_duenio"]):
						s["pierde"] += 1
				else:
					siguen.append(p)
			pendientes = siguen

			var d = estado.get("ultima_decision", {})
			if fotos.is_empty() or d == null or d.is_empty():
				continue
			var tipo := str(d["tipo"])
			if not tipo in ["centro", "pase_largo"]:
				continue
			if absf(pos.y) < ANCHO_BANDA or MotorEspacial.valor_posicion(pos, local) < 0.55:
				continue
			var obj := int(estado["pelota"].get("destino_id", -1))
			if obj == -1:
				continue
			var dx := absf(MotorEspacial.arco_rival(local).x - pos.x)
			tipo = tipo + (" <24" if dx < 24.0 else (" 24-35" if dx < 35.0 else " 35+"))
			if not t["envios"].has(tipo):
				t["envios"][tipo] = {"n": 0, "otra_banda": 0, "area": 0, "remate": 0, "pierde": 0, "roles": {}}
			var s: Dictionary = t["envios"][tipo]
			s["n"] += 1
			var pc: Vector2 = fotos[obj]
			if pc.y * pos.y < 0.0 and absf(pc.y) >= ANCHO_BANDA:
				s["otra_banda"] += 1
			if MotorEspacial._en_el_area(pc, local):
				s["area"] += 1
			var rol := str(estado["jugadores"][obj]["rol"])
			s["roles"][rol] = int(s["roles"].get(rol, 0)) + 1
			t["fotos"] += 1
			for id in fotos:
				var c: Dictionary = estado["jugadores"][id]
				if id != quien and c["equipo_local"] == local and MotorEspacial._en_el_area(fotos[id], local):
					t["en_area_roles"][c["rol"]] = int(t["en_area_roles"].get(c["rol"], 0)) + 1
			pendientes.append({"tipo": tipo, "tick": estado["tick"], "local": local, "tiros": tiros_antes[local]})
	t["centros_intentos"] += int(estado["centros"].get("intentos", 0))
	t["centros_caidos"] += int(estado["centros"].get("caidos", 0))
	t["centros_ganados"] += int(estado["centros"].get("ganados", 0))
	t["cabezazos"] += int(estado["centros"].get("cabezazos", 0))
	t["goles"] += home.goles + away.goles


func _tiros(estado: Dictionary) -> Dictionary:
	var tiros = estado["tiros"]
	if tiros is Dictionary and tiros.has("home"):
		return {true: int(tiros["home"]), false: int(tiros["away"])}
	return {true: 0, false: 0}
