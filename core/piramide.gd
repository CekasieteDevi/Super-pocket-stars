class_name Piramide
extends RefCounted

## Pirámide de 10 divisiones — Fase 7 (GDD §10, §15 decisión 18: Uruguay,
## 10 divisiones, 200 clubes). División 1 = la mejor (arriba de todo),
## división 10 = la peor (donde arranca el jugador, GDD original).
##
## Copas nacionales e internacionales (§10.1-§10.5) quedan para un paso
## siguiente — esto es la base estructural (ascensos/descensos) sobre la
## que se van a montar.
##
## Regla de movimiento entre división D (mejor) y D+1 (peor), 20 equipos
## cada una, posiciones 1-20:
##   - 1° y 2° de D+1 ascienden directo a D.
##   - 3° de D+1 juega un partido único contra el 18° de D por el 3er
##     ascenso: si gana el visitante (3° de D+1), sube y el 18° de D baja;
##     si gana o empata el local (18° de D), no se mueve nadie por ese cruce.
##   - 19° y 20° de D descienden directo a D+1.
## División 1 nunca asciende (no hay nada arriba) y división 10 nunca
## desciende (Fix #6 del GDD original: "en división 10 no hay descenso").
## El propio bucle sobre los 9 límites entre divisiones ya deja afuera esos
## casos sin condición especial: división 1 nunca aparece como "peor" y
## división 10 nunca aparece como "mejor".

const N_DIVISIONES := 10
const EQUIPOS_POR_DIVISION := 20

var divisiones: Array = []  # Liga, indice 0 = division 1 (mejor) .. 9 = division 10 (peor)


## Guardado de partida — ver Team.guardar().
func guardar() -> Dictionary:
	var divisiones_datos := []
	for l in divisiones:
		divisiones_datos.append(l.guardar())
	return {"divisiones": divisiones_datos}


static func cargar(datos: Dictionary) -> Piramide:
	var p := Piramide.new()
	for ld in datos["divisiones"]:
		var liga_cargada := Liga.cargar(ld)
		# Liga no guarda su propia categoria, pero la piramide las guarda
		# EN ORDEN: el indice es la fuente de verdad. Sin esto, al cargar
		# una partida nadie sabia en que division jugaba y el efecto copa
		# (§8.4#28) no se disparaba nunca.
		liga_cargada.division = p.divisiones.size()
		for e in liga_cargada.equipos:
			e.division_actual = liga_cargada.division
		p.divisiones.append(liga_cargada)
	# El escalon no se guarda: es la posicion en el array (ver Liga.division).
	for d in range(p.divisiones.size()):
		p.divisiones[d].division = d
	p.resolver_prestamos()

	# Migración de guardados de antes de §8.4 #14 (clásicos): si nadie de
	# una división tiene rival_directo todavía, se hornea recién ahora —
	# el pareo depende del orden de equipos.size() de ESA división en
	# particular (ascensos/descensos ya movieron equipos entre divisiones
	# desde que se creó la partida), así que no se puede resolver por
	# nombre de club como estilo/DT/cancha.
	for liga in p.divisiones:
		var alguien_con_clasico := false
		for equipo in liga.equipos:
			if equipo.rival_directo != "":
				alguien_con_clasico = true
				break
		if not alguien_con_clasico:
			Rivalidad.hornear_clasicos(liga.equipos)

	return p


## Team.guardar() no puede serializar una referencia a otro Team (JSON no
## entiende objetos) — guarda el NOMBRE del club en su lugar. Esta segunda
## pasada, una vez que TODA la pirámide ya existe, reemplaza esos nombres
## por la referencia real al Team correspondiente (buscando en las 10
## divisiones, no solo en la propia — un préstamo puede haber cruzado
## divisiones si el equipo prestado ascendió/descendió después).
func resolver_prestamos() -> void:
	var por_nombre := {}
	for liga in divisiones:
		for equipo in liga.equipos:
			por_nombre[equipo.nombre] = equipo

	for liga in divisiones:
		for equipo in liga.equipos:
			for id in equipo.prestados_afuera:
				var info: Dictionary = equipo.prestados_afuera[id]
				info["club"] = por_nombre.get(info["club"])
			for id in equipo.prestados_propios:
				var info: Dictionary = equipo.prestados_propios[id]
				info["club_dueno"] = por_nombre.get(info["club_dueno"])


