class_name Team
extends RefCounted

## Equipo para el motor de partido — Fase 2, extendido en Fase 5 con estado
## que persiste entre partidos (fatiga acumulada, ánimo, lesiones). Todavía
## no es el club de la partida completo (eso llega con la economía/plantel
## de 25 en fases posteriores): acá es la plantilla titular fija de 11.

const FORMACION := ["ARQ", "DFC", "DFC", "LAT", "LAT", "MC", "MC", "MCO", "EXT", "EXT", "DC"]

## Cuántos ids reserva cada equipo (Liga/Piramide/Confederacion espacian
## id_inicial por este número, no por FORMACION.size()): los 11 titulares
## usan los primeros 11, el resto queda para la cantera (§17) a lo largo de
## muchas temporadas sin arriesgar colisión con el equipo vecino.
const RANGO_IDS_RESERVADO := 300

## §3: cuánto recupera la fatiga acumulada por día de descanso entre fechas.
const RECUPERACION_FATIGA_POR_DIA := 0.1
## §3: velocidad de la deriva natural del ánimo hacia 50 (por semana).
const DERIVA_ANIMO_POR_SEMANA := 1.0

var nombre: String
var jugadores: Array = []  # 11 dicts (PlayerGenerator.generate), uno por puesto de FORMACION
var local: bool = false
var armonia: float = 0.0  # placeholder hasta que exista §3 completo (vestuario real)
## §8.4 modificador 2 ("Forma, de -5 a +5 según los últimos 5 partidos"),
## bloque A. Sin historial de partidos recientes todavía, se aproxima con
## un valor al azar por partido ("día bueno/malo") — sirve al mismo
## propósito (variedad de partido a partido más allá de la calidad pura
## del plantel) y de paso evita que un equipo apenas mejor gane casi
## siempre por el efecto acumulado de decenas de duelos por partido.
var forma_partido: float = 0.0
var racha: int = 0
var avance: int = 0  # pases consecutivos exitosos en la zona de armado, ver MatchEngine
var goles: int = 0
var capitan_id: int = -1
var resistencia: Dictionary = {}  # jugador_id -> % de resistencia en el partido actual (0..1)

## Fase 5: estado que persiste entre partidos (a diferencia de resistencia,
## que es solo dentro de un partido y siempre arranca desde fatiga_acumulada).
var fatiga_acumulada: Dictionary = {}  # jugador_id -> 0..1, 1 = totalmente descansado
var animo: Dictionary = {}  # jugador_id -> 0..100 (§3)
var lesiones: Dictionary = {}  # jugador_id -> {"tipo":String, "dias_restantes":int}

## Fase 6: economía del club (§9.1).
var caja: Dictionary = {}  # "fichajes"/"contratos"/"mejoras"/"mantenimiento" -> moneda
## Lo que se sumo a cada categoria en el ultimo cierre de temporada, y como
## quedo la caja justo despues de esa inyeccion (antes de que el mercado
## gastara nada) — con las dos, la UI puede mostrar cuanto se gasto de cada
## presupuesto esta temporada (caja_al_cierre - caja).
var presupuesto_temporada: Dictionary = {}
var caja_al_cierre: Dictionary = {}
var sueldos: Dictionary = {}  # jugador_id -> sueldo anual
var contratos: Dictionary = {}  # jugador_id -> años restantes
var reputacion: float = 50.0  # 0-100, afecta entradas/sponsors (§10.5)
var quebrado: bool = false
var scouts: Array = []  # [{"nivel":int}], §9.4 — empieza con 1 al mínimo (§15 decisión 9)

## Fase 9: cantera (§17).
var cantera: Array = []  # dicts de PlayerGenerator.generate, juveniles sin promover
var siguiente_id_cantera: int = 0


## id_inicial debe ser único por equipo dentro de una Liga: los ids de
## jugador no son únicos por sí solos (son 0..10 salvo que el llamador pase
## un offset), y el mercado (Fase 6) transfiere jugadores entre clubes usando
## el id como clave de sueldos/contratos/ánimo — si dos equipos reusan el
## mismo rango de ids, un fichaje puede pisar el registro de otro jugador.
## potencial_objetivo: ver PlayerGenerator.generate — lo usan los clubes del
## exterior (Fase 7, §10.5) para que el plantel ronde su fuerza_equipo.
static func generar(nombre: String, rng: RandomNumberGenerator, id_inicial: int = 0, potencial_objetivo: int = -1) -> Team:
	var t := Team.new()
	t.nombre = nombre
	var next_id := id_inicial
	for pos in FORMACION:
		var jugador := PlayerGenerator.generate(next_id, rng, pos, potencial_objetivo)
		next_id += 1
		t.jugadores.append(jugador)
		t.fatiga_acumulada[jugador["id"]] = 1.0
		t.animo[jugador["id"]] = 50.0
		var valor := ValorJugador.calcular(jugador, 50.0, 3)
		t.sueldos[jugador["id"]] = Economia.sueldo_sugerido(valor) * Personalidad.factor_sueldo(jugador)
		t.contratos[jugador["id"]] = rng.randi_range(1, 5)
		t.armonia += Personalidad.bonus_armonia(jugador)
	t.armonia += rng.randf_range(-3.0, 5.0)
	t.reputacion = clamp(t.media_equipo(), 20.0, 80.0)
	t.scouts = [{"nivel": 1}]
	for categoria in Economia.PRESUPUESTO_PORCENTAJES:
		t.caja[categoria] = 0.0
		t.presupuesto_temporada[categoria] = 0.0
		t.caja_al_cierre[categoria] = 0.0
	t.siguiente_id_cantera = id_inicial + FORMACION.size()
	t.recalcular_capitan()
	return t


