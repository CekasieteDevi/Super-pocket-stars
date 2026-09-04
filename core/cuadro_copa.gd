class_name CuadroCopa
extends RefCounted

## Arma el CUADRO de una copa: las llaves ordenadas de forma que se puedan
## dibujar como el cuadro de una copa de verdad, con cada cruce alineado
## entre los dos de los que sale.
##
## El problema es que Copa vuelve a sortear en cada ronda (ver
## Copa.jugar_siguiente_ronda), asi que el orden en que estan guardados los
## cruces no dice nada: dibujarlos tal cual daria un cuadro con las lineas
## cruzadas por todos lados. Lo que se hace aca es reconstruirlo AL REVES,
## desde la ultima ronda hacia atras: debajo de cada cruce se ponen los dos
## cruces de los que salieron sus dos equipos. Asi el cuadro que se ve es
## cierto —cada linea conecta a quien de verdad viene de ahi— y ademas no
## se cruza ninguna.
##
## No se muestran todas las rondas: la Copa del Rey son 128 clubes y su
## primera ronda tiene 64 cruces, que ni entran en pantalla ni le importan
## a nadie. Se muestran las ultimas, desde donde el cuadro tiene un tamaño
## que se puede mirar — que es lo que hacen tambien los cuadros de verdad,
## que arrancan en octavos.

const MAX_COLUMNAS := 4
const MAX_CRUCES := 8


## `copa` viva -> cuadro. Ver armar() para el formato de salida.
static func desde_copa(copa: Copa) -> Dictionary:
	var pendientes := []
	for p in copa.partidos_pendientes:
		pendientes.append([p[0].nombre, p[1].nombre])
	var bye := []
	for e in copa.equipos_con_bye:
		bye.append(e.nombre)
	return armar(copa.historial, pendientes, bye,
		copa.campeon.nombre if copa.campeon != null else "")


## Copa ya jugada y guardada como datos planos (las internacionales, que
## se resuelven enteras al cerrar la temporada).
static func desde_datos(datos: Dictionary) -> Dictionary:
	return armar(datos.get("rondas", []), [], [], str(datos.get("campeon", "")))


## Devuelve:
##   {
##     "columnas": [{"titulo": String, "cruces": Array}],
##     "campeon": String,
##     "rondas_ocultas": int,   # las que no entraron, de las primeras
##     "total_rondas": int,
##   }
## Cada cruce es {local, visitante, gl, gv, ganador, definicion,
## penales_texto, jugado} o {"bye": true, "equipo": nombre} para el hueco
## que deja un equipo que paso sin jugar.
static func armar(historial: Array, pendientes: Array, bye: Array, campeon: String,
		max_columnas: int = MAX_COLUMNAS, max_cruces: int = MAX_CRUCES) -> Dictionary:
	var todas := []
	for ronda in historial:
		var cruces := []
		for p in ronda:
			var c: Dictionary = (p as Dictionary).duplicate()
			c["jugado"] = true
			cruces.append(c)
		todas.append(cruces)
	if not pendientes.is_empty():
		var cruces_pend := []
		for p in pendientes:
			cruces_pend.append({
				"local": str(p[0]), "visitante": str(p[1]),
				"gl": 0, "gv": 0, "ganador": "", "definicion": "",
				"penales_texto": "", "jugado": false,
			})
		todas.append(cruces_pend)

	var salida := {
		"columnas": [], "campeon": campeon,
		"rondas_ocultas": 0, "total_rondas": todas.size(),
		# Los que esperan a la ronda que viene sin jugar esta: no tienen
		# cruce que mostrar, pero siguen vivos y hay que decirlo.
		"esperando": bye.duplicate(),
	}
	if todas.is_empty():
		return salida

	# De atras para adelante, mientras la ronda entre en pantalla. Las
	# rondas viejas tienen MAS cruces (72 en la primera del Rey), asi que
	# el corte pasa solo.
	var desde := todas.size() - 1
	while desde > 0:
		if todas.size() - desde >= max_columnas:
			break
		if todas[desde - 1].size() > max_cruces:
			break
		desde -= 1
	salida["rondas_ocultas"] = desde

	# El orden sin cruces: la ultima columna queda como esta y cada una
	# anterior se reordena siguiendo a los equipos de la siguiente.
	var columnas := []
	for i in range(desde, todas.size()):
		columnas.append(todas[i])
	for c in range(columnas.size() - 1, 0, -1):
		columnas[c - 1] = _ordenar_debajo(columnas[c], columnas[c - 1])

	# El titulo sale de cuantos EQUIPOS entran a la ronda, no de cuantos
	# cruces tiene: con 20 clubes la primera ronda son 4 cruces y 12 que
	# pasan sin jugar, y llamarla "cuartos de final" por tener 4 cruces
	# seria mentira. Los que entran se reconstruyen de derecha a
	# izquierda: los que entran a una ronda son sus cruces por dos mas los
	# que pasaron sin jugar, y esos ultimos salen de la diferencia con la
	# ronda siguiente.
	var entrando := []
	entrando.resize(columnas.size())
	entrando[columnas.size() - 1] = columnas[columnas.size() - 1].size() * 2 + bye.size()
	for c in range(columnas.size() - 2, -1, -1):
		var byes_c: int = maxi(entrando[c + 1] - columnas[c].size(), 0)
		entrando[c] = columnas[c].size() * 2 + byes_c

	for i in range(columnas.size()):
		salida["columnas"].append({
			"titulo": _titulo(int(entrando[i])), "cruces": columnas[i],
		})
	return salida


