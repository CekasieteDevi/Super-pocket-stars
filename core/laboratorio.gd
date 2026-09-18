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
	{"clave": "cabezazo", "nombre": "Centro y gol de cabeza",
		"que": "El centro sale desde la banda, cruza el área por arriba, el delantero le gana de arriba al defensor y la cabecea al gol."},
	{"clave": "volea", "nombre": "Centro y gol de volea",
		"que": "Centro desde la banda, control del vuelo y volea de primera. Se ve el golpe completo y el balon termina en gol."},
	{"clave": "palomita", "nombre": "Centro y gol de palomita",
		"que": "Centro bajo al area, vuelo horizontal, cabezazo de palomita y gol. El clip termina al acabar el festejo."},
	{"clave": "gol", "nombre": "Gol y festejo",
		"que": "Remate al arco desde el borde del área y el saque del medio posterior."},
	{"clave": "tiro_efecto", "nombre": "Tiro con efecto",
		"que": "El atacante entra en diagonal y curva la pelota al segundo palo. Efecto y tiro mandan la forma y la calidad."},
	{"clave": "festejo_banderin", "nombre": "Festejo en el banderín",
		"que": "Gol desde el costado del área. El goleador y los tres compañeros más cercanos corren al banderín a festejar juntos."},
	{"clave": "saque_arco", "nombre": "Saque de arco",
		"que": "La pelota se va por el fondo y el arquero la pone en juego."},
	{"clave": "cadena_rebotes", "nombre": "Cadena de rebotes aéreos",
		"que": "Remate, rebote aéreo, duelo de cabeza ganado por otro delantero, segundo rebote aéreo y gol de volea."},
	{"clave": "cambio", "nombre": "Cambio",
		"que": "Se detiene el juego, el que sale camina hasta el lateral y el suplente entra por ahí mismo a ocupar su lugar."},
	{"clave": "regate_croqueta", "nombre": "Regate: Croqueta",
		"que": "Cambia la pelota de un pie al otro, protege con el cuerpo y sale por el costado."},
	{"clave": "regate_bicicleta", "nombre": "Regate: Bicicleta",
		"que": "Amagues alternados alrededor de la pelota y salida con el exterior."},
	{"clave": "regate_globito", "nombre": "Regate: Globito",
		"que": "Levanta la pelota sobre el rival, gira y acelera para recuperarla."},
	{"clave": "regate_elastica", "nombre": "Regate: Elastica",
		"que": "Empuja hacia afuera y vuelve de inmediato con el interior del mismo pie."},
	{"clave": "regate_ruleta", "nombre": "Regate: Ruleta",
		"que": "Pisa, arrastra y gira 360 grados cambiando la pelota de pie."},
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
	# El saque del medio deja el juego DETENIDO 12 ticks y con el saque
	# PENDIENTE, y los ticks previos son 6: la jugada se montaba encima de
	# una pausa, nadie se movia, y seis ticks despues el motor ejecutaba el
	# saque inicial en el medio del clip —"¡Arranca el partido!" mientras
	# volaba el centro—. Se descarta la pausa: al que le toco sacar la
	# tiene y se juega.
	estado.erase("balon_parado")
	estado["detenido"] = 0
	estado["quietos"] = 0
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

	if clave.begins_with("regate_"):
		_montar_regate(estado, clave.trim_prefix("regate_"))
		return {
			"goles_local": local.goles,
			"goles_visitante": visitante.goles,
			"log": estado["log"],
			"goles_log": estado["goles_log"],
			"eventos": estado["eventos"],
			"fotogramas": estado["fotogramas"],
		}

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
		"cabezazo":
			_montar_cabezazo(estado)
		"volea":
			_montar_volea(estado)
		"palomita":
			_montar_palomita(estado)
		"gol":
			_montar_gol(estado)
		"tiro_efecto":
			_montar_tiro_efecto(estado)
		"festejo_banderin":
			_montar_festejo_banderin(estado)
		"saque_arco":
			_montar_saque_arco(estado)
		"cadena_rebotes":
			_montar_cadena_rebotes(estado)
		"cambio":
			_montar_cambio(estado)

	# El clip EMPIEZA en la jugada ya montada. Montarla es TELETRANSPORTAR
	# a los 22 —el que cabecea al area chica, el que centra a la banda, el
	# resto fuera del corredor del centro—, y con los fotogramas previos
	# adentro eso se veia: los jugadores desaparecian de un lado y
	# aparecian en otro, como si los sustituyeran a todos de golpe. Los
	# ticks previos siguen corriendo —sirven para despegar a los 22 del
	# circulo central— pero no se muestran.
	estado["fotogramas"].clear()
	MotorEspacial._push_fotograma(estado, estado["eventos"].slice(eventos_antes))

	# La palomita es un clip cerrado: centro, remate, gol y pausa completa.
	# No se reproduce el saque del medio ni una jugada aleatoria posterior.
	if clave == "palomita":
		var gol_visto := false
		var ticks_post_gol := 0
		for i in range(TICKS_TOPE):
			if gol_visto and ticks_post_gol >= int(MotorEspacial.TICKS_DETENIDO["gol"]):
				break
			MotorEspacial._tick(estado, true)
			if gol_visto:
				ticks_post_gol += 1
			else:
				for ev in estado["eventos"]:
					if str(ev.get("resultado", "")) == "gol":
						gol_visto = true
						break
	else:
		# Etapa 1: hasta que se resuelva lo que se monto.
		for i in range(TICKS_TOPE):
			if not _jugada_en_curso(estado):
				break
			MotorEspacial._tick(estado, true)
	# Etapa 2: un rato fijo para ver como sigue. Fijo y no "hasta que se
	# calme": despues de la jugada el partido sigue para siempre, y
	# esperar a que no pase nada terminaba dando el clip entero de 200
	# ticks otra vez.
	if clave != "palomita":
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
	if estado.has("cadena_rebotes"):
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
## El festejo en el banderín es de la vista (VistaPartido.armar_festejo):
## acá solo se monta un gol que lo haga legible. Desde el costado del área
## el goleador queda cerca de un banderín y la corrida entra en cámara.
static func _montar_festejo_banderin(estado: Dictionary) -> void:
	_montar_gol(estado, Vector2(13.0, -14.0))


