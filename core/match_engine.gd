class_name MatchEngine
extends RefCounted

## Motor de partido — Fase 2 (GDD §8.8), extendido en Fase 5 con lesiones.
## Cadena de posesiones tick a tick, sin ningún nodo de Godot: 1000 partidos
## deben poder simularse en segundos.
##
## Modificadores conectados en esta fase: local + choque de estilos (§8.3 y
## §8.6.3, bloque C) y racha de acciones exitosas + armonía + capitán
## (bloque B); DT según marcador (§8.6.4); clima, estado de la cancha,
## árbitro y objetivo de directiva en riesgo (§8.4 #18/19/20/21/23/30). El
## resto de los 37 modificadores (§8.4) llega cuando existan sus sistemas
## de origen: calendario/rival directo/prensa (todavía no hay noción de
## "clásico" ni de racha de prensa), forma de partido a partido (todavía
## no distinguida del ánimo de temporada), rasgos de personalidad
## decorativos (fase futura).
##
## §8.7: hay un "11 en cancha" real (Team.en_cancha) durante el partido, con
## hasta 5 cambios automáticos por lesión/cansancio en 3 ventanas
## (entretiempo, 60', 75' — ver _procesar_cambios). Antes de esto el motor
## sampleaba directo de los 18 (titulares+banco) en cada duelo sin ningún
## concepto de "quién está jugando ahora".

const TICKS_POR_MITAD := 90

## Pases consecutivos exitosos que hacen falta para llegar al último tercio.
## Sin esto, con ~50% de éxito por duelo parejo se genera un tiro casi cada
## 2 ticks y el marcador se dispara a números de básquet. Simula la posesión
## sostenida real en vez de un solo pase mágico que atraviesa la cancha.
##
## Se probó (tests/_diag_estilos_goles.gd) hacer que esto varíe por Estilo
## para que Tiki taka construya con más toques — se descartó: la
## probabilidad de encadenar N pases exitosos es ~p^N, así que hasta ±1
## alrededor de la base (Tiki taka=4, Contragolpe=2) triplicaba los
## goles/partido de Contragolpe respecto a Tiki taka. Es una palanca
## demasiado sensible para usarla como diferenciador de estilo sin romper
## el balance de goles ya calibrado — queda fija para los 6 estilos.
const AVANCE_REQUERIDO := 3

const GRUPO_POR_ATRIBUTO := {
	"pases": "tecnico", "control": "tecnico", "tiro": "tecnico",
	"quite": "defensivo", "barrida": "defensivo",
}


static func _grupo_de(attr: String) -> String:
	return GRUPO_POR_ATRIBUTO.get(attr, "tecnico")


static func _elegir(jugadores: Array, rng: RandomNumberGenerator) -> Dictionary:
	return jugadores[rng.randi() % jugadores.size()]


