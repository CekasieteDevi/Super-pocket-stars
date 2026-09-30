class_name CerebroV2
extends RefCounted

## Arma el partido de la etapa 4 del Motor V2 (docs/motor_v2.md): 11 contra 11
## en CanchitaV2Nativa (modo PARTIDO) con el cerebro en C++
## (motor_v2/cpp/src/cerebro/). Acá solo se juntan los datos que ya existen
## en GDScript, igual que para el motor espacial: los pesos de
## data/utility_pesos.json, el plan del estilo de cada club y la ficha de cada
## jugador. Todo lo que pasa durante el partido lo decide el C++.


## Los dos clubes, de la semilla: planteles con Team.generar (los mismos que
## usa el juego) y estilos distintos para que se vea la diferencia.
static func armar_partido(semilla: int, estilo_local := "", estilo_visitante := "") -> Object:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local := Team.generar("Local", rng)
	var visitante := Team.generar("Visitante", rng, 1000)
	if estilo_local != "":
		local.estilo = estilo_local
	if estilo_visitante != "":
		visitante.estilo = estilo_visitante
	return armar(local, visitante, semilla)


## El local (equipo 0) ataca hacia +x. Van los once de Team.jugadores en el
## orden de Formaciones.slots: el slot i lo ocupa jugadores[i].
static func armar(local: Team, visitante: Team, semilla: int) -> Object:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	c.configurar(FisicaV2.parametros(), FisicaV2.parametros_cuerpo(), FisicaV2.clips(), FisicaV2.parametros_toque())
	c.configurar_cerebro(MotorEspacial.pesos(), FisicaV2.parametros_cerebro())
	var nivel := MatchEngine.nivel_partido(local, visitante)
	var equipos := [local, visitante]
	for e in 2:
		var equipo: Team = equipos[e]
		c.configurar_plan(e, plan_de(equipo, equipos[1 - e]))
		var slots := Formaciones.slots(equipo.formacion)
		for i in mini(equipo.jugadores.size(), slots.size()):
			c.agregar(e, ficha_de(equipo.jugadores[i], str(slots[i]["rol"]), slots[i]["base"], nivel))
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
static func ficha_de(jugador: Dictionary, rol: String, base: Vector2, nivel: float) -> Dictionary:
	var atributos: Dictionary = jugador["atributos"]
	var f := FisicaV2.jugador_de(atributos)
	var relativos := {}
	for clave in atributos:
		relativos[clave] = MatchEngine.relativo_al_nivel(float(atributos[clave]), nivel)
	f["rol"] = rol
	f["base"] = base
	f["atributos"] = atributos
	f["relativos"] = relativos
	f["creador"] = Personalidad.tiene(jugador, "Creador")
	f["metodico"] = Personalidad.tiene(jugador, "Metodico")
	f["pie_malo_lado"] = Personalidad.pie_preferido(jugador) if Personalidad.tiene(jugador, "Pie preferido") else 0
	f["margen_offside"] = MotorEspacial.FACTOR_OFFSIDE_ENFOCADO if Personalidad.tiene(jugador, "Enfocado") else 1.0
	return f
