class_name CerebroV2
extends RefCounted

## Arma el partido de la etapa 4 del Motor V2 (docs/motor_v2.md): 11 contra 11
## en CanchitaV2Nativa (modo PARTIDO) con el cerebro en C++
## (motor_v2/cpp/src/cerebro/). Acá solo se juntan los datos que ya existen
## en GDScript, igual que para el motor espacial: los pesos de
## data/utility_pesos.json, el plan del estilo de cada club y la ficha de cada
## jugador. Todo lo que pasa durante el partido lo decide el C++.


## Los dos clubes, de la semilla: planteles con Team.generar (los mismos que
## usa el juego) y estilos distintos para que se vea la diferencia. Con
## `division_local` y `division_visitante` (0 = primera) los planteles salen
## del nivel de esa división, como en tests/_diag_embudo_remates.gd.
##
## Etapa 6: con `reglas` el partido tiene reloj, reanudaciones, faltas,
## tarjetas, cambios y lesiones (motor_v2/cpp/src/reglas.h); con `tanda`, el
## empate se define por penales.
static func armar_partido(semilla: int, estilo_local := "", estilo_visitante := "",
		division_local := -1, division_visitante := -1, reglas := false, tanda := false) -> Object:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local: Team
	var visitante: Team
	if division_local >= 0:
		local = Team.generar("Local", rng, 0, NivelDivision.potencial(division_local), "Uruguay",
			NivelDivision.realizacion(division_local))
		visitante = Team.generar("Visitante", rng, 1000, NivelDivision.potencial(division_visitante), "Uruguay",
			NivelDivision.realizacion(division_visitante))
	else:
		local = Team.generar("Local", rng)
		visitante = Team.generar("Visitante", rng, 1000)
	if estilo_local != "":
		local.estilo = estilo_local
	if estilo_visitante != "":
		visitante.estilo = estilo_visitante
	return armar(local, visitante, semilla, reglas, tanda)


## El local (equipo 0) ataca hacia +x. Van los once de Team.jugadores en el
## orden de Formaciones.slots: el slot i lo ocupa jugadores[i]. Con `reglas`
## (etapa 6) cada uno lleva lo que leen las reglas (FisicaV2.reglas_de) y el
## banco (Team.banco) va como suplentes.
static func armar(local: Team, visitante: Team, semilla: int, reglas := false, tanda := false) -> Object:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	c.configurar(FisicaV2.parametros(), FisicaV2.parametros_cuerpo(), FisicaV2.clips(), FisicaV2.parametros_toque())
	c.configurar_cerebro(MotorEspacial.pesos(), FisicaV2.parametros_cerebro())
	c.configurar_remate(FisicaV2.parametros_remate(), FisicaV2.parametros_arquero())
	if reglas:
		c.configurar_reglas(FisicaV2.parametros_reglas(tanda))
	var nivel := MatchEngine.nivel_partido(local, visitante)
	var equipos := [local, visitante]
	for e in 2:
		var equipo: Team = equipos[e]
		var rival: Team = equipos[1 - e]
		c.configurar_plan(e, plan_de(equipo, rival))
		if reglas:
			c.configurar_reglas_equipo(e, FisicaV2.reglas_del_club(equipo))
		var slots := Formaciones.slots(equipo.formacion)
		# Etapa 7: el equipo que es mejor que el nivel del partido llega antes
		# a todo. Es del equipo entero: por jugador, en un partido parejo el
		# mejor corría a 11,4 m/s y el peor a 3,4.
		var puntos := equipo.media_equipo() - nivel
		var ventaja := FisicaV2.ventaja_de_nivel(puntos, nivel)
		for i in mini(equipo.jugadores.size(), slots.size()):
			var f := ficha_de(equipo.jugadores[i], str(slots[i]["rol"]), slots[i]["base"], nivel, ventaja, puntos)
			if reglas:
				f["reglas"] = FisicaV2.reglas_de(equipo.jugadores[i], equipo, rival)
			c.agregar(e, f)
		if reglas:
			for j in equipo.banco:
				var f := ficha_de(j, str(j["posicion"]), Vector2.ZERO, nivel, ventaja, puntos)
				f["reglas"] = FisicaV2.reglas_de(j, equipo, rival)
				c.agregar_suplente(e, f)
	c.empezar(CanchitaV2Nativa.PARTIDO, semilla)
	return c


