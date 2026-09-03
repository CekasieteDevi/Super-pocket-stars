class_name Laboratorio
extends RefCounted

## LABORATORIO DE ANIMACIONES: monta una situación concreta y la devuelve
## como fotogramas, para poder mirarla en el acto en vez de esperar a que
## salga sola en un partido.
##
## Una expulsión aparece en 1 de cada 2 partidos, un penal en 1 de cada
## 5, y para ver cómo quedó la animación había que jugar hasta que la
## suerte la trajera. Acá se arma la situación a mano —se fuerza la roja,
## se pone la pelota en el punto del penal, se manda la pelota al córner—
## y se ticka el motor de verdad, sin trucos: lo que se ve es exactamente
## lo que va a pasar en un partido.
##
## Vive en core/ y no en tests/ a propósito: la idea es poder mirarlo
## también desde el teléfono, que es donde la animación se ve de verdad.

## Cuántos ticks se simulan después de montar la situación. 200 ticks son
## 50 segundos de juego, de sobra para el balón parado más largo (la
## salida de un expulsado puede llevar 11 segundos).
const TICKS := 200

## Las situaciones que se pueden pedir: clave, nombre y qué se ve.
const SITUACIONES := [
	{"clave": "expulsion", "nombre": "Expulsión",
		"que": "Roja, el juego se detiene y el expulsado camina hasta el lateral. Recién cuando sale se cobra la falta."},
	{"clave": "penal", "nombre": "Penal",
		"que": "Se cobra, se despeja el área, el pateador se acomoda detrás de la pelota y remata."},
	{"clave": "corner", "nombre": "Córner",
		"que": "El que lo patea corre hasta el banderín, el área se llena según el estilo, y el centro."},
	{"clave": "tiro_libre", "nombre": "Tiro libre con barrera",
		"que": "Se arma la barrera a 9,15 m y el ataque se acomoda antes del remate."},
	{"clave": "lateral", "nombre": "Lateral",
		"que": "La pelota sale por la banda y se reanuda con un saque de banda."},
	{"clave": "gol", "nombre": "Gol y festejo",
		"que": "Remate al arco desde el borde del área y el saque del medio posterior."},
	{"clave": "saque_arco", "nombre": "Saque de arco",
		"que": "La pelota se va por el fondo y el arquero la pone en juego."},
]


static func nombre_de(clave: String) -> String:
	for s in SITUACIONES:
		if str(s["clave"]) == clave:
			return str(s["nombre"])
	return clave


## Arma la situación y devuelve {fotogramas, eventos, log, goles_local,
## goles_visitante} — el mismo shape que MotorEspacial.simular, para que
## la vista de partido lo consuma sin enterarse de nada.
static func generar(clave: String, local: Team, visitante: Team,
		rng: RandomNumberGenerator) -> Dictionary:
	local.reset_partido()
	visitante.reset_partido()
	local.local = true
	visitante.local = false
	local.clima_partido = Clima.generar(rng)
	visitante.clima_partido = local.clima_partido
	local.arbitro_partido = Arbitro.generar(rng)
	visitante.arbitro_partido = local.arbitro_partido

	var estado := MotorEspacial.crear_estado(local, visitante, rng)
	estado["con_fotogramas"] = true
	MotorEspacial._reiniciar_desde_medio(estado, true, 1)
	# Unos ticks de juego normal antes de la situación: sin eso todos
	# arrancan clavados en el círculo central y no se entiende nada.
	for i in range(12):
		MotorEspacial._tick(estado, true)

	match clave:
		"expulsion":
			_montar_expulsion(estado)
		"penal":
			_montar_penal(estado)
		"corner":
			_montar_corner(estado)
		"tiro_libre":
			_montar_tiro_libre(estado)
		"lateral":
			_montar_lateral(estado)
		"gol":
			_montar_gol(estado)
		"saque_arco":
			_montar_saque_arco(estado)

	for i in range(TICKS):
		MotorEspacial._tick(estado, true)

	return {
		"goles_local": local.goles,
		"goles_visitante": visitante.goles,
		"log": estado["log"],
		"goles_log": estado["goles_log"],
		"eventos": estado["eventos"],
		"fotogramas": estado["fotogramas"],
	}


## Roja al defensor del equipo visitante más cercano a la pelota, y falta
## a favor del local en ese punto. Se fuerza la expulsión en vez de tirar
## la tarjeta: si no, habría que repetir hasta que salga.
static func _montar_expulsion(estado: Dictionary) -> void:
	var eq_d: Team = MotorEspacial._equipo_de(estado, false)
	var punto: Vector2 = estado["pelota"]["pos"]
	var clave := MotorEspacial._mas_cercano_del_equipo(estado, punto, false)
	if clave == -1:
		return
	var jugador_id: int = int(estado["jugadores"][clave]["jugador_id"])
	eq_d.expulsados_partido[jugador_id] = true
	estado["eventos"].append({
		"minuto": MotorEspacial._minuto_int(estado), "tipo": "tarjeta",
		"equipo": eq_d.nombre, "rival": "",
		"jugador_posicion": str(estado["jugadores"][clave]["rol"]),
		"jugador_id": jugador_id, "resultado": "roja",
	})
	estado["log"].append("LABORATORIO: roja para %s" % eq_d.nombre)
	MotorEspacial._mandar_a_las_duchas(estado, jugador_id, false)
	MotorEspacial._tiro_libre(estado, punto, true, MotorEspacial._minuto_int(estado))


static func _montar_penal(estado: Dictionary) -> void:
	MotorEspacial._cobrar_penal(estado, true, MotorEspacial._minuto_int(estado))


static func _montar_corner(estado: Dictionary) -> void:
	MotorEspacial._saque_de_esquina(estado, true, true)


## Una falta a 25 metros del arco rival, que es donde la barrera se arma
## y se ve.
static func _montar_tiro_libre(estado: Dictionary) -> void:
	var arco := MotorEspacial.arco_rival(true)
	var punto := Vector2(arco.x - 25.0, 8.0)
	MotorEspacial._tiro_libre(estado, punto, true, MotorEspacial._minuto_int(estado))


static func _montar_lateral(estado: Dictionary) -> void:
	MotorEspacial._lateral(estado, Vector2(10.0, MotorEspacial.MEDIO_ANCHO), true)


## Remate desde el borde del área. Se le pone la pelota al mejor rematador
## del local ahí y se lo deja decidir: si la mete, se ve el festejo y el
## saque del medio.
static func _montar_gol(estado: Dictionary) -> void:
	var eq_a: Team = MotorEspacial._equipo_de(estado, true)
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	var punto := Vector2(arco.x + hacia * 14.0, 2.0)
	var mejor := {}
	for j in eq_a.jugadores_en_cancha():
		if mejor.is_empty() or float(j["atributos"]["tiro"]) > float(mejor["atributos"]["tiro"]):
			mejor = j
	if mejor.is_empty():
		return
	var clave := MotorEspacial.clave_de(int(mejor["id"]), true)
	if not estado["jugadores"].has(clave):
		return
	estado["jugadores"][clave]["pos"] = punto
	MotorEspacial._entregar_pelota(estado, clave)
	estado["pelota"]["pos"] = punto
	MotorEspacial._resolver_tiro(estado, estado["jugadores"][clave], mejor)


static func _montar_saque_arco(estado: Dictionary) -> void:
	MotorEspacial._dar_pelota_al_arquero(estado, false, true)