static func _montar_gol(estado: Dictionary, desplazamiento := Vector2(14.0, 2.0)) -> void:
	var eq_a: Team = MotorEspacial._equipo_de(estado, true)
	var eq_d: Team = MotorEspacial._equipo_de(estado, false)
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	var punto := Vector2(arco.x + hacia * desplazamiento.x, desplazamiento.y)
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


## Gol garantizado desde un costado del area. La diagonal es deliberada:
## es la situacion donde el efecto aparece de forma natural y permite leer
## la curva hasta el segundo palo.
static func _montar_tiro_efecto(estado: Dictionary) -> void:
	var eq_a: Team = MotorEspacial._equipo_de(estado, true)
	var eq_d: Team = MotorEspacial._equipo_de(estado, false)
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	var mejor := {}
	for j in eq_a.jugadores_en_cancha():
		var attrs: Dictionary = j.get("atributos", {})
		var val := float(attrs.get("tiro", 0)) * 0.55 + float(attrs.get("efecto", 0)) * 0.45
		if mejor.is_empty() or val > float(mejor.get("val", -1.0)):
			mejor = {"j": j, "val": val}
	if mejor.is_empty():
		return
	var jugador: Dictionary = mejor["j"]
	var clave := MotorEspacial.clave_de(int(jugador["id"]), true)
	if not estado["jugadores"].has(clave):
		return
	var punto := Vector2(arco.x + hacia * 18.0, -16.0)
	var poseedor: Dictionary = estado["jugadores"][clave]
	poseedor["pos"] = punto
	poseedor["vel"] = Vector2.ZERO
	poseedor["rapidez"] = 0.0
	MotorEspacial._entregar_pelota(estado, clave)
	estado["pelota"]["pos"] = punto
	estado["forzar_remate"] = "gol"
	estado["forzar_remate_attr"] = "tiro"
	var arquero := eq_d.arquero()
	MotorEspacial._lanzar_remate(estado, poseedor, {
		"tipo": "gol", "es_local": true, "clave": clave,
		"rol": poseedor["rol"], "jugador": jugador,
		"agarre": float(arquero.get("atributos", {}).get("agarre", 50)) / 100.0,
		"dist": punto.distance_to(arco), "forzar_curva": true,
	})


