class_name Habilidades
extends RefCounted

## Habilidades por puesto. Un jugador puede tener hasta tres habilidades,
## incluso varias del mismo atributo, por ejemplo Ladrón plata y
## Recuperación oro.

const DATA_PATH := "res://data/habilidades.json"

const MAX_HABILIDADES := 3
const P_BRONCE := 0.15
const P_SEGUNDA_HABILIDAD := 0.35
const P_TERCERA_HABILIDAD := 0.20
const P_PLATA_SI_BRONCE := 0.10
const P_ORO_SI_PLATA := 0.05

const MEDIA_MINIMA := {1: 55.0, 2: 70.0, 3: 80.0}
const BONUS_DUELO := {1: 2.0, 2: 4.0, 3: 6.0}
const BONUS_ATAJAPENALES := {1: 0.05, 2: 0.09, 3: 0.13}
const FACTOR_RECUPERACION := {1: 0.75, 2: 0.55, 3: 0.35}

static var _datos_cache: Dictionary = {}
static var _atributo_por_nombre_cache: Dictionary = {}


static func _datos() -> Dictionary:
	if _datos_cache.is_empty():
		_datos_cache = DataLoader.load_json(DATA_PATH)
		# Alias de lectura para herramientas antiguas. La generación nueva usa
		# siempre el puesto exacto.
		if not _datos_cache.has("arquero"):
			_datos_cache["arquero"] = _datos_cache.get("ARQ", {})
		if not _datos_cache.has("campo"):
			var campo := {}
			for puesto in ["DFC", "LAT", "MC", "MCO", "EXT", "DC"]:
				for atributo in _datos_cache.get(puesto, {}):
					if not campo.has(atributo):
						campo[atributo] = []
					for nombre in _datos_cache[puesto][atributo]:
						if nombre not in campo[atributo]:
							campo[atributo].append(nombre)
			_datos_cache["campo"] = campo
		for puesto in _datos_cache:
			for atributo in _datos_cache[puesto]:
				for nombre in _datos_cache[puesto][atributo]:
					_atributo_por_nombre_cache[nombre] = atributo
	return _datos_cache


## Devuelve el pool de habilidades del puesto. Acepta el formato antiguo
## campo/arquero para que los guardados o herramientas viejas no se rompan.
static func _pool_puesto(posicion: String) -> Dictionary:
	var datos := _datos()
	if datos.has(posicion):
		return datos[posicion]
	if posicion == "ARQ":
		return datos.get("arquero", {})
	return datos.get("campo", {})


static func _candidatas(posicion: String) -> Array:
	var salida := []
	for atributo in _pool_puesto(posicion):
		for nombre in _pool_puesto(posicion)[atributo]:
			salida.append({"nombre": nombre, "atributo": atributo})
	return salida


static func nombres_para_posicion(posicion: String) -> Array:
	var salida := []
	for candidata in _candidatas(posicion):
		salida.append(candidata["nombre"])
	return salida


static func es_compatible(posicion: String, nombre: String) -> bool:
	return nombre in nombres_para_posicion(posicion)


## Lee la lista nueva y también jugadores de guardados antiguos.
static func lista_de(jugador: Dictionary) -> Array:
	var nueva = jugador.get("habilidades", null)
	if nueva is Array and not nueva.is_empty():
		return nueva
	var vieja = jugador.get("habilidad", {})
	if vieja is Dictionary and not vieja.is_empty():
		return [vieja]
	if nueva is Array:
		return nueva
	if nueva is Dictionary and not nueva.is_empty():
		return [nueva]
	return []


## Normaliza el formato persistido. Elimina habilidades que no pertenecen al
## puesto natural y evita nombres repetidos.
static func normalizar(jugador: Dictionary) -> void:
	var posicion := str(jugador.get("posicion", ""))
	var salida := []
	var vistos := {}
	for habilidad in lista_de(jugador):
		if not habilidad is Dictionary:
			continue
		var nombre := str(habilidad.get("nombre", ""))
		if nombre == "" or vistos.has(nombre) or not es_compatible(posicion, nombre):
			continue
		var nivel := clampi(int(habilidad.get("nivel", 1)), 1, 3)
		salida.append({"nombre": nombre, "nivel": nivel})
		vistos[nombre] = true
	jugador["habilidades"] = salida
	jugador.erase("habilidad")