## §8.5: bloque A (forma del día ver Team.forma_partido, fuera de
## posición §8.4#4 y partidos seguidos §8.4#25), bloque B
## (equipo/racha/armonía/capitán/familiaridad táctica §7.4.5), bloque C (local + choque de estilos
## §8.6.3 + rasgo del DT según el marcador §8.6.4 + clima §8.4#18/20 +
## estado de la cancha §8.4#21 + árbitro casero §8.4#23 + público §8.4#22
## + varianza de clásico §8.4#14) y bloque D (motivación §8.4#26-30 —
## por ahora solo #30, objetivo de directiva en riesgo— (personalidad + habilidad de ESE jugador en ESE
## duelo, §6/§5 — Ansioso de visitante, Egoísta priorizando su propio
## tiro, Cañón sumando en sus duelos de tiro si ya se manifestó).
## `companero_id` es el otro jugador del MISMO equipo que participa de la
## accion —el receptor de un pase— o -1 si la accion es de uno solo. La
## quimica (§7.4.6) es de a pares y solo entra cuando hay par.
static func _bloques_equipo(equipo: Team, rival: Team, jugador: Dictionary, atributo: String, minuto: int, rng: RandomNumberGenerator, companero_id: int = -1) -> Dictionary:
	var jugador_id: int = jugador["id"]
	# §8.4 #4 y #25. Los dos son del JUGADOR, asi que van en bloque A, y
	# los dos motores los ven porque los dos pasan por aca.
	var bloque_a := equipo.forma_partido \
		+ equipo.penalizacion_puesto(jugador_id) \
		+ equipo.penalizacion_partidos_seguidos(jugador_id)
	# La racha de acciones aporta MEDIO punto por accion con tope +5, y no
	# uno con tope +10 como decia el §8.4 original.
	#
	# Ese "+1% por accion, tope +10%" es de los 7 modificadores viejos,
	# escritos antes de que existiera la estructura de bloques del §8.5.
	# Con el tope de +10, la racha sola se comia dos tercios del bloque B
	# —tope ±15— y ahi todo lo demas que vive en ese bloque deja de
	# existir. Medido: el bloque B promediaba 11,63 de 15 y se saturaba en
	# el 27% de los duelos, tirando 0,77 pp por duelo a la basura, mientras
	# los otros tres bloques estaban casi vacios. Los que pagaban el precio
	# eran la familiaridad tactica y la quimica, que viven ahi.
	# La armonia entra acotada a la banda que le pone el §8.4:
	# +5 / +2 / 0 / -3 / -5. Team.armonia es la SUMA cruda de los rasgos de
	# los 18 del plantel mas una tirada, y medido sobre 200 clubes va de
	# -9,4 a +9,2 — casi el doble de la banda. Sin acotarla, el vestuario
	# solo se comia un tercio del bloque B.
	var bloque_b: float = clampf(equipo.armonia, -5.0, 5.0) 		+ clamp(float(equipo.racha) * 0.5, 0.0, 5.0)
	if jugador_id == equipo.capitan_id:
		bloque_b += 2.0
	# §8.4#11 / §7.4.5: la tactica que estas usando, de -8 recien
	# estrenada a +5 dominada. Va en bloque B porque es del EQUIPO, no de
	# este jugador ni del entorno.
	bloque_b += Familiaridad.modificador(equipo)
	# §8.4#10 / §7.4.6: lo que se entienden estos dos en particular.
	if companero_id >= 0:
		bloque_b += Quimica.bonus(equipo, jugador_id, companero_id)
	var bloque_c := 5.0 if equipo.local else 0.0
	bloque_c += Estilos.modificador(equipo.estilo, rival.estilo)
	bloque_c += DT.modificador_partido(equipo, rival, atributo, minuto)
	bloque_c += Clima.modificador(equipo.clima_partido, atributo)
	var cancha_del_local: float = equipo.calidad_cancha if equipo.local else rival.calidad_cancha
	bloque_c += EstadoCancha.modificador(cancha_del_local, atributo)
	bloque_c += Arbitro.modificador(equipo.arbitro_partido, equipo.local)
	if equipo.local:
		bloque_c += Publico.modificador(equipo.fans)
	bloque_c += Rivalidad.variacion(Rivalidad.es_clasico(equipo, rival), rng)
	var bloque_d := Personalidad.modificador_partido(jugador, equipo, rival, atributo, minuto) + Habilidades.modificador_partido(jugador, atributo)
	# §8.4#30, objetivo de directiva en riesgo. Estaba sumado al bloque C
	# y el GDD lo pone en el D: los modificadores 26 a 30 son los de
	# MOTIVACION. No es cosmetico —cada bloque tiene su propio tope, asi
	# que estar en el bloque equivocado cambia con quien compite por
	# entrar— y ademas el D estaba practicamente vacio.
	if equipo.objetivo_en_riesgo:
		bloque_d += Objetivos.MALUS_EN_RIESGO
	return {"A": bloque_a, "B": bloque_b, "C": bloque_c, "D": bloque_d}


## §2.3: tira riesgo de lesión para un jugador que acaba de participar en un
## duelo. No lo saca de la cancha al toque (eso requeriría parar el
## partido); queda indisponible para el resto de esta acción y de
## cualquier duelo hasta la próxima ventana de cambios (§8.7,
## _procesar_cambios), que es la que decide si entra un reemplazo.
static func _chequear_lesion(jugador: Dictionary, equipo: Team, rng: RandomNumberGenerator) -> void:
	if equipo.esta_lesionado(jugador["id"]):
		return
	# §7.4.1: entrenar duro rompe jugadores. El parámetro ya existía en
	# evaluar_riesgo pero nadie lo pasaba.
	var resultado := Lesiones.intentar_lesion(
		jugador, equipo.resistencia_pct(jugador["id"]), rng,
		Instalaciones.factor_riesgo_lesion(equipo),
		CargaEntrenamiento.factor_lesion(equipo.carga_entrenamiento))
	if not resultado.is_empty():
		equipo.lesionar(jugador["id"], resultado["tipo"], resultado["dias"])


