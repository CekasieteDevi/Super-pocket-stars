extends SceneTree

## Etapa 8 del Motor V2 (docs/motor_v2.md): las jugadas preparadas
## (core/jugadas.gd) salen en el motor nuevo. El club que sabe el córner
## corto, el córner en bloque o el amague de tiro libre los usa en su pelota
## parada; el que no los sabe, nunca. La defensa adelantada y la presión tras
## pérdida entran por el plan del equipo. El puente las deja en los eventos
## para el relato.

const SEED := 20261501
const PARADAS := 24
## Pasos después del saque en los que se mira qué hizo el socio.
const VENTANA_PASOS := 240
const DEC_PASE := 2
const DEC_CENTRO := 5

var _fallos := 0


func _init() -> void:
	# Con el uso en 1 la jugada sale en cada pelota parada.
	for id in Jugadas.USO:
		Jugadas.USO[id] = 1.0

	# El plan: lo que el club sabe llega al motor; si el rival también la
	# sabe, la mitad (Jugadas.LECTURA_DEL_RIVAL).
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var a: Team = Team.generar("Local", rng, 0)
	var b: Team = Team.generar("Visitante", rng, 1000)
	a.jugadas_aprendidas.clear()
	b.jugadas_aprendidas.clear()
	var sin: Dictionary = CerebroV2.plan_de(a, b)
	_ok(float(sin["paso_defensa"]) == 0.0 and float(sin["contrapresion"]) == 0.0 and float(sin["corner_corto"]) == 0.0
			and float(sin["corner_bloque"]) == 0.0 and float(sin["amague"]) == 0.0,
		"el club que no sabe jugadas tiene el plan en cero")
	a.jugadas_aprendidas = Jugadas.LISTA.duplicate()
	var con: Dictionary = CerebroV2.plan_de(a, b)
	_ok(is_equal_approx(float(con["paso_defensa"]), Jugadas.PASO_DEFENSA)
			and is_equal_approx(float(con["contrapresion"]), Jugadas.RADIO_CONTRAPRESION - 1.0)
			and float(con["corner_corto"]) == 1.0 and float(con["corner_bloque"]) == 1.0 and float(con["amague"]) == 1.0,
		"el club que las sabe las lleva en el plan (paso de la defensa %.1f m)" % float(con["paso_defensa"]))
	b.jugadas_aprendidas = [Jugadas.DEFENSA_ADELANTADA]
	_ok(is_equal_approx(float(CerebroV2.plan_de(a, b)["paso_defensa"]), Jugadas.PASO_DEFENSA * Jugadas.LECTURA_DEL_RIVAL),
		"si el rival también la sabe, la ventaja es la mitad")

	# Pelota parada: sin la jugada no sale nunca; con ella, siempre.
	for caso in [["corner", Jugadas.CORNER_CORTO, 1], ["corner", Jugadas.CORNER_BLOQUE, 2],
			["tiro_libre", Jugadas.AMAGUE, 3]]:
		var base := _forzar(caso[0], "", int(caso[2]))
		_ok(int(base["sacadas"]) >= PARADAS - 4 and int(base["jugadas"]) == 0,
			"%s sin la jugada: %d sacadas y ninguna jugada" % [caso[0], base["sacadas"]])
		var r := _forzar(caso[0], caso[1], int(caso[2]))
		# El bloque sale siempre. El córner corto y el amague, si el socio
		# llegó a su lugar; el amague, además, solo en el tiro libre que va al
		# arco (no todos los forzados lo son).
		var minimo := int(r["sacadas"]) - 2 if caso[1] == Jugadas.CORNER_BLOQUE else int(r["sacadas"]) / 2
		_ok(int(r["sacadas"]) >= PARADAS - 4 and int(r["jugadas"]) >= minimo,
			"%s: sale en %d de %d" % [caso[1], r["jugadas"], r["sacadas"]])
		match str(caso[1]):
			Jugadas.CORNER_CORTO:
				_ok(int(r["al_socio"]) >= int(r["jugadas"]) * 0.7 and int(r["centra_socio"]) >= int(r["jugadas"]) * 0.4,
					"córner corto: el saque va al socio %d veces y el socio centra %d" % [r["al_socio"], r["centra_socio"]])
			Jugadas.CORNER_BLOQUE:
				_ok(float(r["bloque_lejos"]) >= 3.0,
					"córner en bloque: %.1f se juntan en el segundo palo antes del saque" % float(r["bloque_lejos"]))
			Jugadas.AMAGUE:
				# A veces el pase lo toca otro compañero que queda en el camino.
				_ok(int(r["al_socio"]) >= int(r["jugadas"]) * 0.6 and int(r["remata_socio"]) >= int(r["jugadas"]) * 0.4,
					"amague: el saque va al socio %d veces y el socio remata %d" % [r["al_socio"], r["remata_socio"]])

	# Los pateadores que elige el club (Equipo > Roles): el córner, el tiro
	# libre y el penal los saca el elegido, no el mejor de los que están cerca.
	for caso in [["corner", Roles.CORNERS], ["tiro_libre", Roles.LIBRES_CERCA], ["penal", Roles.PENALES]]:
		var del_elegido := 0
		var sacados := 0
		for k in 8:
			var rng_r := RandomNumberGenerator.new()
			rng_r.seed = SEED + 300 + k
			var home: Team = Team.generar("Local", rng_r, 0)
			var away: Team = Team.generar("Visitante", rng_r, 1000)
			home.jugadas_aprendidas.clear()
			away.jugadas_aprendidas.clear()
			# El peor en eso de los que juegan del medio para arriba (los de
			# atrás quedan a más de 80 m del córner): nunca es el que el
			# motor elegiría solo.
			var elegido := -1
			var peor := INF
			for j in home.jugadores:
				if str(j["posicion"]) in ["ARQ", "DFC", "LAT"]:
					continue
				var valor := float(j["atributos"][Roles.ATRIBUTO[caso[1]]])
				if valor < peor:
					peor = valor
					elegido = int(j["id"])
			Roles.asignar(home, caso[1], elegido)
			home.reset_partido()
			away.reset_partido()
			var c: Object = CerebroV2.armar(home, away, SEED + 300 + k, true)
			c.simular(60 * 8)
			var en := Vector2(ProyeccionPartido.MEDIO_LARGO, ProyeccionPartido.MEDIO_ANCHO)
			if caso[0] == "tiro_libre":
				en = Vector2(ProyeccionPartido.MEDIO_LARGO - 20.0, 0.0)
			elif caso[0] == "penal":
				en = Vector2(ProyeccionPartido.MEDIO_LARGO - 11.0, 0.0)
			if not c.forzar_parada(caso[0], 0, en):
				continue
			var antes: int = (c.eventos() as Array).size()
			for paso in 60 * 30:
				c.avanzar()
				var saco := false
				for ev in (c.eventos() as Array).slice(antes):
					if str(ev["tipo"]) == "saque":
						saco = true
						sacados += 1
						if int(ev["jugador"]) == elegido:
							del_elegido += 1
				if saco:
					break
		# El tiro libre no siempre va al arco: si al elegido no le da la
		# pierna se cuelga o se juega corto, y eso lo saca otro.
		var minimo := sacados / 2 if caso[0] == "tiro_libre" else sacados - 2
		_ok(sacados >= 6 and del_elegido >= minimo,
			"%s: el elegido por el club saca %d de %d" % [caso[0], del_elegido, sacados])

	# El puente: el relato cuenta las jugadas.
	var relatadas := {}
	for n in 10:
		var rng_p := RandomNumberGenerator.new()
		rng_p.seed = SEED + 100 + n
		var home: Team = Team.generar("Local", rng_p, 0)
		var away: Team = Team.generar("Visitante", rng_p, 1000)
		home.jugadas_aprendidas = Jugadas.LISTA.duplicate()
		var res: Dictionary = MotorV2.simular(home, away, rng_p, true)
		var nombres := VistaPartido.construir_nombres(home, away)
		for ev in res["eventos"]:
			if str(ev["tipo"]) != "jugada":
				continue
			var id := str(ev.get("jugada", ""))
			if not Jugadas.existe(id) or RelatoPartido.linea(ev, nombres) == "":
				_ok(false, "el evento de jugada '%s' se puede relatar" % id)
			relatadas[id] = int(relatadas.get(id, 0)) + 1
	_ok(relatadas.has(Jugadas.CONTRAPRESION) and relatadas.has(Jugadas.DEFENSA_ADELANTADA),
		"en 10 partidos el relato cuenta jugadas: %s" % str(relatadas))
	print("FALLOS=%d" % _fallos)
	quit()