func recalcular_capitan() -> void:
	var mejor_media := -1.0
	for j in jugadores:
		if j["media"] > mejor_media:
			mejor_media = j["media"]
			capitan_id = j["id"]


func reset_partido() -> void:
	racha = 0
	avance = 0
	goles = 0
	resistencia.clear()
	for j in jugadores:
		resistencia[j["id"]] = fatiga_acumulada.get(j["id"], 1.0)


func jugadores_por_posiciones(posiciones: Array) -> Array:
	var out := []
	for j in jugadores:
		if posiciones.has(j["posicion"]):
			out.append(j)
	return out


## Como jugadores_por_posiciones pero descarta lesionados. Si no queda nadie
## sano en esas posiciones, cae a cualquier sano; si NADIE está sano (sin
## plantel de 25 puede pasar), devuelve la lista completa como último
## recurso — hueco conocido hasta que exista el plantel de 25 (§14).
func jugadores_disponibles_por_posiciones(posiciones: Array) -> Array:
	var en_posicion := []
	var sanos := []
	for j in jugadores:
		if esta_lesionado(j["id"]):
			continue
		sanos.append(j)
		if posiciones.has(j["posicion"]):
			en_posicion.append(j)
	if not en_posicion.is_empty():
		return en_posicion
	if not sanos.is_empty():
		return sanos
	return jugadores


func arquero() -> Dictionary:
	for j in jugadores:
		if j["posicion"] == "ARQ":
			return j
	return jugadores[0]


func media_equipo() -> float:
	var total := 0.0
	for j in jugadores:
		total += j["media"]
	return total / jugadores.size()


func resistencia_pct(jugador_id: int) -> float:
	return resistencia.get(jugador_id, 1.0)


## Desgaste simple por participación en un duelo. La resistencia nunca baja
## de 0.55 dentro de un partido.
func desgastar(jugador_id: int, energia_attr: int) -> void:
	var decay: float = 0.006 * (1.3 - float(energia_attr) / 100.0)
	resistencia[jugador_id] = max(0.55, resistencia_pct(jugador_id) - decay)


func esta_lesionado(jugador_id: int) -> bool:
	return lesiones.has(jugador_id)


func lesionar(jugador_id: int, tipo: String, dias: int) -> void:
	lesiones[jugador_id] = {"tipo": tipo, "dias_restantes": dias}


## Se llama al terminar cada partido: la resistencia con la que se terminó
## pasa a ser el nuevo piso de fatiga acumulada (§3, "energía" de mediano
## plazo), y el ánimo se mueve según el resultado (±3, tope real ±6 con el
## bonus de gol) siguiendo el GDD §3 simplificado — todavía no hay xG ni
## stats de pases/duelos por jugador para el criterio completo por puesto.
func actualizar_post_partido(goles_propios: int, goles_rival: int, goleadores_ids: Array) -> void:
	for j in jugadores:
		var id: int = j["id"]
		fatiga_acumulada[id] = resistencia_pct(id)

		var delta := 0.0
		if goles_propios > goles_rival:
			delta = 3.0
		elif goles_propios < goles_rival:
			delta = -3.0
		if goleadores_ids.has(id):
			delta += 2.0
		delta = clamp(delta, -6.0, 6.0)
		animo[id] = clamp(animo.get(id, 50.0) + delta, 0.0, 100.0)


## Avanza el calendario entre fechas: recupera fatiga, hace derivar el ánimo
## hacia 50 y cuenta los días de lesión. Devuelve los ids que se recuperaron.
func avanzar_dias(dias: int) -> Array:
	for j in jugadores:
		var id: int = j["id"]
		var recuperacion: float = RECUPERACION_FATIGA_POR_DIA * Personalidad.factor_recuperacion_fatiga(j)
		fatiga_acumulada[id] = min(1.0, fatiga_acumulada.get(id, 1.0) + recuperacion * dias)
		var actual: float = animo.get(id, 50.0)
		var deriva: float = clamp(50.0 - actual, -DERIVA_ANIMO_POR_SEMANA, DERIVA_ANIMO_POR_SEMANA) * (dias / 7.0)
		animo[id] = clamp(actual + deriva, 0.0, 100.0)

	var recuperados := []
	for id in lesiones.keys():
		lesiones[id]["dias_restantes"] -= dias
		if lesiones[id]["dias_restantes"] <= 0:
			recuperados.append(id)
	for id in recuperados:
		lesiones.erase(id)
	return recuperados


