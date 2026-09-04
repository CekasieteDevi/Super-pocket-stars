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

## El clip TERMINA cuando termina la jugada, no a los N ticks.
##
## La primera version corria 200 ticks fijos —53 segundos— para una jugada
## que dura entre 1 y 5. El resto era futbol comun y corriente que no
## tenia nada que ver con lo que se venia a mirar.
##
## Ahora son dos etapas: se espera a que la jugada montada se resuelva
## —que se termine la pausa del balon parado y que el expulsado salga— y
## despues un rato fijo para ver como sigue.
const TICKS_DE_CIERRE := 20
const TICKS_TOPE := 200

## Cuantos ticks de juego normal antes de montar la jugada. Pocos: son
## para que los 22 no esten clavados en el circulo central, no para ver un
## partido.
const TICKS_PREVIOS := 6

## Semilla FIJA. Una jugada del laboratorio tiene que dar siempre lo
## mismo: se viene a mirar como quedo la animacion, y si el resultado
## cambia entre una reproduccion y la siguiente no se puede comparar nada
## —ni saber si un cambio la mejoro—. Con esto, "Gol y festejo" es
## siempre el mismo gol.
const SEMILLA := 20260903

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
	{"clave": "cambio", "nombre": "Cambio",
		"que": "Se detiene el juego, el que sale camina hasta el lateral y el suplente entra por ahí mismo a ocupar su lugar."},
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
	for i in range(TICKS_PREVIOS):
		MotorEspacial._tick(estado, true)

	# Los eventos que emita el montaje tienen que quedar PEGADOS a un
	# fotograma: la vista lee los eventos de cada cuadro para mostrar la
	# tarjeta y el relato, y los que se emiten fuera de un tick no los ve
	# nadie. Por eso se anota cuantos habia antes y se empuja un fotograma
	# con los nuevos.
	var eventos_antes: int = estado["eventos"].size()

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
		"cambio":
			_montar_cambio(estado)

	MotorEspacial._push_fotograma(estado, estado["eventos"].slice(eventos_antes))

	# Etapa 1: hasta que se resuelva lo que se monto.
	for i in range(TICKS_TOPE):
		if not _jugada_en_curso(estado):
			break
		MotorEspacial._tick(estado, true)
	# Etapa 2: un rato fijo para ver como sigue. Fijo y no "hasta que se
	# calme": despues de la jugada el partido sigue para siempre, y
	# esperar a que no pase nada terminaba dando el clip entero de 200
	# ticks otra vez.
	for i in range(TICKS_DE_CIERRE):
		MotorEspacial._tick(estado, true)

	return {
		"goles_local": local.goles,
		"goles_visitante": visitante.goles,
		"log": estado["log"],
		"goles_log": estado["goles_log"],
		"eventos": estado["eventos"],
		"fotogramas": estado["fotogramas"],
	}


## ¿Todavia esta pasando la jugada que se monto? Solo mira lo que la
## jugada misma controla: la pausa del balon parado y el expulsado que
## camina. NO mira si la pelota esta en el aire — despues del saque el
## partido sigue y siempre hay alguna pelota volando, asi que con eso el
## clip no terminaba nunca.
static func _jugada_en_curso(estado: Dictionary) -> bool:
	if int(estado.get("detenido", 0)) > 0:
		return true
	return not estado.get("expulsado", {}).is_empty()


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


## En un partido el penal llega por _cobrar_falta, que emite la falta
## ANTES de mandar a _cobrar_penal. Llamando directo a _cobrar_penal esa
## falta no existe y la vista no narra nada hasta el remate, asi que se
## emite igual.
static func _montar_penal(estado: Dictionary) -> void:
	var eq_a: Team = MotorEspacial._equipo_de(estado, true)
	var eq_d: Team = MotorEspacial._equipo_de(estado, false)
	estado["eventos"].append({
		"minuto": MotorEspacial._minuto_int(estado), "tipo": "falta",
		"equipo": eq_d.nombre, "rival": eq_a.nombre,
		"jugador_posicion": "DFC", "resultado": "falta",
	})
	MotorEspacial._cobrar_penal(estado, true, MotorEspacial._minuto_int(estado))


