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

## Qué formación usa cada estilo de juego (§8.6.3). Mismo patrón que
## FocoEquipo.POR_ESTILO: el estilo es la identidad del club y de ahí
## cuelga todo lo demás.
##
## Hasta ahora los 200 clubes jugaban 4-2-3-1 y las otras cuatro
## formaciones existían solo para el jugador humano. Eso hacía que la
## tabla de matchups de estilos fuera lo único que distinguía a un rival
## de otro, y que la cancha de Formación mostrara siempre la misma foto
## enfrente.
##
## Son seis estilos y cinco formaciones, así que una se repite: Físico y
## Contragolpe juegan los dos 4-4-2 —dos puntas y dos líneas de cuatro—
## que es lo que los dos quieren de la vida.
const POR_ESTILO := {
	"Tiki taka": "4-3-3",
	"Contragolpe": "4-4-2",
	"Juego directo": "3-5-2",
	"Presión alta": "4-2-3-1",
	"Defensivo": "5-3-2",
	"Físico": "4-4-2",
}


static func para_estilo(estilo: String) -> String:
	return str(POR_ESTILO.get(estilo, POR_DEFECTO))

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


## Los 7 puestos del banco para una formación: uno por puesto que la
## formación usa, y si sobran lugares se repiten los puestos donde más
## gente hay en la cancha.
##
## Sin esto, un club de 3-5-2 tenía en el banco un EXT y un MCO —puestos
## que su formación no usa— y le faltaba cubrir el tercer central: perder
## un defensor lo obligaba a poner a alguien fuera de posición, que en el
## §8.4 cuesta de −4 a −12.
## Cuantos jugadores tiene el banco.
const TAMANO_BANCO := 7

## Cuantos jugadores tiene que haber de CADA puesto en el plantel, entre
## titulares y banco: uno para jugar y uno de recambio.
const MINIMO_POR_PUESTO := 2


## Los puestos del banco.
##
## Lo primero es la COBERTURA: que ningun puesto de los siete se quede sin
## dos jugadores. Antes el banco salia de los puestos de la formacion con
## la que arrancaba el club y de ninguno mas, asi que un club que arrancaba
## en 5-3-2 —ARQ, DFC, LAT, MC, DC— no tenia un solo EXT ni un solo MCO en
## todo el plantel. Si despues querias pasarte a 4-3-3 no habia con quien:
## los dos puestos de extremo quedaban vacios y no se podia ni poner a
## alguien fuera de posicion, porque no habia a quien poner. Terminabas
## atado a la formacion que te toco al empezar.
##
## Lo que sobra despues de cubrir va a los puestos que MAS usa la
## formacion, para que el banco siga pareciendose a lo que el club juega.
static func banco_para(nombre: String) -> Array:
	var roles := roles(nombre)
	var titulares := {}
	for p in Puestos.TODOS:
		titulares[p] = 0
	for r in roles:
		titulares[r] = int(titulares.get(r, 0)) + 1

	var banco := []
	var total := titulares.duplicate()
	for p in Puestos.TODOS:
		while int(total[p]) < MINIMO_POR_PUESTO and banco.size() < TAMANO_BANCO:
			banco.append(p)
			total[p] = int(total[p]) + 1

	# El relleno: de campo (el arquero suplente ya esta cubierto arriba) y
	# de los que mas usa la formacion primero.
	var relleno := []
	for p in Puestos.TODOS:
		if p != "ARQ" and int(titulares[p]) > 0:
			relleno.append(p)
	relleno.sort_custom(func(a, b): return int(titulares[a]) > int(titulares[b]))
	var i := 0
	while banco.size() < TAMANO_BANCO and not relleno.is_empty():
		banco.append(relleno[i % relleno.size()])
		i += 1
	return banco.slice(0, TAMANO_BANCO)


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
