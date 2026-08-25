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
## §3/§7.4.7. Estaba en 0,1: con eso, TRES días alcanzaban para recuperar
## todo lo que cuesta un partido, así que jugar entre semana no tenía
## consecuencia y el calendario apretado era decorativo. Con 0,055, una
## semana completa recupera casi todo y media semana deja al plantel a
## ~80%, que es donde la carga de entrenamiento pasa a ser una decisión.
const RECUPERACION_FATIGA_POR_DIA := 0.055
## §3: velocidad de la deriva natural del ánimo hacia 50 (por semana).
const DERIVA_ANIMO_POR_SEMANA := 1.0

var nombre: String
var jugadores: Array = []  # 11 dicts (PlayerGenerator.generate), uno por puesto de FORMACION (titulares)
var banco: Array = []  # 7 dicts, uno por puesto de BANCO_FORMACION (suplentes)
var local: bool = false
var estilo: String = ""  # Tiki taka/Contragolpe/Juego directo/Presión alta/Defensivo/Físico, ver core/estilos.gd
var dt: Dictionary = {}  # {"nivel":1-10, "rasgo":Conservador/Loco/Cantera/Chequera}, ver core/dt.gd
## Formación elegida (ver core/formaciones.gd). El slot `i` de la
## formación lo ocupa jugadores[i], así que el ORDEN de esa lista es la
## alineación y no un detalle interno.
var formacion: String = Formaciones.POR_DEFECTO

## §7.4.1: carga de entrenamiento de la semana en curso. Se elige entre
## fecha y fecha; lo que importa para la progresión es el PROMEDIO de la
## temporada, que se acumula en carga_suma/carga_semanas.
var carga_entrenamiento: String = CargaEntrenamiento.POR_DEFECTO
var carga_suma: float = 0.0
var carga_semanas: float = 0.0

var calidad_cancha: float = 0.0  # -8..+3, ver core/estado_cancha.gd — rige cuando este club juega de local
var clima_partido: String = ""  # transitorio, solo dentro de un partido — "" (normal) / Lluvia / Calor / Viento, ver core/clima.gd
var arbitro_partido: String = ""  # transitorio, solo dentro de un partido — Estricto/Permisivo/Casero, ver core/arbitro.gd
var objetivo_en_riesgo: bool = false  # transitorio, lo recalcula GameState antes de cada fecha — ver core/objetivos.gd
var foco_individual: Dictionary = {}  # jugador_id -> atributo (String), foco de ESTA temporada — ver core/entrenamiento.gd
## Fans (§8.4 #22, ver core/fans.gd) — a diferencia de estilo/DT/cancha,
## arranca en 0 para todos ("no va nadie al estadio") y evoluciona con
## resultados/ascensos. racha_sin_ganar es un contador AUXILIAR entre
## partidos (distinto de "racha" de arriba, que es DENTRO de un partido).
var fans: float = 0.0
var racha_sin_ganar: int = 0
var rival_directo: String = ""  # nombre del clásico horneado (§8.4 #14) — ver core/rivalidad.gd
## §10.5/§15 (objetivo de directiva categoría "cantera", ver core/
## objetivos.gd): cuántas veces se promovió a un canterano (cantera->banco
## o banco->titular, ver promover_juvenil/promover_a_titular más abajo)
## en la temporada en curso — cuenta tanto las manuales del jugador humano
## como las automáticas de la IA, porque el incremento vive DENTRO de esas
## dos funciones, no en el llamador. Se resetea a 0 en GameState al cerrar
## cada temporada, después de leerlo para evaluar el objetivo.
var promociones_temporada: int = 0
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

## §8.7 "hasta 5 cambios": quién está efectivamente en cancha AHORA, no
## solo en el plantel de partido (jugadores+banco). Arranca en los 11
## titulares en reset_partido() y MatchEngine.MAX_CAMBIOS (Team.MAX_CAMBIOS)
## la va actualizando en las ventanas de cambio (entretiempo, 60', 75').
var en_cancha: Array = []  # jugador_id
var cambios_realizados: int = 0
const MAX_CAMBIOS := 5