## Corner con el area POBLADA.
##
## _saque_de_esquina reparte las marcas, pero los jugadores tienen que
## trotar hasta ellas y en una jugada montada a mano arrancan en el
## circulo central, a sesenta metros: cuando el ejecutor la pateaba no
## habia llegado nadie y la tiraba corta o para atras, porque no tenia a
## quien buscar. Se los pone ya cerca del area y de ahi terminan de
## acomodarse solos.
static func _montar_corner(estado: Dictionary) -> void:
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	# Adentro del area grande, repartidos a lo ancho.
	var i := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if str(e["rol"]) == "ARQ":
			continue
		var dentro: float = arco.x + hacia * (6.0 + 8.0 * float(i % 3))
		var ancho: float = -14.0 + 5.0 * float(i % 6)
		if e["equipo_local"]:
			e["pos"] = Vector2(dentro, ancho)
		else:
			# Los que defienden, un poco mas cerca de su arco.
			e["pos"] = Vector2(dentro + hacia * 2.5, ancho + 2.0)
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		i += 1
	MotorEspacial._saque_de_esquina(estado, true, true)


## Una falta a 25 metros del arco rival, que es donde la barrera se arma
## y se ve.
static func _montar_tiro_libre(estado: Dictionary) -> void:
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	# 20 metros y bastante centrado: la barrera solo se arma en un tiro
	# libre DIRECTO, y eso lo decide MotorEspacial.tipo_de_falta — el
	# angulo contra angulo_minimo_tiro_libre y la distancia contra el
	# alcance que le da `tiros_libres` al pateador. A 24 m y 7 de costado
	# quedaba afuera y por poco no habia barrera.
	var punto := Vector2(arco.x + hacia * 20.0, 5.0)
	var eq_a: Team = MotorEspacial._equipo_de(estado, true)
	var eq_d: Team = MotorEspacial._equipo_de(estado, false)

	# Se monta la SITUACION entera, no solo la pelota. La barrera la
	# forman los defensores que estan a menos de DIST_MAX_A_LA_BARRERA del
	# punto, y en una jugada armada a mano el equipo defensor esta en el
	# medio de la cancha: sin acercarlos no hay barrera que valga, que es
	# justo lo que se venia a mirar. Tampoco es hacer trampa — es la foto
	# que habria si la falta hubiera pasado de verdad ahi.
	# Se los pone entre la pelota y SU arco, cerca del puesto de la
	# barrera pero no encima: asi se los ve trotar a formarla en vez de
	# aparecer ya alineados. El puesto esta a 9,15 m del punto en la
	# linea al arco, y solo entran a la barrera los que estan a menos de
	# DIST_MAX_A_LA_BARRERA de ahi.
	var hacia_arco: Vector2 = (arco - punto).normalized()
	var lateral := Vector2(-hacia_arco.y, hacia_arco.x)
	var puesto_barrera: Vector2 = punto + hacia_arco * 9.15
	var atras: Array = []
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] or str(e["rol"]) == "ARQ":
			continue
		atras.append(e)
	for i in range(mini(atras.size(), 7)):
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		if i < 5:
			# Los que van a formar la barrera: alrededor del puesto.
			atras[i]["pos"] = puesto_barrera + hacia_arco * 3.5 				+ lateral * lado * (1.5 + 1.2 * i)
		else:
			# Y un par mas atras, marcando.
			atras[i]["pos"] = punto + hacia_arco * (16.0 + 3.0 * i) 				+ lateral * lado * 8.0
		atras[i]["vel"] = Vector2.ZERO
		atras[i]["rapidez"] = 0.0

	# La pelota YA en el punto: si no, se queda donde estaba —el circulo
	# central— durante toda la pausa y despues aparece de un salto.
	estado["pelota"]["pos"] = punto
	estado["pelota"]["poseedor_id"] = -1
	estado["pelota"]["en_vuelo"] = false
	estado["pelota"]["vel"] = Vector2.ZERO

	estado["eventos"].append({
		"minuto": MotorEspacial._minuto_int(estado), "tipo": "falta",
		"equipo": eq_d.nombre, "rival": eq_a.nombre,
		"jugador_posicion": "DFC", "resultado": "falta",
	})
	MotorEspacial._tiro_libre(estado, punto, true, MotorEspacial._minuto_int(estado))