## §8.7: chance de tarjeta para el defensor en un duelo de marca ("quite").
## Con ~180 duelos de marca por partido (2 mitades x 90 ticks), estas
## probabilidades dan ~3 amarillas por partido entre los dos equipos,
## parecido a un partido real. Las rojas (directas + segunda amarilla)
## salen bastante más seguido que en la vida real (~0.4 por partido en vez
## de ~0.1) porque los defensores que participan de estos duelos son un
## pool chico (unos pocos por equipo, no los 20+ de un plantel completo en
## cancha), así que la chance de que el mismo jugador junte 2 amarillas es
## mayor — simplificación conocida del motor de posesión por zona, no
## calibrada para bajarlo más sin perder amarillas realistas. El expulsado
## queda afuera del resto de ESTE partido (Team.expulsados_partido) y
## arrastra 1 partido de suspensión (Team.suspendidos, lo sirve
## Liga.jugar_fecha).
const CHANCE_ROJA_DIRECTA := 0.0004
const CHANCE_AMARILLA := 0.02


static func _chequear_tarjeta(defensor: Dictionary, equipo_defensor: Team, equipo_atacante: Team, rng: RandomNumberGenerator,
		eventos: Array, minuto: int, con_log: bool = false, log: Array = []) -> void:
	var id: int = defensor["id"]
	if equipo_defensor.expulsados_partido.has(id):
		return

	var factor_arbitro := Arbitro.factor_tarjetas(equipo_defensor.arbitro_partido)
	var factor_clasico := Rivalidad.factor_tarjetas(Rivalidad.es_clasico(equipo_defensor, equipo_atacante))
	var roll := rng.randf()
	var es_roja := false
	var doble_amarilla := false

	if roll < CHANCE_ROJA_DIRECTA * factor_arbitro * factor_clasico * Personalidad.factor_roja(defensor):
		es_roja = true
	elif roll < CHANCE_AMARILLA * factor_arbitro * factor_clasico * Personalidad.factor_amarilla(defensor):
		var actuales: int = equipo_defensor.amarillas_partido.get(id, 0) + 1
		equipo_defensor.amarillas_partido[id] = actuales
		if actuales >= 2:
			es_roja = true
			doble_amarilla = true
		else:
			if con_log:
				log.append("min %d - TARJETA AMARILLA (%s) - %s" % [minuto, equipo_defensor.nombre, defensor["posicion"]])
			eventos.append({
				"minuto": minuto, "tipo": "tarjeta", "equipo": equipo_defensor.nombre, "rival": "",
				"jugador_posicion": defensor["posicion"], "jugador_id": id, "resultado": "amarilla",
			})
	else:
		return

	if es_roja:
		equipo_defensor.expulsados_partido[id] = true
		equipo_defensor.suspendidos[id] = equipo_defensor.suspendidos.get(id, 0) + 1
		if con_log:
			log.append("min %d - TARJETA ROJA%s (%s) - %s" % [
				minuto, " (doble amarilla)" if doble_amarilla else "", equipo_defensor.nombre, defensor["posicion"]
			])
		eventos.append({
			"minuto": minuto, "tipo": "tarjeta", "equipo": equipo_defensor.nombre, "rival": "",
			"jugador_posicion": defensor["posicion"], "jugador_id": id,
			"resultado": "roja_doble_amarilla" if doble_amarilla else "roja",
		})


static func _duelo(atacante: Dictionary, atacante_attr: String, equipo_atacante: Team,
		defensor: Dictionary, defensor_attr: String, equipo_defensor: Team, rng: RandomNumberGenerator,
		eventos: Array = [], minuto: int = 0, con_log: bool = false, log: Array = [],
		companero_id: int = -1) -> Dictionary:
	var ata_eff := Duel.atributo_efectivo(
		atacante["atributos"][atacante_attr], _grupo_de(atacante_attr),
		equipo_atacante.resistencia_pct(atacante["id"]))
	var def_eff := Duel.atributo_efectivo(
		defensor["atributos"][defensor_attr], _grupo_de(defensor_attr),
		equipo_defensor.resistencia_pct(defensor["id"]))
	var resultado := Duel.resolver(
		ata_eff, def_eff,
		_bloques_equipo(equipo_atacante, equipo_defensor, atacante, atacante_attr, minuto, rng, companero_id),
		_bloques_equipo(equipo_defensor, equipo_atacante, defensor, defensor_attr, minuto, rng))
	equipo_atacante.desgastar(atacante["id"], atacante["atributos"]["energia"])
	equipo_defensor.desgastar(defensor["id"], defensor["atributos"]["energia"])
	_chequear_lesion(atacante, equipo_atacante, rng)
	_chequear_lesion(defensor, equipo_defensor, rng)
	if defensor_attr == "quite":
		_chequear_tarjeta(defensor, equipo_defensor, equipo_atacante, rng, eventos, minuto, con_log, log)
	return resultado


