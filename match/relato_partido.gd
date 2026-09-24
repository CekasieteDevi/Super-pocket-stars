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
			return NOTABLE if res == "pierde" else NADA
		"cambio":
			return NOTABLE
		"lesion":
			return NOTABLE
		"jugada":
			# Las de pelota parada se anuncian; la presion tras perdida y la
			# trampa del offside pasan seguido y quedan como detalle.
			return MENOR if str(evento.get("jugada", "")) in [Jugadas.CONTRAPRESION, Jugadas.DEFENSA_ADELANTADA] 				else NOTABLE
	return NADA


## La línea. `nombres` es la tabla clave -> "ROL Apellido" que ya arma
## VistaPartido; si el evento no trae clave (o el jugador no está en la
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
					if bool(evento.get("travesano", false)):
						return "¡Al travesaño el remate%s de %s!" % [tecnica_tiro, quien]
					return "¡Al palo el remate%s de %s!" % [tecnica_tiro, quien]
				_: return "Remata%s %s y se va afuera" % [tecnica_tiro, quien]
		"gambeta":
			if str(evento.get("resultado", "")) == "pierde":
				return "%s se la saca a %s" % [_quien_clave(evento.get("defensor_clave", -1), nombres), quien]
			return "%s deja atras a %s" % [quien, _quien_clave(evento.get("defensor_clave", -1), nombres)]
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