static func _montar_lateral(estado: Dictionary) -> void:
	MotorEspacial._lateral(estado, Vector2(10.0, MotorEspacial.MEDIO_ANCHO), true)


## Gol garantizado desde el borde del área.
##
## Antes se llamaba a _resolver_tiro, que tira el duelo contra el arquero:
## el remate se podia ir afuera o lo podian atajar, y el clip que se pidio
## —"gol y festejo"— no mostraba ni el gol ni el festejo. El primer
## intento de arreglarlo fue reintentar hasta que entrara, y eso era peor:
## cada intento fallido dejaba sus propios eventos, asi que el relato
## cantaba cosas de mas.
##
## Ahora se saltea el duelo y se llama derecho a _lanzar_remate con
## tipo "gol". La pelota viaja igual, el arquero se tira igual y el
## festejo es el de siempre: lo unico que no pasa es la tirada.
static func _montar_gol(estado: Dictionary) -> void:
	var eq_a: Team = MotorEspacial._equipo_de(estado, true)
	var eq_d: Team = MotorEspacial._equipo_de(estado, false)
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
	var poseedor: Dictionary = estado["jugadores"][clave]
	poseedor["pos"] = punto
	MotorEspacial._entregar_pelota(estado, clave)
	estado["pelota"]["pos"] = punto

	var arquero := eq_d.arquero()
	MotorEspacial._lanzar_remate(estado, poseedor, {
		"tipo": "gol",
		"es_local": true, "clave": clave, "rol": poseedor["rol"],
		"jugador": mejor,
		"agarre": float(arquero.get("atributos", {}).get("agarre", 50)) / 100.0,
		"dist": punto.distance_to(arco),
	})


static func _montar_saque_arco(estado: Dictionary) -> void:
	MotorEspacial._dar_pelota_al_arquero(estado, false, true)


## Un cambio de cada equipo a la vez: sale un titular y entra un suplente,
## los dos por el lateral. Se hacen los dos juntos a proposito — es lo que
## pasa en un partido cuando los dos tecnicos mueven en la misma pausa, y
## asi se ve que la mecanica sirve para los dos equipos.
static func _montar_cambio(estado: Dictionary) -> void:
	for es_local in [true, false]:
		var equipo: Team = MotorEspacial._equipo_de(estado, es_local)
		if equipo.banco.is_empty():
			continue
		# Sale un jugador de campo (el arquero no) y entra el primero del
		# banco que pueda jugar.
		var sale := {}
		for j in equipo.jugadores_en_cancha():
			if str(j["posicion"]) != "ARQ":
				sale = j
				break
		var entra := {}
		for j in equipo.banco:
			if equipo.puede_jugar(int(j["id"])):
				entra = j
				break
		if sale.is_empty() or entra.is_empty():
			continue
		equipo.sustituir(int(sale["id"]), int(entra["id"]))
		estado["eventos"].append({
			"minuto": MotorEspacial._minuto_int(estado), "tipo": "cambio",
			"equipo": equipo.nombre, "rival": "",
			"jugador_posicion": str(sale["posicion"]), "resultado": "entra",
		})
	MotorEspacial._sincronizar_cambios(estado)