## Preferencia del club para las sustituciones automáticas (no hay partido
## interactivo todavía, así que se configura antes de la fecha, no en vivo):
## "descanso" saca gente cansada más temprano para cuidarla de cara a la
## fecha siguiente, "rendimiento" solo cambia por lesión o agotamiento
## real, "equilibrado" es el punto medio (default para la IA).
var config_cambios: String = "equilibrado"

## Fase 5: estado que persiste entre partidos (a diferencia de resistencia,
## que es solo dentro de un partido y siempre arranca desde fatiga_acumulada).
var fatiga_acumulada: Dictionary = {}  # jugador_id -> 0..1, 1 = totalmente descansado
var animo: Dictionary = {}  # jugador_id -> 0..100 (§3)
var lesiones: Dictionary = {}  # jugador_id -> {"tipo":String, "dias_restantes":int}

## Tarjetas (§8.7). amarillas_partido/expulsados_partido son SOLO del
## partido en curso (reset_partido() los limpia); suspendidos persiste
## entre partidos — lo decrementa Liga.jugar_fecha con un snapshot tomado
## ANTES de jugar cada fecha, para que una expulsión de HOY no se sirva y
## se borre sola en el mismo cierre en el que ocurrió.
var amarillas_partido: Dictionary = {}  # jugador_id -> cantidad en el partido actual
var expulsados_partido: Dictionary = {}  # jugador_id -> true, no disponible por el resto de ESTE partido
var suspendidos: Dictionary = {}  # jugador_id -> partidos que todavia tiene que cumplir

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
## §9.3 extendido: pagando exactamente esto por un jugador, la venta es
## obligatoria — sin la resistencia que tiene una oferta común (ver
## Mercado.resistencia_venta). Se fija al ficharlo (_registrar_fichaje) y
## no cambia mientras esté en el club.
var clausulas: Dictionary = {}  # jugador_id -> monto de la cláusula
var reputacion: float = 50.0  # 0-100, afecta entradas/sponsors (§10.5)
var quebrado: bool = false
## Objetivos de directiva (§10.5/§15): la directiva te pide un resultado
## concreto cada temporada, ver core/objetivos.gd. Solo tiene sentido para
## el equipo del jugador humano (Objetivos.evaluar/GameState._cerrar_temporada
## deciden si se cumplió); los clubes de la IA lo dejan siempre vacío.
var objetivo_temporada: Dictionary = {}  # {"tipo","descripcion","posicion_maxima"}
var objetivos_incumplidos_seguidos: int = 0
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
## pais (§10.1): pool de nombre/apellido de los jugadores generados — ver
## PlayerGenerator.generate. "Uruguay" (default) para los 200 clubes de la
## pirámide, el país real para los clubes del exterior.
## realizacion: cuánto del techo trae puesto un titular (ver
## PlayerGenerator._roll_attribute). Por división lo decide NivelDivision;
## los clubes que se generan sueltos (tests, exterior, selecciones) se
## quedan con la banda por defecto.
static func generar(nombre: String, rng: RandomNumberGenerator, id_inicial: int = 0, potencial_objetivo: int = -1, pais: String = "Uruguay", realizacion: Vector2 = PlayerGenerator.REALIZACION_TITULAR) -> Team:
	var t := Team.new()
	t.nombre = nombre
	var next_id := id_inicial
	for pos in FORMACION:
		var jugador := PlayerGenerator.generate(next_id, rng, pos, potencial_objetivo, pais, realizacion)
		next_id += 1
		t.jugadores.append(jugador)
		t._registrar_fichaje(jugador, ValorJugador.calcular(jugador, 50.0, 3), rng.randi_range(1, 5))
		t.armonia += Personalidad.bonus_armonia(jugador)
	# El banco nace con menos techo realizado que el once (ver
	# NivelDivision.FACTOR_SUPLENTE). Antes salia del mismo molde y
	# quedaba tan bueno como el titular (+0,2 de media), asi que perder a
	# un titular no costaba nada: entraba alguien identico. Se baja el
	# banco en vez de subir el once a proposito — media_equipo() mira solo
	# a los titulares y es el numero contra el que estan calibrados la
	# economia, los objetivos y la paridad entre los dos motores.
	for pos in BANCO_FORMACION:
		var jugador := PlayerGenerator.generate(next_id, rng, pos, potencial_objetivo, pais,
			realizacion * NivelDivision.FACTOR_SUPLENTE)
		next_id += 1
		t.banco.append(jugador)
		t._registrar_fichaje(jugador, ValorJugador.calcular(jugador, 50.0, 3), rng.randi_range(1, 5))
		t.armonia += Personalidad.bonus_armonia(jugador)
	t.armonia += rng.randf_range(-3.0, 5.0)
	t.estilo = Estilos.generar(rng)
	t.dt = DT.generar(rng)
	t.config_cambios = DT.config_cambios_de(t.dt["nivel"])
	t.reputacion = clamp(t.media_equipo(), 20.0, 80.0)
	t.calidad_cancha = EstadoCancha.generar(t.reputacion, rng)
	t.scouts = [{"nivel": 1}]
	t.instalaciones = Instalaciones.nivel_inicial()
	for categoria in Economia.CATEGORIAS_CAJA:
		t.caja[categoria] = 0.0
		t.presupuesto_temporada[categoria] = 0.0
		t.caja_al_cierre[categoria] = 0.0
	t.siguiente_id_cantera = id_inicial + FORMACION.size() + BANCO_FORMACION.size()
	t.recalcular_capitan()
	return t