## §17: camada anual de juveniles. 15 años, media baja (se generan con las
## curvas normales y se escalan como si todavía no hubieran entrenado nada
## — la genética real que van a alcanzar queda oculta en "potencial" igual
## que cualquier jugador). "cantidad" es fija en 3 hasta que exista el
## nivel de la mejora de Juveniles (§9.5, todavía sin sistema de mejoras).
func generar_camada(rng: RandomNumberGenerator, cantidad: int = 3) -> Array:
	var nuevos := []
	for i in range(cantidad):
		var jugador := PlayerGenerator.generate(siguiente_id_cantera, rng)
		siguiente_id_cantera += 1
		jugador["edad"] = 15

		var factor_juventud: float = rng.randf_range(0.5, 0.7)
		for attr in jugador["atributos"]:
			jugador["atributos"][attr] = int(round(float(jugador["atributos"][attr]) * factor_juventud))
		jugador["media"] = PlayerGenerator.compute_media(jugador["atributos"], jugador["posicion"])
		var mejor := PlayerGenerator.best_position(jugador["atributos"])
		jugador["mejor_posicion"] = mejor["posicion"]
		jugador["media_mejor_posicion"] = mejor["media"]

		cantera.append(jugador)
		nuevos.append(jugador)
	return nuevos


## §17: si no se promueve antes de los 20, se va libre. Se llama en el
## envejecimiento de fin de temporada.
func liberar_veteranos_de_cantera() -> Array:
	var liberados := []
	var conservados := []
	for j in cantera:
		if j["edad"] >= 20:
			liberados.append(j)
		else:
			conservados.append(j)
	cantera = conservados
	return liberados


## Saca al juvenil de la cantera y lo pone titular, reemplazando al de
## menor media en su posición (o al de menor media del plantel si nadie
## juega en esa posición). El que sale queda libre — sin plantel de 25
## todavía (§14) no hay banco a donde mandarlo, simplificación documentada
## igual que el resto del mercado de esta fase.
func promover_juvenil(jugador_id: int) -> Dictionary:
	var idx_cantera := -1
	for i in range(cantera.size()):
		if cantera[i]["id"] == jugador_id:
			idx_cantera = i
			break
	if idx_cantera < 0:
		return {}

	var juvenil: Dictionary = cantera[idx_cantera]

	var idx_saliente := -1
	for i in range(jugadores.size()):
		if jugadores[i]["posicion"] == juvenil["posicion"]:
			if idx_saliente == -1 or jugadores[i]["media"] < jugadores[idx_saliente]["media"]:
				idx_saliente = i
	if idx_saliente == -1:
		idx_saliente = 0
		for i in range(1, jugadores.size()):
			if jugadores[i]["media"] < jugadores[idx_saliente]["media"]:
				idx_saliente = i

	var saliente: Dictionary = jugadores[idx_saliente]
	juvenil["es_canterano"] = true
	jugadores[idx_saliente] = juvenil
	cantera.remove_at(idx_cantera)

	fatiga_acumulada[juvenil["id"]] = 1.0
	animo[juvenil["id"]] = 50.0
	var valor := ValorJugador.calcular(juvenil, 50.0, 3)
	sueldos[juvenil["id"]] = Economia.sueldo_sugerido(valor) * Personalidad.factor_sueldo(juvenil)
	contratos[juvenil["id"]] = 3

	sueldos.erase(saliente["id"])
	contratos.erase(saliente["id"])
	fatiga_acumulada.erase(saliente["id"])
	animo.erase(saliente["id"])
	lesiones.erase(saliente["id"])

	recalcular_capitan()
	return {"promovido": juvenil, "saliente": saliente}


## Heurística simple de IA: promueve al juvenil que más mejoraría el
## plantel si supera claramente al titular más débil de su posición.
## Sin esto, la cantera no haría nada durante una temporada simulada sin
## intervención humana.
func promover_automatico(umbral_media: float = 3.0) -> Array:
	var promovidos := []
	for juvenil in cantera.duplicate():
		var peor_en_posicion := -1.0
		for j in jugadores:
			if j["posicion"] == juvenil["posicion"] and (peor_en_posicion < 0.0 or j["media"] < peor_en_posicion):
				peor_en_posicion = j["media"]
		if peor_en_posicion >= 0.0 and juvenil["media"] >= peor_en_posicion + umbral_media:
			var resultado := promover_juvenil(juvenil["id"])
			if not resultado.is_empty():
				promovidos.append(resultado)
	return promovidos