## Un período de juego (una mitad regular, o un tiempo de alargue):
## posesión alternándose duelo a duelo entre zona de armado y zona final,
## igual que cualquier otra franja del partido. Factorizado para que
## simular() (2 mitades de 45') y simular_alargue() (2 tiempos de 15')
## compartan la misma lógica sin duplicar el bucle.
static func _jugar_periodo(equipo_inicial: Team, home: Team, away: Team, ticks: int,
		minuto_offset: int, minutos_reales: float, rng: RandomNumberGenerator, con_log: bool,
		log: Array, goles_log: Array, eventos: Array) -> void:
	var posesion: Team = equipo_inicial
	var zona := "build"

	for tick in range(ticks):
		var minuto: int = minuto_offset + int(tick / (ticks / minutos_reales)) + 1
		var rival: Team = away if posesion == home else home

		if zona == "build":
			var medios := posesion.jugadores_disponibles_por_posiciones(["MC", "MCO", "LAT"])
			var marcadores := rival.jugadores_disponibles_por_posiciones(["DFC", "LAT", "MC"])

			var atacante := _elegir(medios, rng)
			var defensor := _elegir(marcadores, rng)
			# §7.4.6: un pase va DE alguien A alguien. El motor abstracto no
			# modelaba al receptor porque nunca lo habia necesitado; ahora
			# se elige uno de los que estarian en posicion de recibirla,
			# para que la quimica de la dupla tenga a quien mirar.
			var receptor := _elegir(
				posesion.jugadores_disponibles_por_posiciones(["MC", "MCO", "EXT", "DC"]), rng)
			var resultado := _duelo(atacante, "pases", posesion, defensor, "quite", rival, rng, eventos, minuto, con_log, log, int(receptor["id"]))
			var exito := Duel.gana_atacante(resultado, rng)

			if con_log:
				log.append("min %d - PASE (%s) - %s (pases %d) vs %s (quite %d) -> %.1f%% -> %s" % [
					minuto, posesion.nombre, atacante["posicion"], atacante["atributos"]["pases"],
					defensor["posicion"], defensor["atributos"]["quite"],
					resultado["final"], "avanza" if exito else "pierde"
				])
			eventos.append({
				"minuto": minuto, "tipo": "pase", "equipo": posesion.nombre, "rival": rival.nombre,
				"jugador_posicion": atacante["posicion"], "resultado": "avanza" if exito else "pierde",
			})

			if exito:
				posesion.racha += 1
				posesion.avance += 1
				if posesion.avance >= AVANCE_REQUERIDO:
					posesion.avance = 0
					zona = "final"
			else:
				posesion.racha = 0
				posesion.avance = 0
				posesion = rival
				zona = "build"
		else:
			var ofensivos := posesion.jugadores_disponibles_por_posiciones(["EXT", "DC", "MCO"])
			var marcadores := rival.jugadores_disponibles_por_posiciones(["DFC", "LAT"])

			var atacante := _elegir(ofensivos, rng)
			var defensor := _elegir(marcadores, rng)
			var resultado := _duelo(atacante, "control", posesion, defensor, "quite", rival, rng, eventos, minuto, con_log, log)
			var exito := Duel.gana_atacante(resultado, rng)

			if con_log:
				log.append("min %d - GAMBETA (%s) - %s (control %d) vs %s (quite %d) -> %.1f%% -> %s" % [
					minuto, posesion.nombre, atacante["posicion"], atacante["atributos"]["control"],
					defensor["posicion"], defensor["atributos"]["quite"],
					resultado["final"], "tira" if exito else "pierde"
				])
			eventos.append({
				"minuto": minuto, "tipo": "gambeta", "equipo": posesion.nombre, "rival": rival.nombre,
				"jugador_posicion": atacante["posicion"], "resultado": "tira" if exito else "pierde",
			})

			if exito:
				var tiro := _resolver_tiro(posesion, rival, atacante, rng, con_log, log, eventos, minuto)
				if tiro["gol"]:
					posesion.goles += 1
					goles_log.append({"minuto": minuto, "equipo": posesion.nombre, "jugador_id": tiro["goleador_id"]})
				posesion.racha = 0
				posesion = rival
				zona = "build"
			else:
				posesion.racha = 0
				posesion = rival
				zona = "build"