static func generar(rng: RandomNumberGenerator) -> Piramide:
	var p := Piramide.new()
	var siguiente_id := 0
	var nombres_usados := {}  # compartido entre las 10 divisiones: ningún club repite nombre
	for d in range(N_DIVISIONES):
		var nombres := []
		for i in range(EQUIPOS_POR_DIVISION):
			nombres.append(GeneradorNombres.nombre_club(rng, nombres_usados))
		var liga := Liga.new()
		liga.inicializar(nombres, rng, siguiente_id, d)
		Rivalidad.hornear_clasicos(liga.equipos)
		siguiente_id += EQUIPOS_POR_DIVISION * Team.RANGO_IDS_RESERVADO
		p.divisiones.append(liga)
	return p


## Corre todas las fechas de las 10 divisiones. Para jugar de a una fecha
## por división (como haría la UI) iterar liga.jugar_fecha() vos mismo.
func jugar_temporada(rng: RandomNumberGenerator) -> void:
	for liga in divisiones:
		liga.jugar_temporada(rng, false)


## Cierra la temporada: economía/mercado/progresión con la tabla recién
## jugada, decide y ejecuta ascensos/descensos, y arma el fixture nuevo de
## cada división con su composición ya actualizada.
## equipo_protegido: el club del jugador humano, si corresponde — nunca
## participa del mercado automático entre clubes de la IA (ver Mercado).
func fin_de_temporada(rng: RandomNumberGenerator, equipo_protegido: Team = null, temporada_actual: int = 0) -> Dictionary:
	var ordenes := []  # por division: Array de Team, en el orden final de tabla
	for liga in divisiones:
		var mapa := {}
		for equipo in liga.equipos:
			mapa[equipo.nombre] = equipo
		var orden := []
		for nombre in liga.tabla_ordenada():
			orden.append(mapa[nombre])
		ordenes.append(orden)

	var informes := []
	for liga in divisiones:
		informes.append(liga.procesar_economia_y_mercado_y_progresion(rng, equipo_protegido, temporada_actual))

	# §9.3: recien ahora, con la economia de TODAS las divisiones ya
	# procesada, los clubes de arriba salen a comprar abajo. Va antes de
	# ascensos y descensos a proposito: se ficha con la categoria de la
	# temporada que termino, que es la plata que se cobro.
	var transferencias := Mercado.ventana_entre_divisiones(self, rng, equipo_protegido)
	for t in transferencias:
		var liga_destino: Liga = divisiones[t["a_division"] - 1]
		if t["joya"]:
			liga_destino.noticias.append(
				"FICHAJES: %s (division %d) se lleva a una joven promesa de %s (division %d) por %s — media %d, techo %d." % [
					t["a"], t["a_division"], t["de"], t["de_division"],
					Economia.formato_dinero(t["valor"]), int(t["media"]), t["potencial"]])
		else:
			liga_destino.noticias.append(
				"FICHAJES: %s (division %d) refuerza el puesto de %s con un jugador de %s (division %d) por %s." % [
					t["a"], t["a_division"], t["posicion"], t["de"], t["de_division"],
					Economia.formato_dinero(t["valor"])])

	var movimientos := _ejecutar_ascensos_y_descensos(ordenes, rng)

	for liga in divisiones:
		liga.iniciar_temporada()

	return {"informes_por_division": informes, "movimientos": movimientos,
		"transferencias_entre_divisiones": transferencias}


