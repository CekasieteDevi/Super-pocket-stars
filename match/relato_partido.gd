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
			if res == "gol":
				if bool(evento.get("con_efecto", false)):
					return "¡GOL CON EFECTO de %s! %s" % [quien, equipo]
				return "¡GOL de %s! %s" % [quien, equipo]
			if bool(evento.get("con_efecto", false)):
				return "Remata con efecto %s y ataja el arquero" % quien
			return "Remata %s y ataja el arquero" % quien
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
			match res:
				"bloqueado": return "Se la bloquean a %s" % quien
				"palo": return "¡Al palo el remate de %s!" % quien
				_: return "Remata %s y se va afuera" % quien
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
	return ""


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
