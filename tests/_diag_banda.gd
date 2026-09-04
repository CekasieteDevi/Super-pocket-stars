extends SceneTree

## Juego de banda: que hace el que recibe la pelota ABIERTO y en campo
## rival. Mide cuanto se mete hacia el medio mientras la lleva, desde que
## altura cuelga los centros y cuantos centros salen por partido.
##
## El reclamo: el extremo recibe en la banda y en vez de correr la linea
## hasta la altura del area, arranca en diagonal hacia el arco desde el
## primer toque. `_conducir` apunta al arco para los once roles.

const SEED := 4400
const PARTIDOS := 10
## Mismo umbral que usa `puede_centrar` para decidir que estas abierto.
const ANCHO_BANDA := 11.0
const AVANCE_MINIMO := 0.5


func _init() -> void:
	var y_al_recibir := 0.0
	var y_al_soltar := 0.0
	var conducciones := 0
	var centros := 0
	var dist_centro := 0.0
	var por_rol := {}
	var ticks := 0
	var avance := 0.0
	var abiertos := 0
	var gambetas := 0
	var decisiones := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("A", rng, 0)
		var visita := Team.generar("B", rng, 400)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := _correr(casa, visita, r2, por_rol)
		y_al_recibir += res[0]
		y_al_soltar += res[1]
		conducciones += int(res[2])
		centros += int(res[3])
		dist_centro += res[4]
		ticks += int(res[5])
		avance += res[6]
		abiertos += int(res[7])
		gambetas += int(res[8])
		decisiones += int(res[9])
	print("conducciones abiertas: %d en %d partidos" % [conducciones, PARTIDOS])
	if conducciones > 0:
		print("  |y| al recibir: %.1f m   |y| al soltarla: %.1f m   (se mete %.1f m)" % [
			y_al_recibir / conducciones, y_al_soltar / conducciones,
			(y_al_recibir - y_al_soltar) / conducciones])
		print("  dura %.1f s y avanza %.1f m hacia el arco" % [
			float(ticks) / conducciones * MotorEspacial.TICK_SEG,
			avance / conducciones])
		print("  termina todavia abierta: %.0f%%" % [
			100.0 * float(abiertos) / conducciones])
	print("desde la banda y adelantado: %d decisiones, %d gambetas (%.1f%%), %.1f por partido" % [
		decisiones, gambetas, 100.0 * float(gambetas) / maxf(float(decisiones), 1.0),
		float(gambetas) / PARTIDOS])
	print("centros: %.1f por partido, colgados a %.1f m del arco" % [
		float(centros) / PARTIDOS, dist_centro / maxf(float(centros), 1.0)])
	print("  quien lleva la pelota abierto:")
	for rol in por_rol:
		print("    %-4s %d" % [rol, int(por_rol[rol])])
	quit()


func _correr(home: Team, away: Team, rng: RandomNumberGenerator, por_rol: Dictionary) -> Array:
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
	var y_rec := 0.0
	var y_sol := 0.0
	var n := 0
	var centros := 0
	var dist := 0.0
	# Clave del que venia llevandola abierto, y donde la recibio.
	var actual := -1
	var y_inicial := 0.0
	var x_inicial := 0.0
	var t_inicial := 0
	var ticks_total := 0
	var avance_total := 0.0
	var siguen_abiertos := 0
	var gambetas_banda := 0
	var decisiones_banda := 0
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		estado["ultima_decision"] = {}
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			var antes: int = int(estado["centros"].get("intentos", 0))
			var quien: int = int(estado["pelota"].get("poseedor_id", -1))
			MotorEspacial._tick(estado, false)
			# Que decidio el que la tenia ABIERTO y adelantado.
			var d = estado.get("ultima_decision", {})
			if d != null and not d.is_empty() and quien != -1 					and estado["jugadores"].has(quien):
				estado["ultima_decision"] = {}
				var q: Dictionary = estado["jugadores"][quien]
				var ql: bool = bool(q["equipo_local"])
				if absf(float(q["pos"].y)) >= ANCHO_BANDA 						and MotorEspacial.valor_posicion(q["pos"], ql) >= AVANCE_MINIMO:
					decisiones_banda += 1
					if str(d["tipo"]) == "gambeta":
						gambetas_banda += 1
			var pelota: Dictionary = estado["pelota"]
			# Un centro nuevo: donde estaba el que lo colgo.
			if int(estado["centros"].get("intentos", 0)) > antes:
				centros += 1
				var arco := MotorEspacial.arco_rival(bool(pelota["pasador_local"]))
				dist += absf(arco.x - float(pelota["origen_pos"].x))
			var duenio: int = int(pelota.get("poseedor_id", -1))
			if duenio == -1:
				continue
			var e: Dictionary = estado["jugadores"][duenio]
			var local: bool = bool(e["equipo_local"])
			var abierto: bool = absf(e["pos"].y) >= ANCHO_BANDA \
				and MotorEspacial.valor_posicion(e["pos"], local) >= AVANCE_MINIMO
			if duenio != actual:
				# Cambio de dueño: cierra la conduccion anterior.
				if actual != -1 and estado["jugadores"].has(actual):
					var ant: Dictionary = estado["jugadores"][actual]
					y_sol += absf(float(ant["pos"].y))
					ticks_total += int(estado["tick"]) - t_inicial
					avance_total += absf(float(ant["pos"].x) - x_inicial)
					if absf(float(ant["pos"].y)) >= ANCHO_BANDA:
						siguen_abiertos += 1
					n += 1
				actual = -1
				if abierto:
					actual = duenio
					y_inicial = absf(float(e["pos"].y))
					x_inicial = float(e["pos"].x)
					t_inicial = int(estado["tick"])
					y_rec += y_inicial
					por_rol[str(e["rol"])] = int(por_rol.get(str(e["rol"]), 0)) + 1
	return [y_rec, y_sol, n, centros, dist, ticks_total, avance_total, siguen_abiertos,
		gambetas_banda, decisiones_banda]