## §8.7: hasta 5 cambios entre los dos equipos, sacando primero a los
## lesionados y después al más cansado por debajo del umbral que cada club
## eligió (config_cambios). No reemplaza a los expulsados (roja) — eso no
## existe en el fútbol real, el equipo sigue con uno menos. El reemplazo es
## siempre de la MISMA posición desde el banco (7 suplentes, uno por
## puesto): es una simplificación deliberada, no busca "el mejor disponible
## en cualquier puesto".
const UMBRAL_CAMBIO := {"descanso": 0.85, "equilibrado": 0.75, "rendimiento": 0.65}


static func _mejor_suplente_para(equipo: Team, posicion: String):
	var mejor = null
	for j in equipo.banco:
		if j["posicion"] != posicion or equipo.en_cancha.has(j["id"]) or not equipo.puede_jugar(j["id"]):
			continue
		if mejor == null or j["media"] > mejor["media"]:
			mejor = j
	return mejor


static func _procesar_cambios_equipo(equipo: Team, minuto: int, con_log: bool, log: Array, eventos: Array) -> void:
	if equipo.cambios_realizados >= Team.MAX_CAMBIOS:
		return
	var umbral: float = UMBRAL_CAMBIO.get(equipo.config_cambios, UMBRAL_CAMBIO["equilibrado"])

	var candidatos := []
	for j in equipo.jugadores_en_cancha():
		if equipo.expulsados_partido.has(j["id"]):
			continue  # una roja no se reemplaza
		if equipo.esta_lesionado(j["id"]) or equipo.resistencia_pct(j["id"]) < umbral:
			candidatos.append(j)
	candidatos.sort_custom(func(a, b):
		var a_les := equipo.esta_lesionado(a["id"])
		var b_les := equipo.esta_lesionado(b["id"])
		if a_les != b_les:
			return a_les
		return equipo.resistencia_pct(a["id"]) < equipo.resistencia_pct(b["id"]))

	for saliente in candidatos:
		if equipo.cambios_realizados >= Team.MAX_CAMBIOS:
			break
		var entrante = _mejor_suplente_para(equipo, saliente["posicion"])
		if entrante == null:
			continue
		equipo.sustituir(saliente["id"], entrante["id"])
		var motivo := "lesion" if equipo.esta_lesionado(saliente["id"]) else "cansancio"
		if con_log:
			log.append("min %d - CAMBIO (%s) - sale %s (%s), entra %s" % [
				minuto, equipo.nombre, saliente["posicion"], motivo, entrante["posicion"]
			])
		eventos.append({
			"minuto": minuto, "tipo": "cambio", "equipo": equipo.nombre, "rival": "",
			"jugador_posicion": saliente["posicion"], "resultado": motivo,
		})


static func _procesar_cambios(home: Team, away: Team, minuto: int, con_log: bool, log: Array, eventos: Array) -> void:
	_procesar_cambios_equipo(home, minuto, con_log, log, eventos)
	_procesar_cambios_equipo(away, minuto, con_log, log, eventos)


