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
	return armar_de_receta(receta(local, visitante, semilla, reglas, tanda))


## Etapa 8: todo lo que hace falta para armar un partido, como datos. Con la
## misma receta sale el mismo partido: el juego lo simula entero sin vista
## para tener el resultado y la pantalla lo vuelve a armar para mirarlo. Los
## equipos (Team) cambian con el partido (energía, lesiones, cambios); la
## receta es la foto de antes.
##
## `calidad_cancha` y `clima`: los de FisicaV2.parametros (el césped del local
## y el clima del partido). Sin ellos, la pelota de fábrica.
## `alargue`: el empate juega antes dos tiempos de alargue (los cruces del juego).
static func receta(local: Team, visitante: Team, semilla: int, reglas := false, tanda := false,
		calidad_cancha := 0.0, clima := "", alargue := false) -> Dictionary:
	var r := {
		"semilla": semilla,
		"pelota": FisicaV2.parametros(calidad_cancha, clima),
		"cuerpo": FisicaV2.parametros_cuerpo(),
		"clips": FisicaV2.clips(),
		"toque": FisicaV2.parametros_toque(),
		"pesos": BasePartido.pesos(),
		"cerebro": FisicaV2.parametros_cerebro(),
		"remate": FisicaV2.parametros_remate(),
		"arquero": FisicaV2.parametros_arquero(),
		"reglas": FisicaV2.parametros_reglas(tanda, alargue) if reglas else {},
		"planes": [], "clubes": [], "titulares": [[], []], "suplentes": [[], []],
	}
	var nivel := MatchEngine.nivel_partido(local, visitante)
	var equipos := [local, visitante]
	# Los modificadores de equipo (localía, forma del día, armonía, racha,
	# familiaridad, estilos, clima, público...). El motor no resuelve duelos:
	# entran como puntos de media del que tiene más contra el que tiene menos.
	# Con su propio azar (el clásico tira una variación): el del partido queda
	# para el motor.
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var modificador := [MatchEngine.modificador_de_equipo(local, visitante, azar),
		MatchEngine.modificador_de_equipo(visitante, local, azar)]
	var modificador_medio: float = (modificador[0] + modificador[1]) * 0.5
	for e in 2:
		var equipo: Team = equipos[e]
		var rival: Team = equipos[1 - e]
		r["planes"].append(plan_de(equipo, rival))
		r["clubes"].append(FisicaV2.reglas_del_club(equipo) if reglas else {})
		var slots := Formaciones.slots(equipo.formacion)
		# Etapa 7: el equipo que es mejor que el nivel del partido llega antes
		# a todo. Es del equipo entero: por jugador, en un partido parejo el
		# mejor corría a 11,4 m/s y el peor a 3,4.
		var puntos := equipo.media_equipo() - nivel + FisicaV2.puntos_de_modificador(modificador[e] - modificador_medio)
		var ventaja := FisicaV2.ventaja_de_nivel(puntos, nivel)
		for i in mini(equipo.jugadores.size(), slots.size()):
			# El que no puede jugar (lesionado o suspendido) deja el puesto
			# vacío: el equipo sale con uno menos, como en Team.reset_partido.
			if not equipo.puede_jugar(int(equipo.jugadores[i]["id"])):
				continue
			var f := ficha_de(equipo.jugadores[i], str(slots[i]["rol"]), slots[i]["base"], nivel, ventaja, puntos)
			if reglas:
				f["reglas"] = FisicaV2.reglas_de(equipo.jugadores[i], equipo, rival)
			r["titulares"][e].append(f)
		if reglas:
			for j in equipo.banco:
				if not equipo.puede_jugar(int(j["id"])):
					continue
				var f := ficha_de(j, str(j["posicion"]), Vector2.ZERO, nivel, ventaja, puntos)
				f["reglas"] = FisicaV2.reglas_de(j, equipo, rival)
				r["suplentes"][e].append(f)
	return r


