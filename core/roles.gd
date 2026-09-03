class_name Roles
extends RefCounted

## Quién patea qué, y quién lleva la cinta.
##
## Antes no lo elegía nadie. El motor buscaba al mejor del atributo que
## correspondía y listo. Eso daba resultados absurdos: el penal lo pateaba
## el jugador con más `tiro` DE LOS ONCE EN CANCHA, arquero incluido, así
## que el golero se iba caminando hasta el punto del penal.
##
## Ahora el club elige, y lo puede cambiar cuando quiera. Si no elige, o
## si el elegido no está en cancha, se usa el automático de siempre — pero
## el automático ya no mira al arquero.

const PENALES := "penales"
const CORNERS := "corners"
const LIBRES_CERCA := "libres_cerca"
const LIBRES_LEJOS := "libres_lejos"
const CAPITAN := "capitan"

## En el orden en que se muestran.
const CLAVES := [PENALES, CORNERS, LIBRES_CERCA, LIBRES_LEJOS, CAPITAN]

const NOMBRE := {
	PENALES: "Penales",
	CORNERS: "Córners",
	LIBRES_CERCA: "Tiros libres cercanos",
	LIBRES_LEJOS: "Tiros libres lejanos",
	CAPITAN: "Capitán",
}

const DESCRIPCION := {
	PENALES: "Patea todos los penales del partido.",
	CORNERS: "Ejecuta los córners a los dos lados.",
	LIBRES_CERCA: "Remata las faltas con ángulo de arco.",
	LIBRES_LEJOS: "Cuelga al área las faltas lejanas y escoradas.",
	CAPITAN: "Suma en el vestuario y en cada duelo que juega.",
}

## El atributo con el que se ordena la lista y con el que se elige el
## automático. El capitán va por media: la cinta es del que más pesa.
const ATRIBUTO := {
	PENALES: "tiro",
	CORNERS: "centros",
	LIBRES_CERCA: "tiros_libres",
	LIBRES_LEJOS: "centros",
	CAPITAN: "",
}

## Nadie manda al arquero a patear un corner. La única excepción es la
## cinta: un arquero capitán es de lo más normal.
const ADMITE_ARQUERO := {
	PENALES: false,
	CORNERS: false,
	LIBRES_CERCA: false,
	LIBRES_LEJOS: false,
	CAPITAN: true,
}

## Sin elección del club.
const AUTOMATICO := -1


static func existe(clave: String) -> bool:
	return CLAVES.has(clave)


## Con qué se puntea a un jugador para este rol.
static func valor_de(jugador: Dictionary, clave: String) -> float:
	var atributo := str(ATRIBUTO.get(clave, ""))
	if atributo == "":
		return float(jugador.get("media", 0.0))
	return float(jugador["atributos"].get(atributo, 0.0))


## A quién eligió el club, o AUTOMATICO si no eligió a nadie.
static func elegido(equipo: Team, clave: String) -> int:
	return int(equipo.roles.get(clave, AUTOMATICO))


## El club elige. `jugador_id` = AUTOMATICO vuelve al automático.
static func asignar(equipo: Team, clave: String, jugador_id: int) -> void:
	if not existe(clave):
		return
	equipo.roles[clave] = jugador_id
	if clave == CAPITAN:
		equipo.recalcular_capitan()


## Los que se pueden elegir para este rol: el plantel de partido, sin la
## cantera. Se listan aunque estén lesionados —el club decide para
## adelante, no solo para la fecha que viene— y el motor se encarga de
## usar al automático si el elegido no está en la cancha.
static func candidatos(equipo: Team, clave: String) -> Array:
	var lista := []
	for j in equipo.todos_los_jugadores():
		if str(j["posicion"]) == "ARQ" and not bool(ADMITE_ARQUERO.get(clave, false)):
			continue
		lista.append(j)
	lista.sort_custom(func(a, b): return valor_de(a, clave) > valor_de(b, clave))
	return lista