## Guardado de partida (§12 del GDD, "guardado... y guardado incremental"
## simplificado a JSON entero por ahora — ver game/game_state.gd). Todo lo
## que persiste entre sesiones, MENOS el estado de un partido en curso
## (resistencia, forma_partido, racha, avance, goles, amarillas_partido,
## expulsados_partido): un guardado solo se hace entre fechas, nunca a
## mitad de un partido, así que esos campos siempre están vacíos/en su
## valor de reposo en ese momento — no hace falta guardarlos.
##
## prestados_afuera/prestados_propios guardan el NOMBRE del club en vez de
## la referencia (JSON no puede serializar un Team) — Piramide.cargar()
## hace una segunda pasada (resolver_prestamos) para convertir esos
## nombres de vuelta en referencias reales, una vez que todos los equipos
## de la pirámide ya existen.
func guardar() -> Dictionary:
	var prestados_afuera_datos := {}
	for id in prestados_afuera:
		var info: Dictionary = prestados_afuera[id]
		prestados_afuera_datos[str(id)] = {
			"club_nombre": info["club"].nombre, "temporada_retorno": info["temporada_retorno"], "desde_cantera": info["desde_cantera"],
		}
	var prestados_propios_datos := {}
	for id in prestados_propios:
		var info: Dictionary = prestados_propios[id]
		prestados_propios_datos[str(id)] = {
			"club_dueno_nombre": info["club_dueno"].nombre, "temporada_retorno": info["temporada_retorno"],
		}

	return {
		"nombre": nombre, "estilo": estilo, "dt": dt, "calidad_cancha": calidad_cancha,
		"formacion": formacion,
		"carga_entrenamiento": carga_entrenamiento,
		"carga_suma": carga_suma, "carga_semanas": carga_semanas,
		"jugadores": jugadores, "banco": banco, "cantera": cantera,
		"siguiente_id_cantera": siguiente_id_cantera, "capitan_id": capitan_id,
		"fatiga_acumulada": _claves_a_texto(fatiga_acumulada),
		"animo": _claves_a_texto(animo),
		"lesiones": _claves_a_texto(lesiones),
		"suspendidos": _claves_a_texto(suspendidos),
		"caja": caja, "presupuesto_temporada": presupuesto_temporada, "caja_al_cierre": caja_al_cierre,
		"sueldos": _claves_a_texto(sueldos), "contratos": _claves_a_texto(contratos),
		"clausulas": _claves_a_texto(clausulas),
		"reputacion": reputacion, "quebrado": quebrado, "scouts": scouts, "instalaciones": instalaciones,
		"config_cambios": config_cambios,
		"objetivo_temporada": objetivo_temporada, "objetivos_incumplidos_seguidos": objetivos_incumplidos_seguidos,
		"foco_individual": _claves_a_texto(foco_individual),
		"fans": fans, "racha_sin_ganar": racha_sin_ganar, "rival_directo": rival_directo,
		"promociones_temporada": promociones_temporada,
		"prestados_afuera": prestados_afuera_datos, "prestados_propios": prestados_propios_datos,
	}


