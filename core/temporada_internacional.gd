class_name TemporadaInternacional
extends RefCounted

## La temporada internacional EN CURSO — las tres copas de §10.2-§10.4
## jugándose ronda a ronda, intercaladas con el campeonato.
##
## Antes las tres copas se resolvían enteras de un saque al cerrar la
## temporada (Confederacion.jugar_temporada_internacional): el club del
## jugador clasificaba, y se enteraba del resultado por el feed sin haber
## jugado un solo partido. Ahora la temporada internacional es una máquina
## de estados que avanza UNA ronda por llamada, igual que la Copa del Rey,
## y el cruce del club del jugador se juega con el motor espacial y con
## fotogramas cuando le toca (ver GameState.jugar_partido_internacional).
##
## El orden de las rondas es el mismo de siempre:
##
##   1. Previa: 12 clubes de los países de coeficiente bajo, 6 cruces a
##      partido único. El ganador va a Campeones, el perdedor a Guerreros.
##      Uruguay arranca 12°, así que el club del jugador puede caer acá.
##   2. Fase de liga: 8 fechas en Campeones, 6 en Guerreros y Emergentes.
##      Una fecha por ronda, las tres copas a la vez.
##   3. Playoff: del 9° al 24° de la fase de liga, a partido único, por
##      los últimos 8 lugares de octavos.
##   4. Knockout: octavos, cuartos, semi y final (reusa Copa).
##
## Cada copa lleva su propio paso: Campeones necesita 13 rondas y las
## otras dos 11, así que no terminan todas juntas.

## Las tres copas, en el orden en que se juegan y se muestran.
const CLAVES := ["campeones", "guerreros", "emergentes"]

## Cuántos pasan directo a octavos desde la fase de liga (§10.3), y
## cuántos como mucho juegan el playoff por los otros ocho lugares.
const DIRECTOS_A_OCTAVOS := 8
const MAX_EN_PLAYOFF := 16

## Cruces de la previa todavía sin jugar: [[Team, Team], ...]. Vacío en
## cuanto se juega, que es la primera ronda de todas.
var previa_pendiente: Array = []
var previa_resultados: Array = []

## Los cupos directos de cada copa, esperando a que la previa reparta sus
## seis ganadores y sus seis perdedores. Se vacía al armar las fases de
## liga: de ahí en más el estado vive en `copas`.
var cupos_directos: Dictionary = {}  # clave -> Array[Team]

## clave -> estado de esa copa. Ver _nueva_copa.
var copas: Dictionary = {}

## El partido del club seguido en la ronda que se acaba de jugar, con
## fotogramas para verlo, y en qué torneo fue. TRANSITORIO: no se guarda
## y se pisa en cada ronda. Mismo contrato que Copa.seguido.
var seguido: Dictionary = {}
var torneo_seguido: String = ""
## Si el partido seguido era a eliminación directa. Un empate en la fase
## de liga no elimina a nadie, así que la noticia no puede decir lo mismo.
var seguido_eliminatorio: bool = false


## `cupos` viene de Confederacion._asignar_cupos: los directos de cada
## copa y los doce cruces de la previa ya sorteados.
static func iniciar(cupos: Dictionary) -> TemporadaInternacional:
	var t := TemporadaInternacional.new()
	t.previa_pendiente = cupos["previa"].duplicate()
	for clave in CLAVES:
		t.cupos_directos[clave] = cupos[clave].duplicate()
	# Sin previa que jugar (una confederación armada a mano en un test),
	# las fases de liga arrancan con los directos y nada más.
	if t.previa_pendiente.is_empty():
		t._armar_fases_de_liga()
	return t


static func _nueva_copa(nombre: String, equipos: Array, fechas: int) -> Dictionary:
	return {
		"nombre": nombre,
		"fase": FaseLiga.iniciar(nombre, equipos, fechas),
		"fecha": 0,
		"directos": [],
		"playoff_pendientes": [],
		"playoff_resultados": [],
		"eliminados": [],
		"knockout": null,
	}


## §10.3: Campeones juega 8 fechas de fase de liga, las otras dos 6.
func _armar_fases_de_liga() -> void:
	copas["campeones"] = _nueva_copa("Copa de Campeones", cupos_directos["campeones"], 8)
	copas["guerreros"] = _nueva_copa("Copa de Guerreros", cupos_directos["guerreros"], 6)
	copas["emergentes"] = _nueva_copa("Copa de Emergentes", cupos_directos["emergentes"], 6)
	cupos_directos = {}


func hay_pendiente() -> bool:
	if not previa_pendiente.is_empty():
		return true
	if copas.is_empty():
		return true
	for clave in CLAVES:
		if not _copa_terminada(copas[clave]):
			return true
	return false