## Un centro desde la banda que termina en gol de cabeza.
##
## El centro es de verdad: vuela por arriba, no se puede cortar en el
## camino y al caer el motor resuelve el duelo aéreo. Lo único armado es
## el escenario — quién centra, quién ataca el centro y dónde está parado
## cada uno — más el desenlace del remate, que se fuerza a gol.
##
## Se fuerza porque la jugada se viene a MIRAR: el duelo contra el arquero
## la termina en atajada la mitad de las veces, y un clip llamado "gol de
## cabeza" que unas veces no es gol no sirve para comparar cómo quedó la
## animación.
static func _montar_cabezazo(estado: Dictionary) -> void:
	var eq_a: Team = MotorEspacial._equipo_de(estado, true)
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0

	# Quién cabecea: el mejor de arriba del equipo que ataca. Es el mismo
	# criterio con el que el motor elige a quién buscar en un córner.
	#
	# Se saltea a los que el motor haría rematar de volea o de chilena en
	# vez de cabecear (MotorEspacial.remata_de_acrobacia). Sin eso el clip
	# elegía al mejor de arriba y, si ese además pateaba muy bien, el gol
	# salía de chilena: 1 de cada 8 planteles mostraba un clip "de cabeza"
	# sin un solo cabezazo. El reparto es el mismo; solo cambia a quién se
	# le monta la jugada.
	var cabeceador := {}
	var respaldo := {}
	for j in eq_a.jugadores_en_cancha():
		var val: float = float(j["atributos"]["cabezazo"]) * 0.6 + float(j["atributos"]["salto"]) * 0.4
		if respaldo.is_empty() or val > float(respaldo["val"]):
			respaldo = {"j": j, "val": val}
		if MotorEspacial.remata_de_acrobacia(j):
			continue
		if cabeceador.is_empty() or val > float(cabeceador["val"]):
			cabeceador = {"j": j, "val": val}
	# Si los once rematan mejor de pie, el clip se monta igual con el mejor
	# de arriba: es preferible un clip con una chilena a un clip vacío.
	if cabeceador.is_empty():
		cabeceador = respaldo
	if cabeceador.is_empty():
		return
	# Quién centra: el que mejor centra, de los que quedan.
	var centrador := {}
	for j in eq_a.jugadores_en_cancha():
		if j["id"] == cabeceador["j"]["id"]:
			continue
		if centrador.is_empty() or float(j["atributos"]["centros"]) > float(centrador["atributos"]["centros"]):
			centrador = j
	if centrador.is_empty():
		return

	var clave_cab: int = MotorEspacial.clave_de(int(cabeceador["j"]["id"]), true)
	var clave_cen: int = MotorEspacial.clave_de(int(centrador["id"]), true)
	if not estado["jugadores"].has(clave_cab) or not estado["jugadores"].has(clave_cen):
		return

	# El punto de caída: dentro del área chica y sobre un palo. Ahí el
	# cabezazo termina en remate — fuera del área el motor deja que siga
	# jugando y no cabecea nadie (ver _resolver_centro).
	var caida := Vector2(arco.x + hacia * 5.5, -1.0)
	var e_cab: Dictionary = estado["jugadores"][clave_cab]
	e_cab["pos"] = caida
	e_cab["vel"] = Vector2.ZERO
	e_cab["rapidez"] = 0.0

	# El que centra, abierto y a la altura del borde del área.
	#
	# El centro es CORTO a propósito, unos 19 metros. Un centro largo tarda
	# 12 ticks en llegar, y en el último la parábola ya bajó de
	# `z_inalcanzable` (2,5 m): ahí lo corta el primer defensor que llegó
	# corriendo, porque los 22 se mueven mientras la pelota vuela. Con 19
	# metros son 5 ticks y la pelota nunca pasa por abajo antes de caer.
	var e_cen: Dictionary = estado["jugadores"][clave_cen]
	e_cen["pos"] = Vector2(arco.x + hacia * 14.0, 16.0)
	e_cen["vel"] = Vector2.ZERO
	e_cen["rapidez"] = 0.0

	# El resto, TODOS fuera del corredor del centro. El centro viene desde
	# y=+30 hasta y=-3, y un centro se puede cortar en el camino como
	# cualquier pase: al final del vuelo la pelota ya bajó y el primer
	# rival que le quede en la línea se la lleva. Con los defensores
	# repartidos a lo ancho el centro no llegaba nunca a caer.
	#
	# El primer rival sí queda pegado al que cabecea, pero DETRÁS suyo,
	# entre él y el arco: es el marcador del duelo aéreo, y ahí no toca la
	# trayectoria. Además deja al que cabecea habilitado, con él y el
	# arquero por detrás.
	var i := 0
	var marcador_puesto := false
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if id == clave_cab or id == clave_cen:
			continue
		if str(e["rol"]) == "ARQ":
			if not e["equipo_local"]:
				# Sobre la linea, no DETRAS: antes quedaba medio metro
				# afuera de la cancha y se veia al arquero atajando desde
				# adentro del arco.
				e["pos"] = Vector2(arco.x + hacia * 0.5, 0.0)
			e["vel"] = Vector2.ZERO
			e["rapidez"] = 0.0
			continue
		if e["equipo_local"]:
			# Los compañeros entran al área por el otro palo.
			e["pos"] = Vector2(arco.x + hacia * (7.0 + 3.0 * float(i % 4)), -12.0 - 3.0 * float(i % 3))
		elif not marcador_puesto:
			e["pos"] = Vector2(arco.x + hacia * 1.0, -6.0)
			marcador_puesto = true
		else:
			e["pos"] = Vector2(arco.x + hacia * (4.0 + 3.0 * float(i % 4)), -8.0 - 3.0 * float(i % 4))
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		i += 1

	# El centro sale como pase alto, igual que en un partido: se le pone
	# la altura y la marca de centro, que es lo que hace que no se corte
	# en el camino y que al caer se dispute por arriba.
	MotorEspacial._entregar_pelota(estado, clave_cen)
	estado["pelota"]["pos"] = e_cen["pos"]
	MotorEspacial._lanzar_pase(estado, e_cen, clave_cab, centrador, caida)
	estado["pelota"]["altura_max"] = float(MotorEspacial.pesos()["fisica"]["altura_centro"])
	estado["pelota"]["es_centro"] = true
	estado["pelota"]["centro_de"] = true
	# El centro lo gana el que cabecea, si o si: el arquero no sale a
	# descolgarlo y el marcador no le gana el salto. Sin esto el clip
	# mostraba al arquero descolgando y sacando, y el gol lo terminaba
	# haciendo otro de pie.
	estado["forzar_centro"] = "gana"
	# El remate que salga de este centro entra al arco, y solo si es DE
	# CABEZA. Ver el comentario de arriba y MotorEspacial._resolver_tiro.
	estado["forzar_remate"] = "gol"
	estado["forzar_remate_attr"] = "cabezazo"


