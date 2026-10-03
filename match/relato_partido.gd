class_name RelatoPartido
extends RefCounted

## Convierte un evento del motor en una línea de relato. Vive acá y no en
## el motor por la misma razón que la tabla de apellidos: el motor no
## tiene por qué saber que alguien va a narrar el partido.
##
## No todo evento se cuenta. El motor emite un evento por pase completado
## y por quite; narrarlos todos sería un teletipo ilegible corriendo a
## cuatro líneas por segundo. Solo pasan los momentos que un relator
## marcaría, y con la IMPORTANCIA se decide cuánto se sostienen en
## pantalla y si además prenden el festejo.

## Cuánto vale cada momento. El gol manda sobre todo lo demás: si en el
## mismo tick entra un gol y se cobra un córner, se cuenta el gol.
const NADA := 0
const MENOR := 1
const NOTABLE := 2
const MAXIMA := 3

## Cuántos segundos de verdad se sostiene el relato según la importancia del
## momento. En segundos de verdad y no del partido: así el texto se lee igual
## a x1 que a x16.
const SEG_RELATO := {MENOR: 2.0, NOTABLE: 3.0, MAXIMA: 4.0}


## Tabla clave -> "ROL Apellido" de los dos planteles, para nombrar a cada
## uno en el relato y en el cartel de quién tiene la pelota. Se arma acá y no
## en el motor: es un dato de presentación.
static func nombres(local: Team, visitante: Team) -> Dictionary:
	var tabla := {}
	for par in [[local, true], [visitante, false]]:
		var equipo: Team = par[0]
		for j in equipo.todos_los_jugadores():
			tabla[BasePartido.clave_de(j["id"], par[1])] = "%s %s" % [j["posicion"], j["apellido"]]
	return tabla


## Qué tan importante es este evento. NADA = no se cuenta.
static func importancia(evento) -> int:
	if evento == null or not (evento is Dictionary):
		return NADA
	var tipo := str(evento.get("tipo", ""))
	var res := str(evento.get("resultado", ""))
	match tipo:
		"tiro_puerta":
			return MAXIMA if res == "gol" else NOTABLE
		"penal", "penal_tanda", "tanda_arranca":
			return MAXIMA
		"tarjeta":
			return NOTABLE
		"tiro":
			return MENOR if res == "afuera" else NOTABLE
		"saque_inicial":
			return NOTABLE
		"offside", "corner":
			return MENOR
		"falta":
			return MENOR
		"gambeta":
			# El quite se cuenta fuerte; la gambeta ganada, de pasada.
			return NOTABLE if res == "pierde" else MENOR
		"pase":
			# Solo el pase perdido: los completados son el ruido de fondo.
			return MENOR if res == "pierde" else NADA
		"control":
			return MENOR if res == "se_le_va" else NADA
		"centro":
			return MENOR
		"rebote_arquero":
			match res:
				"gol": return MAXIMA
				"control_atacante": return NOTABLE
				"control_defensor": return MENOR
			return NADA
		"cambio":
			return NOTABLE
		"lesion":
			return NOTABLE
		"jugada":
			# Las de pelota parada se anuncian; la presion tras perdida y la
			# trampa del offside pasan seguido y quedan como detalle.
			return MENOR if str(evento.get("jugada", "")) in [Jugadas.CONTRAPRESION, Jugadas.DEFENSA_ADELANTADA] 				else NOTABLE
	return NADA