static func media_maxima_por_techo(posicion: String, techos: Dictionary) -> float:
	if techos.is_empty():
		return 100.0
	return PlayerGenerator.compute_media(techos, posicion)


## Limpia habilidades incompatibles y baja cada nivel al máximo que el
## jugador puede manifestar.
static func corregir_habilidad_por_techo(jugador: Dictionary) -> void:
	normalizar(jugador)
	var max_media := media_maxima_por_techo(str(jugador.get("posicion", "")),
		jugador.get("potenciales", {}))
	var salida := []
	for habilidad in jugador["habilidades"]:
		var nivel_maximo := 0
		for nivel in [3, 2, 1]:
			if max_media >= MEDIA_MINIMA[nivel]:
				nivel_maximo = nivel
				break
		if nivel_maximo == 0:
			continue
		habilidad["nivel"] = mini(int(habilidad["nivel"]), nivel_maximo)
		salida.append(habilidad)
	jugador["habilidades"] = salida


## Genera cero a tres habilidades legales para el puesto. Cada habilidad
## elegida es distinta y su nivel se calcula de forma independiente.
static func generar(posicion: String, rng: RandomNumberGenerator,
		techos: Dictionary = {}) -> Array:
	var media_maxima := media_maxima_por_techo(posicion, techos)
	if media_maxima < MEDIA_MINIMA[1] or rng.randf() >= P_BRONCE:
		return []

	var cantidad := 1
	if cantidad < MAX_HABILIDADES and rng.randf() < P_SEGUNDA_HABILIDAD:
		cantidad += 1
	if cantidad < MAX_HABILIDADES and rng.randf() < P_TERCERA_HABILIDAD:
		cantidad += 1

	var disponibles := _candidatas(posicion)
	var salida := []
	for i in range(cantidad):
		if disponibles.is_empty():
			break
		var indice := rng.randi() % disponibles.size()
		var candidata: Dictionary = disponibles[indice]
		disponibles.remove_at(indice)
		var nivel := 1
		if rng.randf() < P_PLATA_SI_BRONCE and media_maxima >= MEDIA_MINIMA[2]:
			nivel = 2
			if rng.randf() < P_ORO_SI_PLATA and media_maxima >= MEDIA_MINIMA[3]:
				nivel = 3
		salida.append({"nombre": candidata["nombre"], "nivel": nivel})
	return salida


static func atributo_de(nombre: String) -> String:
	_datos()
	return _atributo_por_nombre_cache.get(nombre, "")


static func tiene_manifestada(jugador: Dictionary, nombre: String) -> bool:
	for habilidad in lista_de(jugador):
		if habilidad.get("nombre", "") == nombre and \
			jugador.get("media", 0.0) >= MEDIA_MINIMA.get(int(habilidad.get("nivel", 1)), 999.0):
			return true
	return false


## Suma las habilidades del mismo atributo. El duelo aplica sus topes de
## bloque, por lo que varias habilidades pueden acumularse sin romperlo.
static func modificador_partido(jugador: Dictionary, atributo: String) -> float:
	var total := 0.0
	for habilidad in lista_de(jugador):
		if atributo_de(str(habilidad.get("nombre", ""))) != atributo:
			continue
		var nivel := int(habilidad.get("nivel", 1))
		if jugador.get("media", 0.0) >= MEDIA_MINIMA.get(nivel, 999.0):
			total += BONUS_DUELO.get(nivel, 0.0)
	return total


static func factor_cooldown_recuperacion(jugador: Dictionary) -> float:
	var factor := 1.0
	for habilidad in lista_de(jugador):
		if habilidad.get("nombre", "") != "Recuperación":
			continue
		var nivel := int(habilidad.get("nivel", 1))
		if jugador.get("media", 0.0) >= MEDIA_MINIMA.get(nivel, 999.0):
			factor = minf(factor, FACTOR_RECUPERACION.get(nivel, 1.0))
	return factor


static func bonus_atajapenales(arquero: Dictionary) -> float:
	var bonus := 0.0
	for habilidad in lista_de(arquero):
		if habilidad.get("nombre", "") != "Atajapenales":
			continue
		var nivel := int(habilidad.get("nivel", 1))
		if arquero.get("media", 0.0) >= MEDIA_MINIMA.get(nivel, 999.0):
			bonus = maxf(bonus, BONUS_ATAJAPENALES.get(nivel, 0.0))
	return bonus