## eventos: Array de Dictionary siempre poblada (con_log solo controla el
## log de texto, más caro/verboso) para que la UI (Fase 8) pueda animar un
## partido sin tener que parsear el texto del log.
static func simular(home: Team, away: Team, rng: RandomNumberGenerator, con_log: bool = false) -> Dictionary:
	home.reset_partido()
	away.reset_partido()
	home.local = true
	away.local = false
	home.forma_partido = clamp(rng.randfn(0.0, 4.0), -10.0, 10.0)
	away.forma_partido = clamp(rng.randfn(0.0, 4.0), -10.0, 10.0)
	# Clima y árbitro son del PARTIDO, no de un equipo — los dos comparten
	# el mismo valor (ver Clima.modificador/EstadoCancha.modificador: el
	# gancho ya se encarga de que no favorezcan a nadie por sí solos).
	home.clima_partido = Clima.generar(rng)
	away.clima_partido = home.clima_partido
	home.arbitro_partido = Arbitro.generar(rng)
	away.arbitro_partido = home.arbitro_partido

	var log := []
	var goles_log := []
	var eventos := []

	_jugar_periodo(home, home, away, TICKS_POR_MITAD, 0, 45.0, rng, con_log, log, goles_log, eventos)
	_procesar_cambios(home, away, 45, con_log, log, eventos)  # entretiempo

	# El segundo tiempo se parte en 3 tandas de 15' reales (30 ticks cada
	# una, TICKS_POR_MITAD/3) para poder meter dos ventanas de cambio más
	# (60' y 75') sin duplicar el bucle de _jugar_periodo — el costo es que
	# la posesión "reinicia" en el equipo que arranca cada tanda en vez de
	# seguir de forma perfectamente continua, una simplificación menor
	# frente a lo que ya aproxima el resto del motor. Alternando quién
	# arranca cada tanda (away/home/away) en vez de repetir siempre el
	# mismo equipo, ningún lado termina con más saques que el otro por el
	# solo hecho de que existan las ventanas de cambio.
	var tanda := int(TICKS_POR_MITAD / 3.0)
	_jugar_periodo(away, home, away, tanda, 45, 15.0, rng, con_log, log, goles_log, eventos)
	_procesar_cambios(home, away, 60, con_log, log, eventos)
	_jugar_periodo(home, home, away, tanda, 60, 15.0, rng, con_log, log, goles_log, eventos)
	_procesar_cambios(home, away, 75, con_log, log, eventos)
	_jugar_periodo(away, home, away, TICKS_POR_MITAD - 2 * tanda, 75, 15.0, rng, con_log, log, goles_log, eventos)

	return {
		"goles_local": home.goles,
		"goles_visitante": away.goles,
		"log": log,
		"goles_log": goles_log,
		"eventos": eventos,
		# §7.3: este motor no sabe quién hizo qué, así que estima el
		# reparto por puesto. Ver xp_estimada.
		"xp": {"home": xp_estimada(home), "away": xp_estimada(away)},
	}


## §7.3 aprendizaje por uso, lado abstracto. Este motor resuelve el
## partido como una cadena de duelos por zona: no tiene idea de cuántos
## pases dio cada jugador. Entonces estima el reparto con los PESOS DE
## POSICIÓN (data/position_weights.json), que son literalmente "qué hace
## un jugador de este puesto".
##
## Es una aproximación, y a propósito: lo que NO puede ser aproximado es
## el TOTAL. MotorEspacial normaliza a `minutos/90` por jugador y esto
## entrega lo mismo, así que un titular crece igual de rápido juegue el
## usuario o la IA. Si los totales no coincidieran, el desbalance se
## acumularía temporada a temporada en vez de promediarse como los goles.
##
## Lo que sí cambia entre motores es la FORMA: acá un 9 siempre entrena
## como un 9 promedio; en el partido del usuario, un 9 que remató ocho
## veces entrena tiro de verdad. Esa es justamente la ventaja de jugarlo.
const FRACCION_SUPLENTE := 0.35
## Un titular al que cambian jugó la mayor parte (las ventanas son 45',
## 60' y 75'), no el partido entero.
const FRACCION_REEMPLAZADO := 0.7


static func xp_estimada(equipo: Team) -> Dictionary:
	var pesos: Dictionary = PlayerGenerator.get_weights()
	var out := {}
	for j in equipo.todos_los_jugadores():
		var titular: bool = _es_titular(equipo, j["id"])
		var esta: bool = equipo.en_cancha.has(j["id"])
		# Tres casos: jugó todo, salió, o entró. El que no pisó la cancha
		# no aprende nada, que es justamente lo que hace que los minutos
		# importen (§7.3).
		var fraccion := 0.0
		if titular and esta:
			fraccion = 1.0
		elif titular:
			fraccion = FRACCION_REEMPLAZADO
		elif esta:
			fraccion = FRACCION_SUPLENTE
		if fraccion <= 0.0:
			continue
		var perfil: Dictionary = pesos.get(j["posicion"], {})
		if perfil.is_empty():
			continue
		var suma := 0.0
		for a in perfil:
			suma += float(perfil[a])
		if suma <= 0.0:
			continue
		var d := {}
		for a in perfil:
			d[a] = float(perfil[a]) / suma * fraccion
		out[int(j["id"])] = d
	return out