## La línea. `nombres` es la tabla clave -> "ROL Apellido" que arma
## RelatoPartido.nombres; si el evento no trae clave (o el jugador no está en la
## tabla) se cae al rol, que siempre viene.
static func linea(evento: Dictionary, nombres: Dictionary) -> String:
	var quien := _quien(evento, nombres)
	var equipo := str(evento.get("equipo", ""))
	var res := str(evento.get("resultado", ""))
	match str(evento.get("tipo", "")):
		"tiro_puerta":
			var tecnica := str(evento.get("tecnica", ""))
			var gesto := _nombre_tecnica(tecnica)
			var asistencia := _asistencia(evento, nombres)
			# El efecto se narra solo en el remate de pie común. Con cabeza,
			# volea o chilena el gesto ya describe el tiro, y "GOL CON EFECTO
			# de volea" suena a dos remates distintos a la vez.
			var con_efecto := bool(evento.get("con_efecto", false)) and gesto == ""
			if res == "gol":
				if bool(evento.get("palo", false)):
					return "¡GOL%s de %s%s! Pega en el palo y entra. %s" % [gesto, quien, asistencia, equipo]
				if con_efecto:
					return "¡GOL CON EFECTO de %s%s! %s" % [quien, asistencia, equipo]
				return "¡GOL%s de %s%s! %s" % [gesto, quien, asistencia, equipo]
			if con_efecto:
				return "Remata con efecto %s y ataja el arquero" % quien
			return "Remata%s %s y ataja el arquero" % [gesto, quien]
		"penal":
			if res == "gol":
				return "¡PENAL! %s la cambia por gol" % quien
			return "¡PENAL atajado! Se lo tapan a %s" % quien
		"tanda_arranca":
			return "Se define por penales"
		"penal_tanda":
			# El marcador de la tanda va EN la linea: en una tanda lo que
			# importa no es el remate sino como queda la serie.
			var serie := "%d-%d" % [
				int(evento.get("tanda_local", 0)), int(evento.get("tanda_visitante", 0))]
			if res == "gol":
				return "%s convierte: %s" % [quien, serie]
			return "¡La ataja el arquero! %s la falla: %s" % [quien, serie]
		"tarjeta":
			if res == "amarilla":
				return "Amarilla para %s (%s)" % [quien, equipo]
			if res == "roja_doble_amarilla":
				return "¡Segunda amarilla! Expulsado %s (%s)" % [quien, equipo]
			return "¡ROJA directa! Se va %s (%s)" % [quien, equipo]
		"tiro":
			var tecnica_tiro := _nombre_tecnica(str(evento.get("tecnica", "")))
			match res:
				"bloqueado": return "%s bloquea el remate%s de %s" % [_quien_clave(evento.get("bloqueador_clave", -1), nombres), tecnica_tiro, quien]
				"palo":
					var golpe := "travesaño" if bool(evento.get("travesano", false)) else "palo"
					match str(evento.get("destino_palo", "")):
						"afuera": return "¡El remate%s de %s pega en el %s y se va afuera!" % [tecnica_tiro, quien, golpe]
						"corner": return "¡El remate%s de %s pega en el %s, roza al arquero y se va al córner!" % [tecnica_tiro, quien, golpe]
						"en_juego": return "¡El remate%s de %s pega en el %s! La pelota sigue en juego" % [tecnica_tiro, quien, golpe]
						_: return "¡Al %s el remate%s de %s!" % [golpe, tecnica_tiro, quien]
				_: return "Remata%s %s y se va afuera" % [tecnica_tiro, quien]
		"gambeta":
			var defensor := _quien_clave(evento.get("defensor_clave", -1), nombres)
			if res == "pierde":
				return _una(evento, [
					"%s se la saca a %s" % [defensor, quien],
					"¡Qué quite de %s! Se la roba a %s" % [defensor, quien],
					"%s pierde la pelota ante %s" % [quien, defensor],
				])
			var regate := _nombre_regate(str(evento.get("regate", "")))
			if regate != "":
				return "¡%s de %s! Deja atrás a %s" % [regate, quien, defensor]
			return _una(evento, [
				"%s deja atrás a %s" % [quien, defensor],
				"%s se saca de encima a %s" % [quien, defensor],
			])
		"pase":
			var pasador := _quien_clave(evento.get("pasador_clave", -1), nombres)
			var sin_pasador := not nombres.has(int(evento.get("pasador_clave", -1)))
			if sin_pasador:
				return "La corta %s (%s)" % [quien, str(evento.get("rival", ""))]
			if bool(evento.get("corte", false)):
				return _una(evento, [
					"Mal pase de %s, la corta %s" % [pasador, quien],
					"%s lee el pase de %s y se queda con la pelota" % [quien, pasador],
					"Pase impreciso de %s, recupera %s" % [pasador, quien],
				])
			return _una(evento, [
				"Se adelanta %s y se queda con el pase de %s" % [quien, pasador],
				"El pase de %s no llega: la gana %s" % [pasador, quien],
			])
		"control":
			return _una(evento, [
				"Se le va larga a %s" % quien,
				"Mal control de %s, la pelota se le escapa" % quien,
				"%s no la puede dominar" % quien,
			])
		"centro":
			var centrador := _quien_clave(evento.get("centrador_clave", -1), nombres)
			var con_centrador := nombres.has(int(evento.get("centrador_clave", -1)))
			var de := (" de %s" % centrador) if con_centrador else ""
			match res:
				"despeja": return _una(evento, [
					"Centro%s y despeja %s" % [de, quien],
					"Rechaza %s el centro%s" % [quien, de],
				])
				"descuelga": return "Centro%s y sale el arquero: la descuelga %s" % [de, quien]
				"gana": return "Centro%s, la gana de arriba %s" % [de, quien]
			return ""
		"rebote_arquero":
			match res:
				"gol": return "¡GOL! El rebote del arquero termina adentro. %s" % equipo
				"control_atacante": return "¡Da rebote el arquero y le queda a %s!" % quien
				"control_defensor": return "Da rebote el arquero y despeja %s" % quien
			return ""
		"cambio":
			var sale := _quien_clave(evento.get("saliente_clave", -1), nombres)
			var entra := _quien_clave(evento.get("entrante_clave", -1), nombres)
			return "Cambio: sale %s, entra %s" % [sale, entra]
		"lesion":
			return "¡Lesión! %s no puede seguir (%s)" % [quien, str(evento.get("lesion", "lesión"))]
		"saque_inicial":
			match res:
				"1": return "¡Arranca el partido!"
				"2": return "Arranca el segundo tiempo"
				"3": return "¡Se va al alargue!"
				_: return "Arranca el segundo tiempo del alargue"
		"offside":
			return "Offside de %s" % quien
		"corner":
			return "Córner para %s" % equipo
		"falta":
			return "Falta de %s" % quien
		"jugada":
			var texto := Jugadas.relato(str(evento.get("jugada", "")))
			return "" if texto == "" else "%s (%s)" % [texto, equipo]
	return ""