static func cargar(datos: Dictionary) -> Team:
	var t := Team.new()
	t.nombre = datos["nombre"]
	if datos.has("estilo"):
		t.estilo = datos["estilo"]
	else:
		# Migracion de guardados de antes de que existiera §8.6.3 (choque de
		# estilos): en vez de dejarlo en "" para siempre (matchup neutro
		# eterno), se le sortea un estilo determinado por el nombre del
		# club, asi es estable entre cargas sucesivas del mismo guardado.
		var rng_migracion := RandomNumberGenerator.new()
		rng_migracion.seed = hash(datos["nombre"])
		t.estilo = Estilos.generar(rng_migracion)
	if datos.has("dt"):
		t.dt = datos["dt"]
	else:
		# Misma migracion que estilo, para guardados de antes de §8.6.4.
		var rng_migracion_dt := RandomNumberGenerator.new()
		rng_migracion_dt.seed = hash(datos["nombre"]) + 1  # +1 para no repetir la tirada de estilo
		t.dt = DT.generar(rng_migracion_dt)
	t.carga_entrenamiento = str(datos.get("carga_entrenamiento", CargaEntrenamiento.POR_DEFECTO))
	if not CargaEntrenamiento.existe(t.carga_entrenamiento):
		t.carga_entrenamiento = CargaEntrenamiento.POR_DEFECTO
	t.carga_suma = float(datos.get("carga_suma", 0.0))
	t.carga_semanas = float(datos.get("carga_semanas", 0.0))
	t.formacion = str(datos.get("formacion", Formaciones.POR_DEFECTO))
	if not Formaciones.existe(t.formacion):
		t.formacion = Formaciones.POR_DEFECTO
	if datos.has("calidad_cancha"):
		t.calidad_cancha = datos["calidad_cancha"]
	else:
		# Misma migracion, para guardados de antes de §8.4/§8.6.2.
		var rng_migracion_cancha := RandomNumberGenerator.new()
		rng_migracion_cancha.seed = hash(datos["nombre"]) + 2  # +2 para no repetir estilo ni dt
		t.calidad_cancha = EstadoCancha.generar(datos["reputacion"], rng_migracion_cancha)
	t.jugadores = _normalizar_jugadores(datos["jugadores"])
	t.banco = _normalizar_jugadores(datos["banco"])
	t.cantera = _normalizar_jugadores(datos["cantera"])
	t.siguiente_id_cantera = datos["siguiente_id_cantera"]
	t.capitan_id = datos["capitan_id"]
	t.fatiga_acumulada = _claves_a_entero(datos["fatiga_acumulada"])
	t.animo = _claves_a_entero(datos["animo"])
	t.lesiones = _claves_a_entero(datos["lesiones"])
	t.suspendidos = _claves_a_entero(datos.get("suspendidos", {}))
	t.caja = datos["caja"]
	t.presupuesto_temporada = datos["presupuesto_temporada"]
	t.caja_al_cierre = datos["caja_al_cierre"]
	t.sueldos = _claves_a_entero(datos["sueldos"])
	t.contratos = _claves_a_entero(datos["contratos"])
	t.clausulas = _claves_a_entero(datos.get("clausulas", {}))
	t.reputacion = datos["reputacion"]
	t.quebrado = datos["quebrado"]
	t.scouts = datos["scouts"]
	t.instalaciones = datos["instalaciones"]
	t.config_cambios = datos.get("config_cambios", "equilibrado")
	# JSON.parse() vuelve todos los numeros como float -- "posicion_maxima"
	# despues se compara con un int (posicion_final) via <=, que en GDScript
	# anda bien entre int/float, pero se normaliza igual por consistencia
	# con el resto de los campos numericos del guardado.
	t.objetivo_temporada = datos.get("objetivo_temporada", {}).duplicate()
	if t.objetivo_temporada.has("posicion_maxima"):
		t.objetivo_temporada["posicion_maxima"] = int(t.objetivo_temporada["posicion_maxima"])
	t.objetivos_incumplidos_seguidos = int(datos.get("objetivos_incumplidos_seguidos", 0))
	t.foco_individual = _claves_a_entero(datos.get("foco_individual", {}))
	t.fans = datos.get("fans", 0.0)
	t.racha_sin_ganar = int(datos.get("racha_sin_ganar", 0))
	t.rival_directo = datos.get("rival_directo", "")
	t.promociones_temporada = int(datos.get("promociones_temporada", 0))

	# Quedan con el NOMBRE del club (String) en la clave "club"/"club_dueno"
	# en vez de la referencia real -- Piramide.resolver_prestamos() los
	# reemplaza por el Team de verdad una vez que toda la pirámide está
	# cargada (acá, en el medio de cargar UN equipo, los demás todavía ni
	# existen).
	t.prestados_afuera = {}
	for id_str in datos.get("prestados_afuera", {}):
		var info: Dictionary = datos["prestados_afuera"][id_str]
		t.prestados_afuera[int(id_str)] = {
			"club": info["club_nombre"], "temporada_retorno": info["temporada_retorno"], "desde_cantera": info["desde_cantera"],
		}
	t.prestados_propios = {}
	for id_str in datos.get("prestados_propios", {}):
		var info: Dictionary = datos["prestados_propios"][id_str]
		t.prestados_propios[int(id_str)] = {
			"club_dueno": info["club_dueno_nombre"], "temporada_retorno": info["temporada_retorno"],
		}

	return t