static func _es_titular(equipo: Team, jugador_id: int) -> bool:
	for j in equipo.jugadores:
		if j["id"] == jugador_id:
			return true
	return false


## §8.7: tiempo suplementario — 2 tiempos de 15' cada uno, mismo motor que
## el partido regular pero SIN resetear resistencia/goles/tarjetas: sigue
## desde donde quedó el resultado regular (home.goles/away.goles ya
## traen el marcador de los 90'). Solo se llama cuando terminó 90'
## empatado (ver Copa.jugar_siguiente_ronda) — si después de esto sigue
## empatado, se define por penales (core/penales.gd).
const TICKS_POR_TIEMPO_ALARGUE := int(TICKS_POR_MITAD / 3.0)  # 15' de 45' reales


static func simular_alargue(home: Team, away: Team, rng: RandomNumberGenerator, con_log: bool = false) -> Dictionary:
	var log := []
	var goles_log := []
	var eventos := []

	_procesar_cambios(home, away, 90, con_log, log, eventos)  # ultima ventana, antes del alargue
	for tiempo in range(2):
		var equipo_inicial: Team = home if tiempo == 0 else away
		_jugar_periodo(equipo_inicial, home, away, TICKS_POR_TIEMPO_ALARGUE, 90 + tiempo * 15, 15.0, rng, con_log, log, goles_log, eventos)

	return {
		"goles_local": home.goles,
		"goles_visitante": away.goles,
		"log": log,
		"goles_log": goles_log,
		"eventos": eventos,
	}


## §8.2: destino del tiro, duelo contra el arquero, y rebote si ataja sin agarrar.
static func _resolver_tiro(equipo_atacante: Team, equipo_defensor: Team, atacante: Dictionary,
		rng: RandomNumberGenerator, con_log: bool, log: Array, eventos: Array, minuto: int) -> Dictionary:
	var arquero := equipo_defensor.arquero()
	var tiro: int = atacante["atributos"]["tiro"]
	# La punteria se juzga contra el nivel del partido, no en absoluto:
	# ver relativo_al_nivel.
	var destino := _resolver_destino(
		int(round(relativo_al_nivel(float(tiro), nivel_partido(equipo_atacante, equipo_defensor)))), rng)

	if destino != "porteria":
		if con_log:
			log.append("min %d - TIRO (%s) - %s (tiro %d) -> %s" % [minuto, equipo_atacante.nombre, atacante["posicion"], tiro, destino])
		eventos.append({
			"minuto": minuto, "tipo": "tiro", "equipo": equipo_atacante.nombre, "rival": equipo_defensor.nombre,
			"jugador_posicion": atacante["posicion"], "resultado": destino,
		})
		return {"gol": false, "destino": destino, "goleador_id": -1}

	var arquero_attrs = arquero["atributos"]
	var arquero_valor: float = arquero_attrs["reflejos"] * 0.5 + arquero_attrs["estirada"] * 0.3 + arquero_attrs["agarre"] * 0.2
	var resultado := _duelo_tiro(atacante, float(tiro), equipo_atacante, arquero, arquero_valor, equipo_defensor, rng, minuto)
	var gol := Duel.gana_atacante(resultado, rng)

	if con_log:
		log.append("min %d - TIRO A PUERTA (%s) - %s (tiro %d) vs Arq. de %s (%.1f) -> %.1f%% -> %s" % [
			minuto, equipo_atacante.nombre, atacante["posicion"], tiro, equipo_defensor.nombre, arquero_valor, resultado["final"],
			"GOL (%s)" % equipo_atacante.nombre if gol else "ATAJADA"
		])
	eventos.append({
		"minuto": minuto, "tipo": "tiro_puerta", "equipo": equipo_atacante.nombre, "rival": equipo_defensor.nombre,
		"jugador_posicion": atacante["posicion"], "resultado": "gol" if gol else "atajada",
	})

	if gol:
		return {"gol": true, "destino": destino, "goleador_id": atacante["id"]}

	var chance_rebote: float = clamp(1.0 - float(arquero_attrs["agarre"]) / 100.0, 0.1, 0.7)
	if rng.randf() < chance_rebote:
		var rebotadores := equipo_atacante.jugadores_disponibles_por_posiciones(["DC", "EXT", "MCO"])
		var rematador := _elegir(rebotadores, rng)
		var tiro_rebote: float = float(rematador["atributos"]["tiro"]) * 0.8
		var resultado_rebote := _duelo_tiro(rematador, tiro_rebote, equipo_atacante, arquero, arquero_valor * 0.9, equipo_defensor, rng, minuto)
		var gol_rebote := Duel.gana_atacante(resultado_rebote, rng)
		if con_log:
			log.append("min %d - REBOTE (%s) - %s (tiro %.0f) -> %.1f%% -> %s" % [
				minuto, equipo_atacante.nombre, rematador["posicion"], tiro_rebote, resultado_rebote["final"],
				"GOL (%s)" % equipo_atacante.nombre if gol_rebote else "ATAJADA"
			])
		eventos.append({
			"minuto": minuto, "tipo": "rebote", "equipo": equipo_atacante.nombre, "rival": equipo_defensor.nombre,
			"jugador_posicion": rematador["posicion"], "resultado": "gol" if gol_rebote else "atajada",
		})
		return {"gol": gol_rebote, "destino": "porteria", "goleador_id": rematador["id"]}

	return {"gol": false, "destino": destino, "goleador_id": -1}


