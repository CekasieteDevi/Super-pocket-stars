class_name BusquedaMercado
extends RefCounted

## §9.3 rework: el buscador del mercado. Filtros opcionales, resultado
## alfabético, columnas ordenables — y la NIEBLA.
##
## De un jugador ajeno se ve el nombre, el puesto y la EDAD; lo demás
## queda tapado hasta que un investigador termine su informe (ver
## core/investigadores.gd). De eso se encarga `ficha`: la UI nunca lee el
## jugador directo, para no filtrar un dato sin querer.
##
## La edad es pública porque en el fútbol lo es: sale en cualquier lado y
## no hace falta mandar a nadie a verlo jugar para saber que tiene 33.
## Lo que se paga por averiguar es lo que rinde, lo que cobra y lo que le
## queda de contrato.
##
## El filtro de contrato SI trabaja sobre un dato oculto, y es a
## propósito: filtrar es pedirle a tu gente "traeme volantes con contrato
## corto", no enterarte de cuánto le queda a cada uno. La lista se achica,
## la ficha sigue tapada.

const POSICIONES := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]

## Columnas de la tabla. `clave` es la que ordena, `oculta` marca las que
## solo se ven con informe terminado.
const COLUMNAS := [
	{"clave": "nombre", "titulo": "Nombre", "oculta": false},
	{"clave": "edad", "titulo": "Edad", "oculta": false},
	{"clave": "posicion", "titulo": "Pos", "oculta": false},
	{"clave": "media", "titulo": "Media", "oculta": true},
	{"clave": "valor", "titulo": "Valor", "oculta": true},
	{"clave": "salario", "titulo": "Salario", "oculta": true},
	{"clave": "contrato", "titulo": "Contrato", "oculta": true},
	{"clave": "animo", "titulo": "Ánimo", "oculta": true},
]


## Filtros vacíos: todo opcional, -1 = sin filtro.
static func filtros_vacios() -> Dictionary:
	return {"posicion": "", "edad_min": -1, "edad_max": -1, "contrato_max": -1,
		"division": -1, "club": ""}


## Todos los jugadores de la pirámide que pasan los filtros, MENOS los
## propios. Incluye banco y cantera: la joya de una academia ajena tiene
## que poder aparecer, que es de lo que se trata investigar.
static func buscar(piramide, equipo_propio: Team, filtros: Dictionary) -> Array:
	var salida := []
	var posicion := str(filtros.get("posicion", ""))
	var edad_min := int(filtros.get("edad_min", -1))
	var edad_max := int(filtros.get("edad_max", -1))
	var contrato_max := int(filtros.get("contrato_max", -1))
	var division := int(filtros.get("division", -1))
	# El club solo tiene sentido dentro de una division elegida (asi lo
	# ofrece la UI), pero se filtra por NOMBRE y no por indice para no
	# depender de eso: si el club no esta en la division filtrada, no sale
	# nadie, que es la respuesta correcta.
	var club_filtro := str(filtros.get("club", ""))

	for d in range(piramide.divisiones.size()):
		if division != -1 and d != division:
			continue
		for club in piramide.divisiones[d].equipos:
			if club == equipo_propio:
				continue
			if club_filtro != "" and club.nombre != club_filtro:
				continue
			for grupo in [[club.jugadores, "titular"], [club.banco, "banco"], [club.cantera, "cantera"]]:
				for j in grupo[0]:
					if posicion != "" and str(j["posicion"]) != posicion:
						continue
					var edad := int(j["edad"])
					if edad_min != -1 and edad < edad_min:
						continue
					if edad_max != -1 and edad > edad_max:
						continue
					if contrato_max != -1 and int(club.contratos.get(int(j["id"]), 3)) > contrato_max:
						continue
					salida.append({"equipo": club, "jugador": j, "division": d + 1, "origen": grupo[1]})
	salida.sort_custom(func(a, b): return _alfabetico(a) < _alfabetico(b))
	return salida


static func _alfabetico(entrada: Dictionary) -> String:
	var j: Dictionary = entrada["jugador"]
	return "%s %s" % [str(j.get("apellido", "")), str(j.get("nombre", ""))]


## Lo que se puede MOSTRAR de una entrada. Los campos ocultos vienen como
## null si todavía no hay informe; la UI los dibuja como "?".
static func ficha(equipo_propio: Team, entrada: Dictionary) -> Dictionary:
	var j: Dictionary = entrada["jugador"]
	var club: Team = entrada["equipo"]
	var id := int(j["id"])
	var f := {
		"id": id,
		"nombre": _alfabetico(entrada).strip_edges(),
		"posicion": str(j["posicion"]),
		"edad": int(j["edad"]),
		"club": club.nombre,
		"division": int(entrada["division"]),
		"origen": str(entrada["origen"]),
		"conocido": Investigadores.conoce(equipo_propio, id),
		"progreso": Investigadores.progreso(equipo_propio, id),
	}
	if not f["conocido"]:
		f["media"] = null
		f["valor"] = null
		f["salario"] = null
		f["contrato"] = null
		f["animo"] = null
		return f
	var animo: float = float(club.animo.get(id, 50.0))
	var contrato := int(club.contratos.get(id, 3))
	f["media"] = float(j["media"])
	f["valor"] = ValorJugador.calcular(j, animo, contrato)
	f["salario"] = float(club.sueldos.get(id, 0.0))
	f["contrato"] = contrato
	f["animo"] = animo
	return f


## Ordena las fichas por una columna. Lo desconocido va SIEMPRE al final,
## suba o baje el orden: si no, ordenar por salario te llenaba la pantalla
## de signos de pregunta.
static func ordenar(fichas: Array, clave: String, ascendente: bool) -> Array:
	var conocidas := []
	var tapadas := []
	for f in fichas:
		if f.get(clave) == null:
			tapadas.append(f)
		else:
			conocidas.append(f)
	conocidas.sort_custom(func(a, b):
		var va = a[clave]
		var vb = b[clave]
		if va == vb:
			return str(a["nombre"]) < str(b["nombre"])
		return va < vb if ascendente else va > vb
	)
	return conocidas + tapadas


## Que habilidad se le VE a un jugador. `ajeno` = es de otro club.
##
## Una habilidad DORMIDA —la tiene, pero todavia no llego a la media que
## la manifiesta (Habilidades.MEDIA_MINIMA)— no se muestra de un ajeno:
## por fuera del club no hay forma de saber que esta ahi. Encontrartela
## despues de comprarlo es la sorpresa que hace que valga la pena
## arriesgarse con un juvenil, y verla de antemano la mataria.
##
## En tu propio plantel si se ve, dormida y todo: para eso lo tenes.
static func habilidad_visible(jugador: Dictionary, ajeno: bool) -> Dictionary:
	var h: Dictionary = jugador.get("habilidad", {})
	if h.is_empty():
		return {}
	if not ajeno:
		return h
	return h if Habilidades.tiene_manifestada(jugador, str(h["nombre"])) else {}