## ¿Ya hay un club con ese nombre? Importa porque el nombre es la CLAVE
## de la tabla de posiciones y de media docena de indices mas: dos clubes
## con el mismo nombre se pisarian los puntos.
func existe_nombre(nombre: String) -> bool:
	for liga in divisiones:
		for e in liga.equipos:
			if e.nombre == nombre:
				return true
	return false


## Le cambia el nombre a un club arreglando todo lo que lo referencia por
## texto. Devuelve false si el nombre esta tomado o vacio.
##
## Hay que hacerlo temprano —al empezar la partida, antes de que se armen
## la confederacion y las copas— porque de ahi en mas el nombre viaja a
## demasiados lados: la tabla lo usa de clave, los clasicos lo guardan
## como texto, y cada jugador lleva de que club viene.
func renombrar(equipo: Team, nuevo: String) -> bool:
	var limpio := nuevo.strip_edges()
	if limpio == "" or existe_nombre(limpio):
		return false
	var viejo := equipo.nombre

	for liga in divisiones:
		if not liga.equipos.has(equipo):
			continue
		# La tabla esta indexada por nombre: hay que mover la fila, no
		# agregar una nueva, o el club aparece dos veces.
		if liga.tabla.has(viejo):
			liga.tabla[limpio] = liga.tabla[viejo]
			liga.tabla.erase(viejo)
		# El clasico se guarda como texto en los dos sentidos.
		for otro in liga.equipos:
			if otro.rival_directo == viejo:
				otro.rival_directo = limpio

	# De donde viene cada jugador (§8.4#26).
	for j in equipo.todos_los_jugadores():
		if str(j.get("club_actual", "")) == viejo:
			j["club_actual"] = limpio
		var ex: Array = j.get("ex_clubes", [])
		for i in range(ex.size()):
			if str(ex[i]) == viejo:
				ex[i] = limpio

	equipo.nombre = limpio
	return true


func _ejecutar_ascensos_y_descensos(ordenes: Array, rng: RandomNumberGenerator) -> Array:
	var movimientos := []

	for limite in range(N_DIVISIONES - 1):
		var mejor: Liga = divisiones[limite]
		var peor: Liga = divisiones[limite + 1]
		var orden_mejor: Array = ordenes[limite]
		var orden_peor: Array = ordenes[limite + 1]

		for i in range(2):
			var equipo: Team = orden_peor[i]
			peor.equipos.erase(equipo)
			mejor.equipos.append(equipo)
			equipo.division_actual = limite
			Fans.actualizar_por_movimiento_de_division(equipo, true)
			movimientos.append({"equipo": equipo.nombre, "tipo": "ascenso directo", "de_division": limite + 2, "a_division": limite + 1})

		var candidato: Team = orden_peor[2]
		var defensor: Team = orden_mejor[17]
		var resultado_playoff := MatchEngine.simular(defensor, candidato, rng, false)
		if resultado_playoff["goles_visitante"] > resultado_playoff["goles_local"]:
			peor.equipos.erase(candidato)
			mejor.equipos.append(candidato)
			mejor.equipos.erase(defensor)
			peor.equipos.append(defensor)
			candidato.division_actual = limite
			defensor.division_actual = limite + 1
			Fans.actualizar_por_movimiento_de_division(candidato, true)
			Fans.actualizar_por_movimiento_de_division(defensor, false)
			movimientos.append({"equipo": candidato.nombre, "tipo": "ascenso por playoff", "de_division": limite + 2, "a_division": limite + 1})
			movimientos.append({"equipo": defensor.nombre, "tipo": "descenso por playoff", "de_division": limite + 1, "a_division": limite + 2})

		for i in [18, 19]:
			var equipo: Team = orden_mejor[i]
			mejor.equipos.erase(equipo)
			peor.equipos.append(equipo)
			equipo.division_actual = limite + 1
			Fans.actualizar_por_movimiento_de_division(equipo, false)
			movimientos.append({"equipo": equipo.nombre, "tipo": "descenso directo", "de_division": limite + 1, "a_division": limite + 2})

	return movimientos