## Misma escena y mismo centro que el cabezazo, pero fuerza la variante
## visual de palomita. El motor sigue resolviendo el centro y el remate.
static func _montar_palomita(estado: Dictionary) -> void:
	_montar_cabezazo(estado)
	estado["forzar_centro_accion"] = MotorEspacial.ACCION_PALOMITA


## Misma escena de centro, pero fija el remate de volea y el atributo que
## alimenta la punteria. El motor sigue recorriendo el centro real y dibuja
## la misma accion que en un partido normal.
static func _montar_volea(estado: Dictionary) -> void:
	_montar_cabezazo(estado)
	estado["forzar_centro_accion"] = "volea"
	estado["forzar_remate_attr"] = "volea"


static func _montar_saque_arco(estado: Dictionary) -> void:
	MotorEspacial._dar_pelota_al_arquero(estado, false, true)


## Cadena cerrada para revisar la lectura de DOS rebotes aÃ©reos seguidos:
## remate inicial, manotazo alto, duelo delantero-vs-DFC ganado de cabeza,
## segundo manotazo alto y volea de otro delantero al gol.
static func _montar_cadena_rebotes(estado: Dictionary) -> void:
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	var atacantes: Array = []
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if not e["equipo_local"] or str(e["rol"]) == "ARQ":
			continue
		if str(e["rol"]) in ["DC", "EXT", "MCO"]:
			atacantes.append(int(id))
	if atacantes.size() < 3:
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			if e["equipo_local"] and str(e["rol"]) != "ARQ" and int(id) not in atacantes:
				atacantes.append(int(id))
	if atacantes.size() < 3:
		return

	var defensor := -1
	var arquero := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if not e["equipo_local"] and str(e["rol"]) == "DFC" and defensor == -1:
			defensor = int(id)
		if not e["equipo_local"] and str(e["rol"]) == "ARQ" and arquero == -1:
			arquero = int(id)
	if defensor == -1 or arquero == -1:
		return

	var rematador: int = int(atacantes[0])
	var cabeceador: int = int(atacantes[1])
	var voleador: int = int(atacantes[2])
	var punto_remate := Vector2(arco.x + hacia * 16.0, 0.0)
	var punto_rebote := Vector2(arco.x + hacia * 5.5, 0.0)
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		if int(id) in [rematador, cabeceador, voleador, defensor, arquero]:
			continue
		# Saca al resto del corredor para que la escena tenga solo el duelo
		# delantero-DFC que queremos mirar.
		e["pos"] = Vector2(-2.0, 13.0 + float(posmod(int(id), 3)))

	var e_rematador: Dictionary = estado["jugadores"][rematador]
	var e_cabeceador: Dictionary = estado["jugadores"][cabeceador]
	var e_voleador: Dictionary = estado["jugadores"][voleador]
	var e_defensor: Dictionary = estado["jugadores"][defensor]
	var e_arquero: Dictionary = estado["jugadores"][arquero]
	e_rematador["pos"] = punto_remate
	e_cabeceador["pos"] = punto_rebote + Vector2(-0.8, -1.1)
	e_voleador["pos"] = punto_rebote + Vector2(0.8, 1.1)
	e_defensor["pos"] = punto_rebote + Vector2(0.3, 0.0)
	e_arquero["pos"] = Vector2(arco.x + hacia * 0.4, 0.0)

	var eq_a: Team = MotorEspacial._equipo_de(estado, true)
	var jugador_rematador := {}
	for j in eq_a.jugadores_en_cancha():
		if int(j["id"]) == int(e_rematador["jugador_id"]):
			jugador_rematador = j
			break
	if jugador_rematador.is_empty():
		return

	estado["cadena_rebotes"] = {
		"rebotes_pendientes": 2,
		"punto": punto_rebote,
		"atacantes": [cabeceador, voleador],
		"defensor": defensor,
		"paso": 0,
		"remates": [
			{"atributo": "cabezazo", "accion": MotorEspacial.ACCION_CABECEA, "resultado": "atajada"},
			{"atributo": "volea", "accion": "volea", "resultado": "gol"},
		],
	}
	estado["foco_laboratorio"] = punto_rebote
	MotorEspacial._entregar_pelota(estado, rematador)
	estado["pelota"]["pos"] = punto_remate
	# El primer remate entra al arco y el arquero lo rechaza. Las dos
	# atajadas siguientes las fuerza la cadena, no el azar.
	estado["forzar_remate"] = "atajada"
	estado["forzar_remate_attr"] = "tiro"
	MotorEspacial._resolver_tiro(estado, e_rematador, jugador_rematador, "tiro", MotorEspacial.ACCION_PATEA)


