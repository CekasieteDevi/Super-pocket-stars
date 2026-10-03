extends SceneTree

## Etapa 8 del Motor V2 (docs/motor_v2.md): el puente MotorV2.simular entrega
## lo mismo que MatchEngine.simular y deja los equipos como los deja un
## partido: goleadores que cierran con el marcador, expulsados suspendidos,
## cambios anotados, energía gastada y eventos que el relato y las
## estadísticas saben leer. Y la receta vuelve a dar el mismo partido.

const SEED := 20261102
const PARTIDOS := 12

var _fallos := 0


func _init() -> void:
	var rojas := 0
	var cambios := 0
	var lesiones := 0
	var relatados := 0
	var quites := 0
	var centros := 0
	var pases_con_minuto := 0
	for n in PARTIDOS:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var home: Team = Team.generar("Local", rng, 0)
		var away: Team = Team.generar("Visitante", rng, 1000)
		var lesionados_antes := home.lesiones.size() + away.lesiones.size()
		var suspendidos_antes := _suma(home.suspendidos) + _suma(away.suspendidos)
		var r: Dictionary = MotorV2.simular(home, away, rng, true)
		var texto := "semilla %d" % (SEED + n)

		for clave in ["goles_local", "goles_visitante", "log", "goles_log", "cancelado", "definicion", "penales", "eventos",
				"fotogramas", "xp", "stats", "receta_v2"]:
			if not r.has(clave):
				_ok(false, "%s: el resultado trae '%s'" % [texto, clave])
		_ok(int(r["goles_local"]) == home.goles and int(r["goles_visitante"]) == away.goles,
			"%s: el marcador es el de los equipos (%d-%d)" % [texto, home.goles, away.goles])
		# Goleadores: uno por gol, del equipo que lo hizo y con un jugador del plantel.
		var por_equipo := {home.nombre: 0, away.nombre: 0}
		var goleadores_bien := true
		for gol in r["goles_log"]:
			por_equipo[str(gol["equipo"])] += 1
			var id := int(gol["jugador_id"])
			if id >= 0 and not _es_de(home if str(gol["equipo"]) == home.nombre else away, id):
				goleadores_bien = false
		_ok(por_equipo[home.nombre] == home.goles and por_equipo[away.nombre] == away.goles and goleadores_bien,
			"%s: los goleadores cierran con el marcador" % texto)

		# Tarjetas: cada roja deja un expulsado y una fecha de suspensión.
		var rojas_partido := 0
		var cambios_partido := 0
		for ev in r["eventos"]:
			if str(ev["tipo"]) == "tarjeta" and str(ev["resultado"]) != "amarilla":
				rojas_partido += 1
			if str(ev["tipo"]) == "cambio":
				cambios_partido += 1
		var expulsados := home.expulsados_partido.size() + away.expulsados_partido.size()
		_ok(expulsados == rojas_partido and _suma(home.suspendidos) + _suma(away.suspendidos) == suspendidos_antes + rojas_partido,
			"%s: %d rojas, %d expulsados y otras tantas suspensiones" % [texto, rojas_partido, expulsados])
		_ok(home.cambios_realizados + away.cambios_realizados == cambios_partido
				and home.cambios_realizados <= Team.MAX_CAMBIOS and away.cambios_realizados <= Team.MAX_CAMBIOS,
			"%s: %d cambios anotados en los equipos" % [texto, cambios_partido])
		rojas += rojas_partido
		cambios += cambios_partido
		lesiones += home.lesiones.size() + away.lesiones.size() - lesionados_antes

		# Energía: los once que arrancaron la gastaron.
		var cansados := 0
		for j in home.jugadores + away.jugadores:
			if float(home.resistencia.get(j["id"], away.resistencia.get(j["id"], 1.0))) < 0.999:
				cansados += 1
		_ok(cansados >= 20, "%s: %d de los 22 titulares terminan con menos energía" % [texto, cansados])

		# Los eventos van en orden y el relato y las estadísticas los leen.
		var en_orden := true
		var paso_previo := -1
		var nombres := RelatoPartido.nombres(home, away)
		for ev in r["eventos"]:
			if int(ev["paso"]) < paso_previo:
				en_orden = false
			paso_previo = int(ev["paso"])
			if RelatoPartido.importancia(ev) > RelatoPartido.NADA and RelatoPartido.linea(ev, nombres) != "":
				relatados += 1
			match str(ev["tipo"]):
				"gambeta": quites += 1
				"centro": centros += 1
				"pase":
					if int(ev["minuto"]) > 0:
						pases_con_minuto += 1
		_ok(en_orden, "%s: los eventos van en orden" % texto)
		var stats: Dictionary = EstadisticasPartido.calcular(r["eventos"], home.nombre, away.nombre)
		var pases := int(stats[home.nombre]["pases_intentados"]) + int(stats[away.nombre]["pases_intentados"])
		var tiros := int(stats[home.nombre]["tiros"]) + int(stats[away.nombre]["tiros"])
		_ok(pases >= 20 and tiros >= 1 and tiros >= home.goles + away.goles,
			"%s: las estadísticas cuentan %d pases y %d tiros" % [texto, pases, tiros])
		_ok(not (r["xp"]["home"] as Dictionary).is_empty() and not (r["xp"]["away"] as Dictionary).is_empty(),
			"%s: hay experiencia para los dos equipos" % texto)
		# La experiencia: nadie pasa de un punto por partido, el que jugó los
		# 90 se lleva uno entero y alguno entrenó algo que su puesto no pide
		# (sale de lo que hizo, no solo del puesto).
		var pesos: Dictionary = PlayerGenerator.get_weights()
		var maximo := 0.0
		var enteros := 0
		var por_accion := 0
		for lado in ["home", "away"]:
			var equipo: Team = home if lado == "home" else away
			for id in r["xp"][lado]:
				var total := 0.0
				var perfil: Dictionary = {}
				for j in equipo.todos_los_jugadores():
					if int(j["id"]) == int(id):
						perfil = pesos.get(j["posicion"], {})
				for a in r["xp"][lado][id]:
					total += float(r["xp"][lado][id][a])
					if float(perfil.get(a, 0.0)) <= 0.0:
						por_accion += 1
				maximo = maxf(maximo, total)
				if absf(total - 1.0) < 0.001:
					enteros += 1
		_ok(maximo <= 1.001 and enteros >= 10 and por_accion > 0,
			"%s: experiencia de a lo sumo 1 punto (%.2f), %d con el partido entero, %d atributos por lo que hicieron" % [
				texto, maximo, enteros, por_accion])

		# La receta da el mismo partido.
		if n < 3:
			var c: Object = CerebroV2.armar_de_receta(r["receta_v2"])
			var pasos := 0
			while str(c.get_estado()["periodo"]) != "terminado" and pasos < MotorV2.PASOS_TOPE:
				c.simular(600)
				pasos += 600
			var goles: PackedInt32Array = c.get_goles()
			_ok(int(goles[0]) == int(r["goles_local"]) and int(goles[1]) == int(r["goles_visitante"])
					and int(c.get_estado()["paso"]) == int(r["stats"]["pasos"]),
				"%s: la receta vuelve a dar el mismo partido" % texto)
	_ok(cambios > 0, "en %d partidos hay cambios (%d)" % [PARTIDOS, cambios])

	# Los modificadores de equipo: el mismo club corre más de local que de
	# visitante, y más con la armonía a favor (MatchEngine.modificador_de_equipo).
	var rng_m := RandomNumberGenerator.new()
	rng_m.seed = SEED + 900
	var a: Team = Team.generar("Local", rng_m, 0)
	var b: Team = Team.generar("Visitante", rng_m, 1000)
	a.reset_partido()
	b.reset_partido()
	a.armonia = 0.0
	b.armonia = 0.0
	a.local = true
	b.local = false
	var de_local := float(CerebroV2.receta(a, b, SEED, true)["titulares"][0][0]["vel_max"])
	var azar := RandomNumberGenerator.new()
	azar.seed = SEED
	var ventaja := MatchEngine.modificador_de_equipo(a, b, azar) - MatchEngine.modificador_de_equipo(b, a, azar)
	a.local = false
	b.local = true
	var de_visitante := float(CerebroV2.receta(a, b, SEED, true)["titulares"][0][0]["vel_max"])
	a.armonia = 5.0
	b.armonia = -5.0
	var con_armonia := float(CerebroV2.receta(a, b, SEED, true)["titulares"][0][0]["vel_max"])
	_ok(ventaja >= 5.0 and de_local > de_visitante and con_armonia > de_visitante,
		"el local tiene %.1f puntos de duelo a favor y corre a %.2f m/s (de visitante, a %.2f; con la armonía a favor, a %.2f)" % [
			ventaja, de_local, de_visitante, con_armonia])
	_ok(relatados > PARTIDOS * 5, "el relato cuenta %d momentos" % relatados)
	_ok(quites > PARTIDOS and centros > 0 and pases_con_minuto > PARTIDOS * 10,
		"el relato tiene %d quites, %d centros y %d pases con su minuto" % [quites, centros, pases_con_minuto])
	print("rojas %d, cambios %d, lesiones %d" % [rojas, cambios, lesiones])

	# Eliminación directa: si empatan, hay tanda y un ganador.
	var definidos := 0
	for n in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + 500 + n
		var home: Team = Team.generar("Local", rng, 0)
		var away: Team = Team.generar("Visitante", rng, 1000)
		var r: Dictionary = MotorV2.simular(home, away, rng, true, true)
		if home.goles != away.goles:
			continue
		var pen: Dictionary = r["penales"]
		_ok(str(r["definicion"]) == "penales" and not pen.is_empty() and pen["ganador"] != null
				and int(pen["goles_local"]) != int(pen["goles_visitante"]) and (pen["tandas"] as Array).size() >= 5,
			"semilla %d: el empate se define por penales (%s)" % [SEED + 500 + n,
				"%d-%d" % [pen.get("goles_local", 0), pen.get("goles_visitante", 0)]])
		definidos += 1
	_ok(definidos > 0, "en 30 cruces hay empates que van a penales (%d)" % definidos)
	print("FALLOS=%d" % _fallos)
	quit()


func _suma(d: Dictionary) -> int:
	var total := 0
	for k in d:
		total += int(d[k])
	return total


func _es_de(equipo: Team, id: int) -> bool:
	for j in equipo.todos_los_jugadores():
		if int(j["id"]) == id:
			return true
	return false


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: %s" % texto)
	else:
		print("FALLA: %s" % texto)
		_fallos += 1