## Deja `anterior` en el orden que le corresponde debajo de `siguiente`:
## para cada cruce de la siguiente, primero el cruce del que salio su
## local y despues el del que salio su visitante. El que no viene de
## ningun cruce (paso con bye) deja un hueco marcado, para que las dos
## columnas sigan midiendo lo mismo y todo quede alineado.
static func _ordenar_debajo(siguiente: Array, anterior: Array) -> Array:
	var nuevo := []
	var usados := {}
	for cruce in siguiente:
		for equipo in [str(cruce["local"]), str(cruce["visitante"])]:
			var idx := -1
			for i in range(anterior.size()):
				if usados.has(i):
					continue
				if str(anterior[i].get("ganador", "")) == equipo:
					idx = i
					break
			if idx >= 0:
				usados[idx] = true
				nuevo.append(anterior[idx])
			else:
				nuevo.append({"bye": true, "equipo": equipo})
	# No deberia quedar ninguno suelto (todo ganador juega la ronda que
	# sigue), pero si queda no se tira: un cuadro al que le falta un cruce
	# es peor que uno con un cruce de mas al final.
	for i in range(anterior.size()):
		if not usados.has(i):
			nuevo.append(anterior[i])
	return nuevo


## `equipos` = cuantos entran a esa ronda. Si no es potencia de dos, es
## una ronda previa: la que se juega justamente para dejar el cuadro
## parejo de ahi en adelante.
static func _titulo(equipos: int) -> String:
	if equipos < 2:
		return "Final"
	var potencia := 1
	while potencia < equipos:
		potencia *= 2
	if potencia != equipos:
		return "Ronda previa"
	match equipos:
		2:
			return "Final"
		4:
			return "Semifinales"
		8:
			return "Cuartos de final"
		16:
			return "Octavos de final"
		32:
			return "Dieciseisavos"
		64:
			return "Treintaidosavos"
	return "Ronda de %d" % equipos


## Como le fue a un club en la copa, en una linea. Es lo primero que se
## mira al abrir la pantalla y no siempre esta en el pedazo de cuadro que
## se muestra: en el Rey podes haber quedado afuera en la segunda ronda,
## seis columnas antes de la primera que se dibuja.
static func camino_de(historial: Array, pendientes: Array, bye: Array,
		campeon: String, club: String) -> String:
	if club == "":
		return ""
	if campeon == club:
		return "Campeón."
	var total := historial.size()
	for i in range(total):
		for p in historial[i]:
			if str(p["local"]) != club and str(p["visitante"]) != club:
				continue
			if str(p["ganador"]) == club:
				break
			var rival := str(p["visitante"]) if str(p["local"]) == club else str(p["local"])
			# El marcador de los 90 no cuenta la historia de un cruce que
			# se definio por penales: 0-0 y afuera no se entiende.
			var como := str(p.get("penales_texto", "")).strip_edges()
			if como == "" and str(p.get("definicion", "")) == "alargue":
				como = "(en el alargue)"
			return "Eliminado en la ronda %d de %d por %s (%d-%d)%s." % [
				i + 1, total, rival, int(p["gl"]), int(p["gv"]),
				"  %s" % como if como != "" else ""]
	for p in pendientes:
		if str(p[0]) == club or str(p[1]) == club:
			var rival := str(p[1]) if str(p[0]) == club else str(p[0])
			return "Próxima ronda (%d): contra %s." % [total + 1, rival]
	if bye.has(club):
		return "Pasa sin jugar a la ronda %d." % (total + 2)
	# No aparece en ninguna ronda: no es que lo eliminaron, es que no
	# clasifico. Vale para las tres internacionales (se juegan entre los
	# mejores de cada pais) y tambien para las dos domesticas, que desde
	# que reparten cupos por tabla tampoco las juegan todos.
	return "No clasificaste a esta copa."