## Un cambio de cada equipo a la vez: sale un titular y entra un suplente,
## los dos por el lateral. Se hacen los dos juntos a proposito — es lo que
## pasa en un partido cuando los dos tecnicos mueven en la misma pausa, y
## asi se ve que la mecanica sirve para los dos equipos.
static func _montar_cambio(estado: Dictionary) -> void:
	# Un cambio solo entra con el juego CORTADO, con el corte venido de
	# antes y con la pelota quieta: son las tres condiciones de
	# MotorEspacial._sincronizar_cambios. Esa pausa la traia de arrastre
	# el saque del medio, que ahora el clip descarta, asi que la monta la
	# jugada. Dos ticks alcanzan: mientras quede alguien caminando, el
	# motor estira la pausa solo.
	var cerca := MotorEspacial._mas_cercano_del_equipo(estado, estado["pelota"]["pos"], true)
	if cerca != -1:
		MotorEspacial._entregar_pelota(estado, cerca)
	estado["detenido"] = 2
	estado["detenido_previo"] = 2
	estado["quietos"] = 0

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


## Clip corto y determinista para ver cada regate sin esperar a que el motor
## lo elija por azar. La accion sigue siendo la misma que en un duelo real:
## el atacante conserva la pelota, el defensor queda superado y la camara
## queda centrada en el contacto.
static func _montar_regate(estado: Dictionary, tipo: String) -> void:
	if tipo not in MotorEspacial.REGATE_ACCIONES:
		return
	var equipo_a: Team = MotorEspacial._equipo_de(estado, true)
	var equipo_d: Team = MotorEspacial._equipo_de(estado, false)
	var elegido := {}
	for jugador in equipo_a.jugadores_en_cancha():
		if str(jugador.get("posicion", "")) == "ARQ":
			continue
		var agilidad := float(jugador.get("atributos", {}).get("agilidad", 0.0))
		if elegido.is_empty() or agilidad > float(elegido.get("atributos", {}).get("agilidad", -1.0)):
			elegido = jugador.duplicate(true)
	if elegido.is_empty():
		return

	var atacante_clave := MotorEspacial.clave_de(int(elegido["id"]), true)
	var defensor_clave := -1
	for id in estado["jugadores"]:
		var candidato: Dictionary = estado["jugadores"][id]
		if not bool(candidato["equipo_local"]) and str(candidato["rol"]) != "ARQ":
			defensor_clave = int(id)
			break
	if defensor_clave == -1 or not estado["jugadores"].has(atacante_clave):
		return

	var origen := Vector2(0.0, 0.0)
	var atacante: Dictionary = estado["jugadores"][atacante_clave]
	var defensor: Dictionary = estado["jugadores"][defensor_clave]
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if int(id) == atacante_clave or int(id) == defensor_clave:
			continue
		# Los demás quedan fuera del corredor para que el gesto se lea.
		e["pos"] = Vector2(32.0 + float(posmod(int(id), 4)) * 2.0,
			18.0 + float(posmod(int(id), 5)) * 2.5)
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
	atacante["pos"] = origen
	atacante["vel"] = Vector2.ZERO
	atacante["rapidez"] = 0.0
	atacante["orientacion"] = Vector2.RIGHT
	defensor["pos"] = origen + Vector2(2.4, 0.0)
	defensor["vel"] = Vector2.ZERO
	defensor["rapidez"] = 0.0
	defensor["orientacion"] = Vector2.LEFT
	MotorEspacial._entregar_pelota(estado, atacante_clave)
	estado["pelota"]["pos"] = origen
	estado["pelota"]["ticks_con_pelota"] = 5
	# La salida de la croqueta ocupa mas cancha que el contacto: centrar el
	# plano entre el rival y el espacio libre evita que el jugador se vaya del
	# encuadre justo cuando acelera.
	estado["foco_laboratorio"] = origen + Vector2(2.2, -1.0) if tipo == "croqueta" \
		else (origen + Vector2(2.5, 0.0) if tipo in ["bicicleta", "globito", "ruleta"] else origen + Vector2(1.0, 0.0))
	estado["detenido"] = 0
	estado["quietos"] = 0
	estado["fotogramas"].clear()

	var evento := {
		"minuto": 12,
		"tipo": "gambeta",
		"equipo": equipo_a.nombre,
		"rival": equipo_d.nombre,
		"jugador_posicion": atacante["rol"],
		"resultado": "pasa",
		"regate": tipo,
	}
	estado["eventos"].append(evento)
	estado["regates"]["home"][tipo] = 1

	# Doce cuadros de gesto y seis de salida: el usuario ve el regate entero
	# y también la aceleración posterior, sin convertirlo en un partido.
	# La fase del sprite termina en el cuadro 11; la salida sigue moviendo al
	# atacante para que el ultimo cuadro no quede congelado.
	for i in range(18):
		var fase_gesto := clampf(float(i) / 11.0, 0.0, 1.0)
		var fase_salida := clampf(float(i - 11) / 6.0, 0.0, 1.0)
		var desplazamiento := _desplazamiento_regate(tipo, fase_gesto, fase_salida)
		atacante["pos"] = origen + desplazamiento
		if tipo == "bicicleta":
			defensor["pos"] = origen + _defensor_bicicleta(fase_gesto)
		elif tipo in ["globito", "ruleta"]:
			# Queda clavado: en el globito la pelota le pasa por arriba y en
			# la ruleta el jugador gira a su lado. Correrlo taparia justo lo
			# que se quiere ver.
			defensor["pos"] = origen + Vector2(2.4, 0.0)
		elif tipo == "croqueta" and fase_gesto < 0.28:
			# El defensor queda de frente: primero hay entrada recta, sin
			# reaccionar antes del traslado real.
			defensor["pos"] = origen + Vector2(2.4, 0.0)
		elif fase_gesto < 0.55:
			defensor["pos"] = origen + Vector2(2.4, 0.0)
		else:
			var inicio_reaccion := 0.70 if tipo == "bicicleta" else (0.55 if tipo != "croqueta" else 0.58)
			var reaccion := clampf((fase_gesto - inicio_reaccion) / (1.0 - inicio_reaccion), 0.0, 1.0)
			defensor["pos"] = origen + Vector2(2.4 + reaccion * 0.35,
				1.0 + reaccion * 2.2)
		estado["pelota"]["pos"] = atacante["pos"]
		estado["tick"] = i
		estado["minuto"] = 12.0 + float(i) * 0.25
		estado["acciones_tick"] = []
		if i == 0:
			MotorEspacial._accion(estado, atacante_clave, "regate_" + tipo)
		MotorEspacial._push_fotograma(estado, [evento] if i == 0 else [])


