class_name Formaciones
extends RefCounted

## Formaciones (§8.1). Cada una define los 11 puestos EN ORDEN y dónde se
## para cada uno; el slot `i` lo ocupa `Team.jugadores[i]`.
##
## Esa correspondencia por ÍNDICE es la decisión importante: el rol de un
## jugador en la cancha sale del SLOT, no de su `posicion` natural. Así se
## puede jugar a un volante de 9 sin inventar ninguna mecánica nueva — el
## motor le da el rol del slot y sus atributos hacen el resto (rematará
## con su `tiro`, que es el que tiene). Antes el motor repartía por
## `posicion` y, si un equipo tenía tres DFC, los que sobraban caían al
## mismo casillero y quedaban apilados.

const DATA_PATH := "res://data/formaciones.json"
const POR_DEFECTO := "4-2-3-1"

static var _cache: Dictionary = {}


static func _datos() -> Dictionary:
	if _cache.is_empty():
		_cache = DataLoader.load_json(DATA_PATH)
	return _cache


## Nombres disponibles, en orden estable para la UI.
static func lista() -> Array:
	var out := []
	for k in _datos():
		if not str(k).begins_with("_"):
			out.append(k)
	out.sort()
	return out


static func existe(nombre: String) -> bool:
	return _datos().has(nombre) and not nombre.begins_with("_")


## Los 11 slots: [{"rol": String, "base": Vector2}], en orden.
static func slots(nombre: String) -> Array:
	var clave := nombre if existe(nombre) else POR_DEFECTO
	var out := []
	for fila in _datos()[clave]:
		out.append({"rol": str(fila[0]), "base": Vector2(float(fila[1]), float(fila[2]))})
	return out


## Solo los roles, que es lo que necesita la UI para etiquetar cada slot.
static func roles(nombre: String) -> Array:
	var out := []
	for s in slots(nombre):
		out.append(s["rol"])
	return out


## Cuántos de cada puesto pide la formación, para mostrarlo como "4-4-2"
## no alcanza: el usuario quiere saber si le faltan defensores de verdad.
static func conteo(nombre: String) -> Dictionary:
	var out := {}
	for r in roles(nombre):
		out[r] = int(out.get(r, 0)) + 1
	return out