func _copa_terminada(c: Dictionary) -> bool:
	var knockout: Copa = c["knockout"]
	return knockout != null and knockout.campeon != null


## Una ronda: la previa, o una fecha/playoff/ronda de knockout en cada una
## de las tres copas a la vez.
func jugar_siguiente_ronda(rng: RandomNumberGenerator, equipo_seguido: Team = null) -> void:
	seguido = {}
	torneo_seguido = ""
	seguido_eliminatorio = false
	if not previa_pendiente.is_empty():
		_jugar_previa(rng, equipo_seguido)
		return
	for clave in CLAVES:
		_avanzar_copa(copas[clave], rng, equipo_seguido)


## §10.2: seis cruces a partido único. El GDD pide ida y vuelta;
## simplificación como el resto de las copas de esta fase (ver Copa).
##
## El empate ya no lo gana el local: la previa la puede jugar el club del
## jugador, y definir un cruce suyo por quién era local sería regalarlo o
## robarlo. Se define como cualquier eliminatoria — alargue y penales.
func _jugar_previa(rng: RandomNumberGenerator, equipo_seguido: Team) -> void:
	var ganadores := []
	var perdedores := []
	for par in previa_pendiente:
		var a: Team = par[0]
		var b: Team = par[1]
		var es_el_del_jugador: bool = a == equipo_seguido or b == equipo_seguido
		var cruce := Copa.resolver_cruce(a, b, rng, es_el_del_jugador)
		var ganador: Team = cruce["ganador"]
		ganadores.append(ganador)
		perdedores.append(b if ganador == a else a)
		previa_resultados.append(Copa.fila_de_historial(cruce))
		if es_el_del_jugador:
			_tomar_seguido(cruce, "Previa internacional", true)
	previa_pendiente = []
	cupos_directos["campeones"].append_array(ganadores)
	cupos_directos["guerreros"].append_array(perdedores)
	_armar_fases_de_liga()


func _avanzar_copa(c: Dictionary, rng: RandomNumberGenerator, equipo_seguido: Team) -> void:
	var fase: FaseLiga = c["fase"]
	if int(c["fecha"]) < fase.fixture.size():
		fase.jugar_fecha(int(c["fecha"]), rng, equipo_seguido)
		c["fecha"] = int(c["fecha"]) + 1
		if not fase.seguido.is_empty():
			_tomar_detalle(fase.seguido, str(c["nombre"]), false)
		if int(c["fecha"]) >= fase.fixture.size():
			_armar_playoff(c, rng)
		return
	if not c["playoff_pendientes"].is_empty():
		_jugar_playoff(c, rng, equipo_seguido)
		return
	var knockout: Copa = c["knockout"]
	if knockout != null and knockout.campeon == null:
		knockout.jugar_siguiente_ronda(rng, equipo_seguido)
		if not knockout.seguido.is_empty():
			_tomar_detalle(knockout.seguido, str(c["nombre"]), true)