static func _desplazamiento_regate(tipo: String, fase: float,
		fase_salida: float = 0.0) -> Vector2:
	var avance := Vector2.RIGHT * (2.8 * fase)
	match tipo:
		"croqueta":
			# Croqueta limpia: entra recto, arrastra de un pie al otro hacia
			# el costado y recién después sale recto. Tres tramos visibles.
			if fase < 0.30:
				return Vector2.RIGHT * lerpf(0.0, 1.10, fase / 0.30)
			if fase < 0.66:
				var traslado := smoothstep(0.0, 1.0, (fase - 0.30) / 0.36)
				return Vector2(1.10 + traslado * 0.18, -1.80 * traslado)
			var salida := smoothstep(0.0, 1.0, (fase - 0.66) / 0.34)
			return Vector2(1.28 + salida * 2.10, -1.80)
		"bicicleta":
			# El cuerpo casi no se mueve mientras amaga: las piernas pasan
			# por encima de la pelota. Antes zigzagueaba medio metro a cada
			# lado y parecía que el jugador se teletransportaba.
			var amagues := SpritesPartido.BICICLETA_INICIO_AMAGUES
			var salida := SpritesPartido.BICICLETA_INICIO_SALIDA
			if fase < amagues:
				return Vector2.RIGHT * lerpf(0.0, 0.90, fase / amagues)
			if fase < salida:
				return Vector2.RIGHT * lerpf(0.90, 1.05, (fase - amagues) / (salida - amagues))
			# Los amagues venden el lado del rival: la salida corta al otro
			# lado en diagonal y, pasado el gesto, sigue derecho por al lado
			# del defensor, que quedo clavado (ver _defensor_bicicleta).
			var corte := smoothstep(0.0, 1.0, (fase - salida) / (1.0 - salida))
			return Vector2(1.05 + corte * 0.85 + fase_salida * 3.0,
				-1.1 * corte - 0.1 * fase_salida)
		"globito":
			# Pasado el gesto sigue derecho hasta la pelota, que ya pico.
			return SpritesPartido.globito(fase)["cuerpo"] + Vector2.RIGHT * (2.2 * fase_salida)
		"elastica":
			return Vector2.RIGHT * (2.6 * fase) + Vector2(0.0, sin(fase * TAU) * -1.4)
		"ruleta":
			return SpritesPartido.ruleta(fase)["cuerpo"] + Vector2.RIGHT * (2.2 * fase_salida)
	return avance


## Donde queda el defensor de la bicicleta, relativo al origen del clip.
## Se come los dos amagues: se inclina medio metro hacia el lado que le
## vendieron y ahi queda plantado. El atacante sale por el otro lado.
## Antes el defensor se corria solo hacia un costado y parecia que le
## abria el paso en vez de haber sido engañado.
static func _defensor_bicicleta(fase: float) -> Vector2:
	var amagues := SpritesPartido.BICICLETA_INICIO_AMAGUES
	var salida := SpritesPartido.BICICLETA_INICIO_SALIDA
	var engano := smoothstep(amagues, salida, fase)
	return Vector2(2.4, 0.45 * engano)