## Fuerza PARADAS pelotas paradas del local (que sabe `jugada`, o ninguna) y
## cuenta qué pasó. `detalle`: la Jugada del motor que se espera.
func _forzar(tipo: String, jugada: String, detalle: int) -> Dictionary:
	var r := {"sacadas": 0, "jugadas": 0, "al_socio": 0, "centra_socio": 0, "remata_socio": 0, "bloque_lejos": 0.0}
	for k in PARADAS:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + k
		var home: Team = Team.generar("Local", rng, 0)
		var away: Team = Team.generar("Visitante", rng, 1000)
		home.jugadas_aprendidas.clear()
		away.jugadas_aprendidas.clear()
		if jugada != "":
			home.jugadas_aprendidas.append(jugada)
		home.reset_partido()
		away.reset_partido()
		var c: Object = CerebroV2.armar(home, away, SEED + k, true)
		c.simular(60 * 8)
		var lado := 1.0 if k % 2 == 0 else -1.0
		var en := Vector2(ProyeccionPartido.MEDIO_LARGO, lado * ProyeccionPartido.MEDIO_ANCHO) if tipo == "corner" \
			else Vector2(ProyeccionPartido.MEDIO_LARGO - 20.0 - float(k % 5), lado * float(k % 7))
		if not c.forzar_parada(tipo, 0, en):
			continue
		var eventos_antes: int = (c.eventos() as Array).size()
		var pases_antes: int = (c.registro_pases() as Array).size()
		var remates_antes: int = (c.registro_remates() as Array).size()
		var saque := {}
		var lejos := 0
		for paso in 60 * 25:
			# Antes del saque: cuántos del local esperan del lado del segundo
			# palo, entre 5 y 9 m del medio del arco.
			var cuantos := 0
			var pos: PackedVector2Array = c.get_pos()
			var equipos: PackedInt32Array = c.get_equipos()
			for i in pos.size():
				if equipos[i] == 0 and pos[i].x > ProyeccionPartido.MEDIO_LARGO - 12.0 and -lado * pos[i].y >= 5.0 \
						and -lado * pos[i].y <= 9.5:
					cuantos += 1
			c.avanzar()
			var eventos: Array = c.eventos()
			for q in range(eventos_antes, eventos.size()):
				if str(eventos[q]["tipo"]) == "saque":
					saque = eventos[q]
			if not saque.is_empty():
				lejos = cuantos
				break
		if saque.is_empty():
			continue
		r["sacadas"] += 1
		r["bloque_lejos"] += float(lejos)
		c.simular(VENTANA_PASOS)
		var socio := -1
		for ev in (c.eventos() as Array).slice(eventos_antes):
			if str(ev["tipo"]) == "jugada" and int(ev["equipo"]) == 0 and int(ev["detalle"]) == detalle:
				r["jugadas"] += 1
				socio = int(ev["otro"])
				break
		if socio < 0:
			continue
		var pases: Array = (c.registro_pases() as Array).slice(pases_antes)
		if not pases.is_empty() and int(pases[0]["tipo"]) == DEC_PASE and int(pases[0]["toca_id"]) == socio:
			r["al_socio"] += 1
		for p in pases:
			if int(p["pateador_id"]) == socio and int(p["tipo"]) == DEC_CENTRO:
				r["centra_socio"] += 1
				break
		for t in (c.registro_remates() as Array).slice(remates_antes):
			if int(t["pateador_id"]) == socio:
				r["remata_socio"] += 1
				break
	r["bloque_lejos"] = float(r["bloque_lejos"]) / maxf(float(r["sacadas"]), 1.0)
	return r


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: %s" % texto)
	else:
		print("FALLA: %s" % texto)
		_fallos += 1