## El plan de juego del estilo (Estilos) y las jugadas de juego abierto que
## sabe el club (Jugadas), como los lee MotorEspacial.
static func plan_de(equipo: Team, rival: Team) -> Dictionary:
	var p: Dictionary = Estilos.plan(equipo.estilo).duplicate()
	p["retroceso"] = Estilos.retroceso_sin_pelota(equipo.estilo) - Estilos.RETROCESO_DEFAULT
	p["acompanamiento"] = Estilos.acompanamiento(equipo.estilo) / Estilos.ACOMPANAMIENTO_DEFAULT
	p["intencion_centro"] = Estilos.intencion_centro(equipo.estilo)
	p["contragolpe"] = equipo.estilo == "Contragolpe"
	p["presion_alta"] = equipo.estilo == "Presión alta"
	p["defensivo"] = equipo.estilo == "Defensivo"
	p["extra_pared"] = Jugadas.UTILIDAD_PARED * Jugadas.factor(equipo, rival, Jugadas.PAREDES)
	p["extra_contragolpe"] = Jugadas.EXTRA_CONTRAGOLPE * Jugadas.factor(equipo, rival, Jugadas.CONTRAGOLPE)
	p["rasgo_dt"] = str(equipo.dt.get("rasgo", "")) if not equipo.dt.is_empty() else ""
	return p


## Lo que necesitan el cuerpo (FisicaV2.jugador_de) y el cerebro: rol y
## casillero del slot, los atributos tal cual y relativos al nivel del partido
## (MatchEngine.relativo_al_nivel) y los rasgos que cambian decisiones.
##
## `ventaja` (etapa 7): FisicaV2.ventaja_de_nivel del equipo. Multiplica la
## punta y la aceleración.
## `puntos`: los puntos de media que el equipo le saca al nivel del partido.
## Corren los pases y el control (FisicaV2.tecnica_de_nivel).
static func ficha_de(jugador: Dictionary, rol: String, base: Vector2, nivel: float, ventaja := 1.0, puntos := 0.0) -> Dictionary:
	var atributos: Dictionary = jugador["atributos"]
	var f := FisicaV2.jugador_de(atributos)
	f["vel_max"] = float(f["vel_max"]) * ventaja
	f["aceleracion"] = float(f["aceleracion"]) * ventaja
	var tecnica := FisicaV2.tecnica_de_nivel(puntos, nivel)
	f["pases"] = clampf(float(f["pases"]) + tecnica, 0.0, 100.0)
	f["control"] = clampf(float(f["control"]) + tecnica, 0.0, 100.0)
	var relativos := {}
	for clave in atributos:
		relativos[clave] = MatchEngine.relativo_al_nivel(float(atributos[clave]), nivel)
	# Etapa 7: los reflejos del arquero no son solo relativos al partido. El de
	# primera reacciona antes que el de décima también en un partido parejo.
	if relativos.has("reflejos"):
		relativos["reflejos"] = lerpf(float(relativos["reflejos"]), float(atributos["reflejos"]),
			float(FisicaV2.datos()["nivel"]["mezcla_reflejos"]))
	f["rol"] = rol
	f["base"] = base
	f["atributos"] = atributos
	f["relativos"] = relativos
	f["creador"] = Personalidad.tiene(jugador, "Creador")
	f["metodico"] = Personalidad.tiene(jugador, "Metodico")
	f["egoista"] = Personalidad.tiene(jugador, "Egoista")
	f["pie_malo_lado"] = Personalidad.pie_preferido(jugador) if Personalidad.tiene(jugador, "Pie preferido") else 0
	f["margen_offside"] = MotorEspacial.FACTOR_OFFSIDE_ENFOCADO if Personalidad.tiene(jugador, "Enfocado") else 1.0
	return f