## El mejor del plantel para este rol, sin mirar quién está en cancha.
## Es lo que se muestra cuando el rol está en automático.
static func automatico(equipo: Team, clave: String) -> int:
	var mejor := -1
	var mejor_valor := -1.0
	for j in candidatos(equipo, clave):
		var v := valor_de(j, clave)
		if v > mejor_valor:
			mejor_valor = v
			mejor = int(j["id"])
	return mejor


## Quién ocupa el rol AHORA, mirando el plantel entero. Es lo que muestra
## la pantalla de Roles.
##
## El elegido pierde el puesto si ya no está en el club o si no puede
## jugar (lesión o suspensión): de nada sirve tener un pateador de penales
## que está tres meses afuera.
static func resolver(equipo: Team, clave: String) -> int:
	var id := elegido(equipo, clave)
	if id != AUTOMATICO and _sirve(equipo, clave, id):
		return id
	return automatico(equipo, clave)


## Quién lo ejecuta EN ESTE PARTIDO. Igual que resolver, pero además el
## elegido tiene que estar en la cancha en este momento: si lo cambiaron o
## lo expulsaron, la patea otro.
##
## `ids_en_cancha` son los jugador_id que están jugando. Si viene vacío no
## se filtra por cancha (sirve para las pruebas y para el motor abstracto,
## que no lleva posiciones).
static func ejecutor(equipo: Team, clave: String, ids_en_cancha: Array) -> int:
	var id := elegido(equipo, clave)
	if id != AUTOMATICO and _sirve(equipo, clave, id) 			and (ids_en_cancha.is_empty() or ids_en_cancha.has(id)):
		return id
	if ids_en_cancha.is_empty():
		return automatico(equipo, clave)
	# El mejor de los que efectivamente están jugando.
	var mejor := -1
	var mejor_valor := -1.0
	for j in candidatos(equipo, clave):
		if not ids_en_cancha.has(int(j["id"])):
			continue
		var v := valor_de(j, clave)
		if v > mejor_valor:
			mejor_valor = v
			mejor = int(j["id"])
	return mejor


## El elegido POR EL CLUB, y solo si esta jugando. -1 si el club no
## eligio a nadie.
##
## Es distinto de ejecutor(): ese siempre devuelve a alguien, porque
## alguien tiene que patear. Este responde otra pregunta, "hay una
## decision del club que respetar", y la respuesta cambia lo que hace el
## motor: al designado se lo espera aunque este lejos, y al automatico
## no. Sin esta distincion, los doscientos clubes de la IA —que nunca
## eligen nada— quedaban esperando a un pateador que nadie eligio.
static func explicito(equipo: Team, clave: String, ids_en_cancha: Array) -> int:
	var id := elegido(equipo, clave)
	if id == AUTOMATICO or not _sirve(equipo, clave, id):
		return -1
	if not ids_en_cancha.is_empty() and not ids_en_cancha.has(id):
		return -1
	return id


## Limpia las elecciones que dejaron de tener sentido: el jugador se fue,
## se retiró o lo vendieron. Se llama en los mismos lugares donde ya se
## recalculaba el capitán.
static func limpiar(equipo: Team) -> void:
	for clave in CLAVES:
		var id := elegido(equipo, clave)
		if id == AUTOMATICO:
			continue
		if not _esta_en_el_plantel(equipo, clave, id):
			equipo.roles[clave] = AUTOMATICO


static func _sirve(equipo: Team, clave: String, jugador_id: int) -> bool:
	return _esta_en_el_plantel(equipo, clave, jugador_id) and equipo.puede_jugar(jugador_id)


static func _esta_en_el_plantel(equipo: Team, clave: String, jugador_id: int) -> bool:
	for j in equipo.todos_los_jugadores():
		if int(j["id"]) != jugador_id:
			continue
		if str(j["posicion"]) == "ARQ" and not bool(ADMITE_ARQUERO.get(clave, false)):
			return false
		return true
	return false