static func _nombre_tecnica(tecnica: String) -> String:
	match tecnica:
		"cabecea", "cabezazo": return " de cabeza"
		"palomita": return " de palomita"
		"volea": return " de volea"
		"chilena": return " de chilena"
		_: return ""


## Elige una de las variantes para que el mismo momento no se diga siempre
## igual. Sale del minuto y del jugador, no de un rng: el mismo partido
## repetido se narra igual.
static func _una(evento: Dictionary, variantes: Array) -> String:
	var semilla := int(evento.get("minuto", 0)) * 7 + int(evento.get("clave", 0)) * 3 		+ int(evento.get("defensor_clave", evento.get("pasador_clave", 0)))
	return str(variantes[posmod(semilla, variantes.size())])


static func _nombre_regate(regate: String) -> String:
	match regate:
		"bicicleta": return "Bicicleta"
		"croqueta": return "Croqueta"
		"ruleta": return "Ruleta"
		"globito": return "Sombrerito"
		"elastica": return "Elástica"
	return ""


static func _quien_clave(valor, nombres: Dictionary) -> String:
	var clave := int(valor)
	return str(nombres.get(clave, "el rival"))


static func _asistencia(evento: Dictionary, nombres: Dictionary) -> String:
	if bool(evento.get("tiro_libre", false)):
		return ""
	var clave := int(evento.get("asistencia_clave", -1))
	if clave == -1 or not nombres.has(clave):
		return ""
	return " (asistencia de %s)" % str(nombres[clave])


static func _quien(evento: Dictionary, nombres: Dictionary) -> String:
	var clave := int(evento.get("clave", -1))
	if clave != -1 and nombres.has(clave):
		var nombre := str(nombres[clave])
		# `nombres` conserva el puesto natural del jugador, pero durante el
		# partido puede ocupar otro slot (por una eleccion tactica o un
		# cambio). La cancha muestra el rol del slot; el relato debe hacer lo
		# mismo para no decir "DFC" cuando en pantalla juega de "DC".
		var rol := str(evento.get("jugador_posicion", ""))
		if rol != "" and nombre.find(" ") != -1:
			return "%s%s" % [rol, nombre.substr(nombre.find(" "))]
		return nombre
	var rol := str(evento.get("jugador_posicion", ""))
	return rol if rol != "" else "el equipo"