## §10.3: top 8 directo a octavos, del 9° al 24° a un playoff a partido
## único por los otros ocho lugares, el resto afuera.
func _armar_playoff(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var fase: FaseLiga = c["fase"]
	var ordenados := fase.equipos_ordenados()
	var n := ordenados.size()
	c["directos"] = ordenados.slice(0, mini(DIRECTOS_A_OCTAVOS, n))
	var resto: Array = ordenados.slice(mini(DIRECTOS_A_OCTAVOS, n), n)
	var tamano_pool: int = mini(MAX_EN_PLAYOFF, resto.size())
	# Un pool impar dejaría un cruce a medias: se corta al par de abajo y
	# el que sobra queda eliminado con los demás.
	tamano_pool -= tamano_pool % 2
	var pool: Array = resto.slice(0, tamano_pool)
	for equipo in resto.slice(tamano_pool, resto.size()):
		c["eliminados"].append(equipo.nombre)
	var pares := []
	for i in range(tamano_pool / 2):
		pares.append([pool[i], pool[tamano_pool - 1 - i]])
	c["playoff_pendientes"] = pares
	if pares.is_empty():
		_armar_knockout(c, [], rng)


func _jugar_playoff(c: Dictionary, rng: RandomNumberGenerator, equipo_seguido: Team) -> void:
	var ganadores := []
	for par in c["playoff_pendientes"]:
		var a: Team = par[0]
		var b: Team = par[1]
		var es_el_del_jugador: bool = a == equipo_seguido or b == equipo_seguido
		var cruce := Copa.resolver_cruce(a, b, rng, es_el_del_jugador)
		ganadores.append(cruce["ganador"])
		c["playoff_resultados"].append(Copa.fila_de_historial(cruce))
		if es_el_del_jugador:
			_tomar_seguido(cruce, "%s — Playoff" % str(c["nombre"]), true)
	c["playoff_pendientes"] = []
	_armar_knockout(c, ganadores, rng)


func _armar_knockout(c: Dictionary, ganadores_playoff: Array, rng: RandomNumberGenerator) -> void:
	var equipos_octavos: Array = c["directos"] + ganadores_playoff
	c["knockout"] = Copa.iniciar("%s - Eliminacion" % str(c["nombre"]), equipos_octavos, rng)


func _tomar_seguido(cruce: Dictionary, torneo: String, eliminatorio: bool) -> void:
	_tomar_detalle(Copa.detalle_seguido(cruce), torneo, eliminatorio)


func _tomar_detalle(detalle: Dictionary, torneo: String, eliminatorio: bool) -> void:
	seguido = detalle
	torneo_seguido = torneo
	seguido_eliminatorio = eliminatorio


## El cruce que le toca al club en la ronda que VIENE, para que la portada
## sepa si hay partido internacional hoy y contra quién:
## {"clave", "torneo", "ronda", "local", "visitante", "eliminatorio"}.
## Vacío si el club no juega la próxima ronda (no clasificó, ya lo
## eliminaron, o su copa terminó).
func cruce_de(equipo: Team) -> Dictionary:
	if equipo == null:
		return {}
	if not previa_pendiente.is_empty():
		for par in previa_pendiente:
			if par[0] == equipo or par[1] == equipo:
				return {"clave": "previa", "torneo": "Previa internacional",
					"ronda": "Cruce único", "local": par[0], "visitante": par[1],
					"eliminatorio": true}
		return {}
	for clave in CLAVES:
		var cruce := _cruce_en_copa(copas[clave], equipo)
		if not cruce.is_empty():
			cruce["clave"] = clave
			return cruce
	return {}


func _cruce_en_copa(c: Dictionary, equipo: Team) -> Dictionary:
	var fase: FaseLiga = c["fase"]
	var fecha := int(c["fecha"])
	if fecha < fase.fixture.size():
		var par := fase.cruce_de(equipo, fecha)
		if par.is_empty():
			return {}
		return {"torneo": str(c["nombre"]),
			"ronda": "Fecha %d de la fase de liga" % (fecha + 1),
			"local": par[0], "visitante": par[1], "eliminatorio": false}
	for par in c["playoff_pendientes"]:
		if par[0] == equipo or par[1] == equipo:
			return {"torneo": str(c["nombre"]), "ronda": "Playoff de octavos",
				"local": par[0], "visitante": par[1], "eliminatorio": true}
	var knockout: Copa = c["knockout"]
	if knockout != null:
		var par_knockout := knockout.cruce_de(equipo)
		if not par_knockout.is_empty():
			return {"torneo": str(c["nombre"]), "ronda": knockout.ronda_actual(),
				"local": par_knockout[0], "visitante": par_knockout[1],
				"eliminatorio": true}
	return {}


## Si el club juega alguna de las tres copas esta temporada. Lo mira el
## aviso de clasificación y la pantalla de copas.
func participa(equipo: Team) -> bool:
	if equipo == null:
		return false
	for par in previa_pendiente:
		if par[0] == equipo or par[1] == equipo:
			return true
	for clave in cupos_directos:
		if cupos_directos[clave].has(equipo):
			return true
	for clave in copas:
		var fase: FaseLiga = copas[clave]["fase"]
		if fase.equipos.has(equipo):
			return true
	return false


## En qué copa juega el club, por clave ("campeones"/...). "" si no juega
## ninguna, y "previa" mientras la previa no reparta los cupos.
func copa_de(equipo: Team) -> String:
	if equipo == null:
		return ""
	for par in previa_pendiente:
		if par[0] == equipo or par[1] == equipo:
			return "previa"
	for clave in CLAVES:
		if cupos_directos.has(clave) and cupos_directos[clave].has(equipo):
			return clave
		if copas.has(clave) and copas[clave]["fase"].equipos.has(equipo):
			return clave
	return ""


func campeon_de(clave: String) -> Team:
	if not copas.has(clave):
		return null
	var knockout: Copa = copas[clave]["knockout"]
	return knockout.campeon if knockout != null else null


## El resultado en el MISMO formato que devolvía
## Confederacion.jugar_temporada_internacional cuando resolvía las tres
## copas de un saque: es lo que leen los premios, la reputación, el
## resumen de temporada y el recálculo de coeficientes.
func resultado() -> Dictionary:
	var salida := {"previa": previa_resultados}
	for clave in CLAVES:
		if not copas.has(clave):
			continue
		var c: Dictionary = copas[clave]
		salida[clave] = {
			"fase_liga": c["fase"],
			"eliminados_pre_playoff": c["eliminados"],
			"partidos_playoff": c["playoff_resultados"],
			"knockout": c["knockout"],
			"campeon": campeon_de(clave),
		}
	return salida


## La foto plana que dibuja la pantalla de Copas: tabla de la fase de
## liga, playoff y rondas del knockout, sin objetos vivos adentro. Se
## saca DESPUÉS de cada ronda, no solo al terminar, así que la pantalla
## muestra la copa en curso (ver GameState.copas_internacionales).
func resumen(temporada: int) -> Dictionary:
	var salida := {"temporada": temporada, "en_curso": hay_pendiente()}
	for clave in CLAVES:
		if not copas.has(clave):
			continue
		var c: Dictionary = copas[clave]
		var fase: FaseLiga = c["fase"]
		var tabla := []
		for nombre_equipo in fase.tabla_ordenada():
			var fila: Dictionary = fase.tabla[nombre_equipo].duplicate()
			fila["equipo"] = nombre_equipo
			tabla.append(fila)
		var knockout: Copa = c["knockout"]
		var campeon := campeon_de(clave)
		salida[clave] = {
			"nombre": str(c["nombre"]),
			"tabla": tabla,
			"playoff": c["playoff_resultados"],
			"rondas": knockout.historial if knockout != null else [],
			"campeon": campeon.nombre if campeon != null else "",
			"fecha": int(c["fecha"]),
			"fechas": fase.fixture.size(),
		}
	return salida


## Guardado. Los Team viajan por NOMBRE y se relocalizan al cargar con el
## índice de Confederacion, que junta la pirámide y los clubes del
## exterior ya materializados.
func guardar() -> Dictionary:
	var directos := {}
	for clave in cupos_directos:
		directos[clave] = _nombres(cupos_directos[clave])
	var copas_datos := {}
	for clave in copas:
		var c: Dictionary = copas[clave]
		var knockout: Copa = c["knockout"]
		copas_datos[clave] = {
			"nombre": str(c["nombre"]),
			"fase": c["fase"].guardar(),
			"fecha": int(c["fecha"]),
			"directos": _nombres(c["directos"]),
			"playoff_pendientes": _pares_de_nombres(c["playoff_pendientes"]),
			"playoff_resultados": c["playoff_resultados"],
			"eliminados": c["eliminados"],
			"knockout": knockout.guardar() if knockout != null else {},
		}
	return {
		"previa_pendiente": _pares_de_nombres(previa_pendiente),
		"previa_resultados": previa_resultados,
		"cupos_directos": directos,
		"copas": copas_datos,
	}


static func cargar(datos: Dictionary, indice: Dictionary) -> TemporadaInternacional:
	var t := TemporadaInternacional.new()
	t.previa_resultados = datos.get("previa_resultados", [])
	t.previa_pendiente = _pares_de_equipos(datos.get("previa_pendiente", []), indice)
	for clave in datos.get("cupos_directos", {}):
		t.cupos_directos[str(clave)] = _equipos(datos["cupos_directos"][clave], indice)
	for clave in datos.get("copas", {}):
		var d: Dictionary = datos["copas"][clave]
		var knockout_datos: Dictionary = d.get("knockout", {})
		t.copas[str(clave)] = {
			"nombre": str(d.get("nombre", "")),
			"fase": FaseLiga.cargar(d.get("fase", {}), indice),
			"fecha": int(d.get("fecha", 0)),
			"directos": _equipos(d.get("directos", []), indice),
			"playoff_pendientes": _pares_de_equipos(d.get("playoff_pendientes", []), indice),
			"playoff_resultados": d.get("playoff_resultados", []),
			"eliminados": d.get("eliminados", []),
			"knockout": Copa.cargar_desde_indice(knockout_datos, indice) if not knockout_datos.is_empty() else null,
		}
	return t


static func _nombres(equipos: Array) -> Array:
	var salida := []
	for e in equipos:
		salida.append(e.nombre)
	return salida


static func _pares_de_nombres(pares: Array) -> Array:
	var salida := []
	for par in pares:
		salida.append([par[0].nombre, par[1].nombre])
	return salida


static func _equipos(nombres: Array, indice: Dictionary) -> Array:
	var salida := []
	for n in nombres:
		if indice.has(str(n)):
			salida.append(indice[str(n)])
	return salida


## Un cruce con un equipo que ya no existe se descarta entero, igual que
## en Copa.cargar: mejor perder el cruce que dejar un partido a medias
## que reventaría al jugarlo.
static func _pares_de_equipos(pares: Array, indice: Dictionary) -> Array:
	var salida := []
	for par in pares:
		if indice.has(str(par[0])) and indice.has(str(par[1])):
			salida.append([indice[str(par[0])], indice[str(par[1])]])
	return salida