## El partido de una receta, listo para avanzar.
static func armar_de_receta(r: Dictionary) -> Object:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	c.configurar(r["pelota"], r["cuerpo"], r["clips"], r["toque"])
	c.configurar_cerebro(r["pesos"], r["cerebro"])
	c.configurar_remate(r["remate"], r["arquero"])
	var reglas: bool = not (r["reglas"] as Dictionary).is_empty()
	if reglas:
		c.configurar_reglas(r["reglas"])
	for e in 2:
		c.configurar_plan(e, r["planes"][e])
		if reglas:
			c.configurar_reglas_equipo(e, r["clubes"][e])
		for f in r["titulares"][e]:
			c.agregar(e, f)
		for f in r["suplentes"][e]:
			c.agregar_suplente(e, f)
	c.empezar(CanchitaV2Nativa.PARTIDO, int(r["semilla"]))
	return c


## La clave del plan (PlanEquipo, en C++) de cada jugada de pelota parada.
const CLAVE_DE_JUGADA := {Jugadas.CORNER_CORTO: "corner_corto", Jugadas.CORNER_BLOQUE: "corner_bloque",
	Jugadas.AMAGUE: "amague"}


## El plan de juego del estilo (Estilos) y las jugadas que sabe el club
## (Jugadas).
static func plan_de(equipo: Team, rival: Team) -> Dictionary:
	var p: Dictionary = Estilos.plan(equipo.estilo).duplicate()
	p["retroceso"] = Estilos.retroceso_sin_pelota(equipo.estilo) - Estilos.RETROCESO_DEFAULT
	p["acompanamiento"] = Estilos.acompanamiento(equipo.estilo) / Estilos.ACOMPANAMIENTO_DEFAULT
	p["intencion_centro"] = Estilos.intencion_centro(equipo.estilo)
	p["pique"] = Estilos.pique_a_la_espalda(equipo.estilo)
	p["contragolpe"] = equipo.estilo == "Contragolpe"
	p["presion_alta"] = equipo.estilo == "Presión alta"
	p["defensivo"] = equipo.estilo == "Defensivo"
	p["extra_pared"] = Jugadas.UTILIDAD_PARED * Jugadas.factor(equipo, rival, Jugadas.PAREDES)
	p["extra_contragolpe"] = Jugadas.EXTRA_CONTRAGOLPE * Jugadas.factor(equipo, rival, Jugadas.CONTRAGOLPE)
	p["paso_defensa"] = Jugadas.PASO_DEFENSA * Jugadas.factor(equipo, rival, Jugadas.DEFENSA_ADELANTADA)
	p["contrapresion"] = (Jugadas.RADIO_CONTRAPRESION - 1.0) * Jugadas.factor(equipo, rival, Jugadas.CONTRAPRESION)
	# Las de pelota parada: la probabilidad de usarla si el club la sabe.
	for id in [Jugadas.CORNER_CORTO, Jugadas.CORNER_BLOQUE, Jugadas.AMAGUE]:
		p[CLAVE_DE_JUGADA[id]] = float(Jugadas.USO[id]) if Jugadas.sabe(equipo, id) else 0.0
	p["rasgo_dt"] = str(equipo.dt.get("rasgo", "")) if not equipo.dt.is_empty() else ""
	return p


## Lo que necesitan el cuerpo (FisicaV2.jugador_de) y el cerebro: rol y
## casillero del slot, los atributos tal cual y relativos al nivel del partido
## (MatchEngine.relativo_al_nivel) y los rasgos que cambian decisiones.
##
## `ventaja` (etapa 7): FisicaV2.ventaja_de_nivel del equipo. Multiplica la
## aceleración; la punta, con el tope de FisicaV2.punta_de_nivel.
## `puntos`: los puntos de media que el equipo le saca al nivel del partido.
## Corren los pases y el control (FisicaV2.tecnica_de_nivel).
static func ficha_de(jugador: Dictionary, rol: String, base: Vector2, nivel: float, ventaja := 1.0, puntos := 0.0) -> Dictionary:
	var atributos: Dictionary = jugador["atributos"]
	var f := FisicaV2.jugador_de(atributos)
	f["vel_max"] = float(f["vel_max"]) * FisicaV2.punta_de_nivel(puntos, nivel)
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
	f["margen_offside"] = BasePartido.FACTOR_OFFSIDE_ENFOCADO if Personalidad.tiene(jugador, "Enfocado") else 1.0
	return f
