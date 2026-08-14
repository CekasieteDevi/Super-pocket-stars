class_name Team
extends RefCounted

## Equipo para el motor de partido — Fase 2, extendido en Fase 5 con estado
## que persiste entre partidos (fatiga acumulada, ánimo, lesiones), y en
## esta fase con el plantel de 25 (§14): 11 titulares + 7 banco (suplentes
## adultos) + hasta ~7 en cantera (reserva, §17, ya existía). Mínimo 15
## disponibles (titulares+banco sanos, de 18 posibles) para jugar — si no
## se llega, ver Liga._resolver_forfeit().

const FORMACION := ["ARQ", "DFC", "DFC", "LAT", "LAT", "MC", "MC", "MCO", "EXT", "EXT", "DC"]
## Un suplente por puesto — banco de 7, como pide §14.
const BANCO_FORMACION := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]

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
var jugadores: Array = []  # 11 dicts (PlayerGenerator.generate), uno por puesto de FORMACION (titulares)
var banco: Array = []  # 7 dicts, uno por puesto de BANCO_FORMACION (suplentes)
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
var instalaciones: Dictionary = {}  # categoria -> nivel 1-5 (§9.5), ver core/instalaciones.gd

## Fase 9: cantera (§17).
var cantera: Array = []  # dicts de PlayerGenerator.generate, juveniles sin promover
var siguiente_id_cantera: int = 0

## Préstamos (§9.3 extendido, §14): ver core/prestamos.gd.
var prestados_afuera: Dictionary = {}  # jugador_id -> {"club":Team, "temporada_retorno":int, "desde_cantera":bool} — jugadores MIOS que cedí, no están en mi plantel ahora
var prestados_propios: Dictionary = {}  # jugador_id -> {"club_dueno":Team, "temporada_retorno":int} — jugadores AJENOS que tengo a préstamo, en mi banco


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
		t._registrar_fichaje(jugador, ValorJugador.calcular(jugador, 50.0, 3), rng.randi_range(1, 5))
		t.armonia += Personalidad.bonus_armonia(jugador)
	for pos in BANCO_FORMACION:
		var jugador := PlayerGenerator.generate(next_id, rng, pos, potencial_objetivo)
		next_id += 1
		t.banco.append(jugador)
		t._registrar_fichaje(jugador, ValorJugador.calcular(jugador, 50.0, 3), rng.randi_range(1, 5))
		t.armonia += Personalidad.bonus_armonia(jugador)
	t.armonia += rng.randf_range(-3.0, 5.0)
	t.reputacion = clamp(t.media_equipo(), 20.0, 80.0)
	t.scouts = [{"nivel": 1}]
	t.instalaciones = Instalaciones.nivel_inicial()
	for categoria in Economia.CATEGORIAS_CAJA:
		t.caja[categoria] = 0.0
		t.presupuesto_temporada[categoria] = 0.0
		t.caja_al_cierre[categoria] = 0.0
	t.siguiente_id_cantera = id_inicial + FORMACION.size() + BANCO_FORMACION.size()
	t.recalcular_capitan()
	return t


func recalcular_capitan() -> void:
	var mejor_media := -1.0
	for j in jugadores:
		if j["media"] > mejor_media:
			mejor_media = j["media"]
			capitan_id = j["id"]


## Titulares + banco (18), sin la cantera/reserva — esos no son parte del
## plantel de partido (§14) hasta que se los promueve.
func todos_los_jugadores() -> Array:
	return jugadores + banco


func jugadores_sanos_count() -> int:
	var count := 0
	for j in todos_los_jugadores():
		if not esta_lesionado(j["id"]):
			count += 1
	return count


## Da de alta a un jugador que se suma al plantel (fichaje, ascenso desde
## cantera): sueldo, contrato, ánimo neutro, totalmente descansado.
func _registrar_fichaje(jugador: Dictionary, valor: float, contrato_anios: int = 3) -> void:
	var id: int = jugador["id"]
	sueldos[id] = Economia.sueldo_sugerido(valor) * Personalidad.factor_sueldo(jugador)
	contratos[id] = contrato_anios
	animo[id] = 50.0
	fatiga_acumulada[id] = 1.0