static func _claves_a_texto(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out


static func _claves_a_entero(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[int(k)] = d[k]
	return out


## JSON no distingue int de float: TODO número vuelve como float al
## parsear (JSON.parse). Sin esto, un jugador cargado tendría "id" en
## 5.0 en vez de 5 — y como los Dictionary de Godot distinguen 5 (int) de
## 5.0 (float) como claves DISTINTAS, cualquier dict.get(jugador["id"])
## en todo el resto del motor (sueldos, contratos, ánimo, sueldos del
## mercado, etc.) fallaría en silencio después de cargar una partida.
static func _normalizar_jugadores(lista: Array) -> Array:
	for j in lista:
		j["id"] = int(j["id"])
		j["edad"] = int(j["edad"])
		j["potencial"] = int(j["potencial"])
		j["propension_lesion"] = int(j["propension_lesion"])
		if j.has("foco_temporadas_consecutivas"):
			j["foco_temporadas_consecutivas"] = int(j["foco_temporadas_consecutivas"])
		if j.has("partidos_seguidos_titular"):
			j["partidos_seguidos_titular"] = int(j["partidos_seguidos_titular"])
		if j.has("partidos_seguidos_banco"):
			j["partidos_seguidos_banco"] = int(j["partidos_seguidos_banco"])
		# §7.3: el uso acumulado va en float y JSON lo devuelve como float,
		# asi que no hay que normalizarlo; solo garantizar que exista.
		if not j.has("xp_uso"):
			j["xp_uso"] = {}
		for attr in j["atributos"]:
			j["atributos"][attr] = int(j["atributos"][attr])
		# §7.2: los guardados anteriores a los techos por atributo no
		# traen el campo. Se derivan del id, que es estable, en vez de
		# dejar el potencial global plano: si no, un jugador viejo nunca
		# tendría la individualidad que sí tienen los nuevos.
		if not j.has("potenciales") or (j["potenciales"] as Dictionary).is_empty():
			j["potenciales"] = PlayerGenerator.techos_derivados(int(j["potencial"]), int(j["id"]))
		else:
			for attr in j["potenciales"]:
				j["potenciales"][attr] = int(j["potenciales"][attr])
	return lista


## Promedio de carga de la temporada, para la progresión. Se resetea al
## cerrar la temporada (ver Liga.fin_de_temporada).
func factor_carga_temporada() -> float:
	if carga_semanas <= 0.0:
		return 1.0
	return carga_suma / carga_semanas


func reiniciar_carga() -> void:
	carga_suma = 0.0
	carga_semanas = 0.0


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
		if puede_jugar(j["id"]):
			count += 1
	return count


## §8.7: disponible para jugar AHORA — ni lesionado, ni expulsado en el
## partido en curso, ni cumpliendo una suspensión por tarjetas.
func puede_jugar(jugador_id: int) -> bool:
	return not esta_lesionado(jugador_id) and not expulsados_partido.has(jugador_id) and suspendidos.get(jugador_id, 0) <= 0


## Cuánto más que el valor de mercado hace falta pagar para forzar una
## venta sin resistencia (ver Mercado.pagar_clausula).
const FACTOR_CLAUSULA := 1.8


## Da de alta a un jugador que se suma al plantel (fichaje, ascenso desde
## cantera): sueldo, contrato, ánimo neutro, totalmente descansado,
## cláusula de rescisión nueva.
func _registrar_fichaje(jugador: Dictionary, valor: float, contrato_anios: int = 3) -> void:
	var id: int = jugador["id"]
	sueldos[id] = Economia.sueldo_sugerido(valor) * Personalidad.factor_sueldo(jugador)
	contratos[id] = contrato_anios
	animo[id] = 50.0
	fatiga_acumulada[id] = 1.0
	clausulas[id] = valor * FACTOR_CLAUSULA


## Da de baja a un jugador que se va del club (vendido, liberado).
func _limpiar_registro(id: int) -> void:
	sueldos.erase(id)
	contratos.erase(id)
	animo.erase(id)
	fatiga_acumulada.erase(id)
	lesiones.erase(id)
	clausulas.erase(id)


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
## Intercambia dos jugadores del plantel, estén donde estén (dos
## titulares entre sí, o un titular con uno del banco). Es lo que necesita
## la pantalla de formación: mover a alguien de slot no es "promoverlo",
## es cambiarlo de lugar.
##
## Devuelve false si alguno no está o si son el mismo. NO valida puestos a
## propósito: poner a un defensor de 9 es una decisión del DT, mala pero
## suya, y el motor ya la castiga solo (juega con SUS atributos en el rol
## del slot).
func intercambiar(id_a: int, id_b: int) -> bool:
	if id_a == id_b:
		return false
	var a := _ubicar(id_a)
	var b := _ubicar(id_b)
	if a.is_empty() or b.is_empty():
		return false
	var lista_a: Array = jugadores if a["titular"] else banco
	var lista_b: Array = jugadores if b["titular"] else banco
	var tmp: Dictionary = lista_a[a["idx"]]
	lista_a[a["idx"]] = lista_b[b["idx"]]
	lista_b[b["idx"]] = tmp
	return true


func _ubicar(jugador_id: int) -> Dictionary:
	for i in range(jugadores.size()):
		if jugadores[i]["id"] == jugador_id:
			return {"titular": true, "idx": i}
	for i in range(banco.size()):
		if banco[i]["id"] == jugador_id:
			return {"titular": false, "idx": i}
	return {}


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
	promociones_temporada += 1
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
	amarillas_partido.clear()
	expulsados_partido.clear()
	en_cancha = jugadores.map(func(j): return j["id"])
	cambios_realizados = 0
	for j in todos_los_jugadores():
		resistencia[j["id"]] = fatiga_acumulada.get(j["id"], 1.0)


## Los 11 (o menos, si hubo rojas) que están efectivamente jugando ahora
## mismo, después de aplicar los cambios que se hayan hecho en el partido.
func jugadores_en_cancha() -> Array:
	var todos := todos_los_jugadores()
	var out := []
	for j in todos:
		if en_cancha.has(j["id"]):
			out.append(j)
	return out


## Cambio en firme: sale un jugador de la cancha, entra otro del banco.
## No valida nada (posición, disponibilidad) — eso lo decide quien llama,
## MatchEngine._procesar_cambios.
func sustituir(id_sale: int, id_entra: int) -> void:
	en_cancha.erase(id_sale)
	en_cancha.append(id_entra)
	cambios_realizados += 1


func jugadores_por_posiciones(posiciones: Array) -> Array:
	var out := []
	for j in jugadores:
		if posiciones.has(j["posicion"]):
			out.append(j)
	return out


## Busca entre los que están EN CANCHA ahora mismo (§8.7, ver en_cancha) y
## descarta lesionados, expulsados (este partido) y suspendidos. Si no
## queda nadie disponible en esas posiciones, cae a cualquiera disponible
## en cancha; si NADIE de la cancha está disponible (caso extremo: varias
## lesiones/rojas seguidas y ya no quedan cambios), amplía la búsqueda a
## todo el plantel como último recurso (ver Liga._resolver_forfeit).
func jugadores_disponibles_por_posiciones(posiciones: Array) -> Array:
	var en_posicion := []
	var disponibles := []
	var en_cancha_dicts := jugadores_en_cancha()
	for j in en_cancha_dicts:
		if not puede_jugar(j["id"]):
			continue
		disponibles.append(j)
		if posiciones.has(j["posicion"]):
			en_posicion.append(j)
	if not en_posicion.is_empty():
		return en_posicion
	if not disponibles.is_empty():
		return disponibles
	return todos_los_jugadores()


## El arquero que está EN CANCHA ahora mismo (si hubo un cambio de arquero
## a mitad de partido, en_cancha ya refleja al suplente). Si por lo que
## sea ninguno de los que están en cancha califica, cae al titular
## original de todos modos (ver Liga._resolver_forfeit para el caso de que
## falten demasiados jugadores para jugar el partido).
func arquero() -> Dictionary:
	for j in jugadores_en_cancha():
		if j["posicion"] == "ARQ" and puede_jugar(j["id"]):
			return j
	var titular: Dictionary = {}
	for j in jugadores:
		if j["posicion"] == "ARQ":
			titular = j
			break
	if not titular.is_empty() and puede_jugar(titular["id"]):
		return titular
	for j in banco:
		if j["posicion"] == "ARQ" and puede_jugar(j["id"]):
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
## de 0.55 dentro de un partido. §8.4 #19: con Calor, un 30% más rápido.
## multiplicador: cuánto pesa ESTE duelo en el desgaste. MatchEngine usa
## 1.0 (está calibrado sobre sus ~180 duelos por partido); MotorEspacial
## pasa otro valor porque resuelve una cantidad de duelos completamente
## distinta y, con 1.0, dejaba a los 22 jugadores en el piso de
## resistencia antes del entretiempo.
func desgastar(jugador_id: int, energia_attr: int, multiplicador: float = 1.0) -> void:
	var decay: float = 0.006 * (1.3 - float(energia_attr) / 100.0) * Clima.factor_energia(clima_partido) * multiplicador
	resistencia[jugador_id] = max(0.55, resistencia_pct(jugador_id) - decay)


func esta_lesionado(jugador_id: int) -> bool:
	return lesiones.has(jugador_id)


func lesionar(jugador_id: int, tipo: String, dias: int) -> void:
	lesiones[jugador_id] = {"tipo": tipo, "dias_restantes": dias}


## Se llama al terminar cada partido: la resistencia con la que se terminó
## pasa a ser el nuevo piso de fatiga acumulada (§3, "energía" de mediano
## plazo), y el ánimo se mueve según el resultado (±3, con el bonus de gol
## y los rasgos de personalidad que lo modifican — Positivo/Bajón/
## Egolatra, ver Personalidad.ajustar_delta_animo) siguiendo el GDD §3
## simplificado — todavía no hay xG ni stats de pases/duelos por jugador
## para el criterio completo por puesto.
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
		delta = Personalidad.ajustar_delta_animo(j, delta, id == capitan_id)
		delta = clamp(delta, -8.0, 8.0)  # tope un poco mas ancho que el base (±6): Bajon/Egolatra pueden empujarlo mas
		animo[id] = clamp(animo.get(id, 50.0) + delta, 0.0, 100.0)


## Avanza el calendario entre fechas: recupera fatiga, hace derivar el ánimo
## hacia 50 y cuenta los días de lesión. Devuelve los ids que se recuperaron.
func avanzar_dias(dias: int) -> Array:
	for j in todos_los_jugadores():
		var id: int = j["id"]
		var recuperacion: float = RECUPERACION_FATIGA_POR_DIA 			* Personalidad.factor_recuperacion_fatiga(j) 			* Instalaciones.factor_recuperacion_fatiga(self) 			* CargaEntrenamiento.factor_recuperacion(carga_entrenamiento)
		fatiga_acumulada[id] = min(1.0, fatiga_acumulada.get(id, 1.0) + recuperacion * dias)
		var actual: float = animo.get(id, 50.0)
		var deriva: float = clamp(50.0 - actual, -DERIVA_ANIMO_POR_SEMANA, DERIVA_ANIMO_POR_SEMANA) * (dias / 7.0)
		animo[id] = clamp(actual + deriva, 0.0, 100.0)

	# La carga de ESTA semana cuenta para el promedio de la temporada,
	# ponderada por los días: una semana de dos partidos con carga baja
	# pesa lo mismo que cualquier otra semana de la misma duración.
	carga_suma += CargaEntrenamiento.factor_crecimiento(carga_entrenamiento) * (float(dias) / 7.0)
	carga_semanas += float(dias) / 7.0

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


## §14 + §17: convocatoria de emergencia. Si las bajas (lesiones, rojas,
## suspensiones) dejan al plantel por debajo del mínimo para presentarse,
## suben juveniles de la cantera como refuerzo — que es lo que hace un
## club de verdad, no perder 0-3 por no presentarse teniendo siete pibes
## en reserva. Vuelven solos a la cantera cuando el plantel se recupera.
##
## No es una promoción: el juvenil NO firma contrato ni cobra sueldo
## mientras está convocado (por eso no pasa por _registrar_fichaje) y no
## cuenta para el objetivo de cantera — promoverlo de verdad sigue siendo
## una decisión aparte, ver promover_juvenil. Tampoco desplaza a nadie:
## el banco crece mientras dura la emergencia, porque el punto es sumar
## gente disponible y un swap dejaría el conteo igual que antes.
##
## Devuelve {"subidos":Array, "bajados":Array} para que quien llame pueda
## contarlo como noticia.
func ajustar_convocatorias_de_emergencia(minimo: int) -> Dictionary:
	var subidos := []
	var bajados := []

	# Primero devolver a los que ya no hacen falta. Un convocado lesionado
	# se va igual (no aporta), y uno sano solo si el plantel sigue
	# llegando al mínimo sin él.
	var i := banco.size() - 1
	while i >= 0:
		var j: Dictionary = banco[i]
		if bool(j.get("convocado_emergencia", false)):
			var aporta: int = 1 if puede_jugar(j["id"]) else 0
			if jugadores_sanos_count() - aporta >= minimo:
				j.erase("convocado_emergencia")
				# Baja del contrato temporal, pero NO de animo/fatiga/lesiones:
				# _limpiar_registro borraria tambien la lesion y el pibe
				# volveria a la cantera curado de arriba.
				sueldos.erase(j["id"])
				contratos.erase(j["id"])
				clausulas.erase(j["id"])
				banco.remove_at(i)
				cantera.append(j)
				bajados.append(j)
		i -= 1

	# Después llamar a los que hagan falta, del mejor para abajo.
	while jugadores_sanos_count() < minimo:
		var idx := _mejor_juvenil_disponible()
		if idx < 0:
			break
		var juvenil: Dictionary = cantera[idx]
		cantera.remove_at(idx)
		juvenil["convocado_emergencia"] = true
		# Contrato corto de debutante. Se da de alta igual que un fichaje
		# porque el resto del juego da por hecho que todo el que está en
		# el plantel tiene sueldo, contrato y ánimo (lo verifica
		# test_phase6): un jugador sin alta rompe economía y mercado. Se
		# le da de baja al devolverlo a la cantera, más arriba.
		_registrar_fichaje(juvenil, ValorJugador.calcular(juvenil, 50.0, 1), 1)
		banco.append(juvenil)
		subidos.append(juvenil)

	return {"subidos": subidos, "bajados": bajados}


## El juvenil sano de mayor media. -1 si no queda ninguno disponible.
func _mejor_juvenil_disponible() -> int:
	var mejor := -1
	for i in range(cantera.size()):
		if not puede_jugar(cantera[i]["id"]):
			continue
		if mejor == -1 or cantera[i]["media"] > cantera[mejor]["media"]:
			mejor = i
	return mejor


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
	promociones_temporada += 1

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