static func _duelo_tiro(atacante: Dictionary, tiro_valor: float, equipo_atacante: Team,
		arquero: Dictionary, arquero_valor: float, equipo_defensor: Team, rng: RandomNumberGenerator, minuto: int) -> Dictionary:
	var ata_eff := Duel.atributo_efectivo(tiro_valor, "tecnico", equipo_atacante.resistencia_pct(atacante["id"]))
	var def_eff := Duel.atributo_efectivo(arquero_valor, "tecnico", equipo_defensor.resistencia_pct(arquero["id"]))
	var resultado := Duel.resolver(
		ata_eff, def_eff,
		_bloques_equipo(equipo_atacante, equipo_defensor, atacante, "tiro", minuto, rng),
		_bloques_equipo(equipo_defensor, equipo_atacante, arquero, "reflejos", minuto, rng))
	equipo_atacante.desgastar(atacante["id"], atacante["atributos"]["energia"])
	equipo_defensor.desgastar(arquero["id"], arquero["atributos"]["energia"])
	_chequear_lesion(atacante, equipo_atacante, rng)
	_chequear_lesion(arquero, equipo_defensor, rng)
	return resultado


## Media de plantel contra la que están calibradas las curvas que miran el
## valor ABSOLUTO de un atributo. Es la media que daban todos los clubes
## cuando la pirámide no tenía gradiente por división.
const NIVEL_REFERENCIA := 46.0


## El nivel al que se juega este partido.
static func nivel_partido(a: Team, b: Team) -> float:
	return (a.media_equipo() + b.media_equipo()) * 0.5


## Lleva un atributo al nivel de referencia, conservando cuánto se despega
## el jugador del nivel al que juega.
##
## Hace falta porque algunas curvas (puntería, ver _resolver_destino) miran
## el valor absoluto: con el gradiente por división (NivelDivision) un
## delantero de primera tiene tiro ~87 y erraba casi nunca, así que la
## primera terminaba con 5,45 goles por partido y la décima con 2,24 —
## justo al revés de lo que pasa en el fútbol de verdad, y con la economía
## y los objetivos calibrados sobre ~3,4. Normalizando, un delantero
## promedio de su liga apunta igual de bien juegue donde juegue, y el que
## se despega de su liga sigue teniendo su ventaja.
static func relativo_al_nivel(valor: float, nivel: float) -> float:
	return clampf(valor - nivel + NIVEL_REFERENCIA, 0.0, 100.0)


## §8.2 punto 1: a mayor tiro, más chance de ir a puerta; el palo escala con
## la precisión, "afuera" baja cuanto mejor es el rematador. `tiro` viene
## ya normalizado al nivel del partido (ver relativo_al_nivel).
static func _resolver_destino(tiro: int, rng: RandomNumberGenerator) -> String:
	var t: float = clamp(tiro, 0, 100) / 100.0
	var chance_palo: float = 0.05 * t
	var chance_afuera: float = clamp(0.6 - 0.45 * t, 0.08, 0.6)
	var chance_porteria: float = max(0.0, 1.0 - chance_palo - chance_afuera)

	var roll := rng.randf()
	if roll < chance_porteria:
		return "porteria"
	elif roll < chance_porteria + chance_palo:
		return "palo"
	return "afuera"