## Da de baja a un jugador que se va del club (vendido, liberado).
func _limpiar_registro(id: int) -> void:
	sueldos.erase(id)
	contratos.erase(id)
	animo.erase(id)
	fatiga_acumulada.erase(id)
	lesiones.erase(id)


## Mete a un jugador en el banco, en el puesto de BANCO_FORMACION que le
## corresponde por posición (desplazando y liberando al que estaba ahí, si
## había alguien). La usa el mercado cuando un fichaje externo desplaza a
## un titular — antes del plantel de 25 ese titular se liberaba directo;
## ahora pasa al banco en vez de desaparecer.
func mover_a_banco(jugador: Dictionary) -> Dictionary:
	var posicion: String = jugador["posicion"]
	var idx := -1
	for i in range(banco.size()):
		if banco[i]["posicion"] == posicion:
			idx = i
			break
	if idx == -1:
		idx = 0
		for i in range(1, banco.size()):
			if banco[i]["media"] < banco[idx]["media"]:
				idx = i

	var liberado: Dictionary = banco[idx]
	banco[idx] = jugador
	return liberado


## El jugador (o la IA) decide subir a un suplente a titular — swap directo
## de posición, el titular más débil de esa posición pasa al banco. Sin
## costo, es reordenar tu propio plantel, no un fichaje.
func promover_a_titular(jugador_banco_id: int) -> Dictionary:
	var idx_banco := -1
	for i in range(banco.size()):
		if banco[i]["id"] == jugador_banco_id:
			idx_banco = i
			break
	if idx_banco < 0:
		return {}

	var entrante: Dictionary = banco[idx_banco]
	var posicion: String = entrante["posicion"]

	var idx_titular := -1
	for i in range(jugadores.size()):
		if jugadores[i]["posicion"] == posicion:
			if idx_titular == -1 or jugadores[i]["media"] < jugadores[idx_titular]["media"]:
				idx_titular = i
	if idx_titular == -1:
		return {}

	var saliente: Dictionary = jugadores[idx_titular]
	jugadores[idx_titular] = entrante
	banco[idx_banco] = saliente
	recalcular_capitan()
	return {"entra": entrante, "sale": saliente}


## El club que VENDE en una transferencia: en vez de que el jugador que
## llega (más débil, es la contraparte del trueque) pise el puesto titular
## directo, se promueve al suplente de esa posición del banco y el que
## llega ocupa ese lugar del banco — más realista que arrancar de la nada
## con quien sea que llegó a cambio.
func vender_titular(indice_titular: int, jugador_entrante: Dictionary) -> void:
	var posicion: String = jugadores[indice_titular]["posicion"]
	var idx_banco := -1
	for i in range(banco.size()):
		if banco[i]["posicion"] == posicion:
			idx_banco = i
			break
	if idx_banco == -1:
		# no debería pasar (siempre hay un suplente por posición), pero por
		# las dudas: el que llega ocupa el puesto titular directo.
		jugadores[indice_titular] = jugador_entrante
		recalcular_capitan()
		return

	jugadores[indice_titular] = banco[idx_banco]
	banco[idx_banco] = jugador_entrante
	recalcular_capitan()


func reset_partido() -> void:
	racha = 0
	avance = 0
	goles = 0
	resistencia.clear()
	for j in todos_los_jugadores():
		resistencia[j["id"]] = fatiga_acumulada.get(j["id"], 1.0)


func jugadores_por_posiciones(posiciones: Array) -> Array:
	var out := []
	for j in jugadores:
		if posiciones.has(j["posicion"]):
			out.append(j)
	return out


## Como jugadores_por_posiciones pero busca en titulares+banco (§14) y
## descarta lesionados. Si no queda nadie sano en esas posiciones, cae a
## cualquier sano del plantel; si NADIE está sano (con 18 sanos mínimo para
## jugar no debería pasar en un partido real, ver Liga._resolver_forfeit),
## devuelve la lista completa como último recurso.
func jugadores_disponibles_por_posiciones(posiciones: Array) -> Array:
	var en_posicion := []
	var sanos := []
	var todos := todos_los_jugadores()
	for j in todos:
		if esta_lesionado(j["id"]):
			continue
		sanos.append(j)
		if posiciones.has(j["posicion"]):
			en_posicion.append(j)
	if not en_posicion.is_empty():
		return en_posicion
	if not sanos.is_empty():
		return sanos
	return todos


## El titular si está sano; si está lesionado, el suplente de banco (§14).
## Si ninguno está sano, el titular igual (ver Liga._resolver_forfeit para
## el caso de que falten demasiados jugadores para jugar el partido).
func arquero() -> Dictionary:
	var titular: Dictionary = {}
	for j in jugadores:
		if j["posicion"] == "ARQ":
			titular = j
			break
	if not titular.is_empty() and not esta_lesionado(titular["id"]):
		return titular
	for j in banco:
		if j["posicion"] == "ARQ" and not esta_lesionado(j["id"]):
			return j
	return titular if not titular.is_empty() else jugadores[0]


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
	for j in todos_los_jugadores():
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
	for j in todos_los_jugadores():
		var id: int = j["id"]
		var recuperacion: float = RECUPERACION_FATIGA_POR_DIA * Personalidad.factor_recuperacion_fatiga(j) * Instalaciones.factor_recuperacion_fatiga(self)
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
## que cualquier jugador). "cantidad" la decide el nivel de la mejora de
## Juveniles (§9.5, Instalaciones.cantidad_camada) — el default de 3 acá es
## solo para llamadas sueltas (tests) que no pasan por ese cálculo.
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


## Saca al juvenil de la cantera y lo pone en el banco (§14 — un debutante
## entra al plantel, no directo al 11 titular; para eso está
## promover_a_titular, aparte). El suplente que ocupaba ese lugar en el
## banco queda libre.
func promover_juvenil(jugador_id: int) -> Dictionary:
	var idx_cantera := -1
	for i in range(cantera.size()):
		if cantera[i]["id"] == jugador_id:
			idx_cantera = i
			break
	if idx_cantera < 0:
		return {}

	var juvenil: Dictionary = cantera[idx_cantera]
	juvenil["es_canterano"] = true

	var liberado := mover_a_banco(juvenil)
	cantera.remove_at(idx_cantera)

	_registrar_fichaje(juvenil, ValorJugador.calcular(juvenil, 50.0, 3))
	_limpiar_registro(liberado["id"])

	return {"promovido": juvenil, "saliente": liberado}


## Heurística simple de IA: promueve al juvenil que más mejoraría el
## plantel (contra el banco, que es a donde entra un debutante — ver
## promover_juvenil). Sin esto, la cantera no haría nada durante una
## temporada simulada sin intervención humana. No se llama para el equipo
## del jugador humano (ver Liga._procesar_cantera) — esa decisión es suya.
func promover_automatico(umbral_media: float = 3.0) -> Array:
	var promovidos := []
	for juvenil in cantera.duplicate():
		var actual_en_banco := -1.0
		for j in banco:
			if j["posicion"] == juvenil["posicion"]:
				actual_en_banco = j["media"]
				break
		if actual_en_banco >= 0.0 and juvenil["media"] >= actual_en_banco + umbral_media:
			var resultado := promover_juvenil(juvenil["id"])
			if not resultado.is_empty():
				promovidos.append(resultado)
	return promovidos


## Simétrico a promover_automatico pero banco -> titular: si un suplente
## ya es claramente mejor que el titular de su posición, la IA lo pone a
## jugar. Tampoco se llama para el equipo del jugador humano.
func promover_banco_automatico(umbral_media: float = 3.0) -> Array:
	var promovidos := []
	for suplente in banco.duplicate():
		var actual_titular := -1.0
		for j in jugadores:
			if j["posicion"] == suplente["posicion"]:
				actual_titular = j["media"]
				break
		if actual_titular >= 0.0 and suplente["media"] >= actual_titular + umbral_media:
			var resultado := promover_a_titular(suplente["id"])
			if not resultado.is_empty():
				promovidos.append(resultado)
	return promovidos
