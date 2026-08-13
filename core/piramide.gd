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


static func generar(rng: RandomNumberGenerator) -> Piramide:
	var p := Piramide.new()
	var siguiente_id := 0
	for d in range(N_DIVISIONES):
		var nombres := []
		for i in range(EQUIPOS_POR_DIVISION):
			nombres.append("D%d Club %02d" % [d + 1, i + 1])
		var liga := Liga.new()
		liga.inicializar(nombres, rng, siguiente_id)
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

	var movimientos := _ejecutar_ascensos_y_descensos(ordenes, rng)

	for liga in divisiones:
		liga.iniciar_temporada()

	return {"informes_por_division": informes, "movimientos": movimientos}


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
			movimientos.append({"equipo": equipo.nombre, "tipo": "ascenso directo", "de_division": limite + 2, "a_division": limite + 1})

		var candidato: Team = orden_peor[2]
		var defensor: Team = orden_mejor[17]
		var resultado_playoff := MatchEngine.simular(defensor, candidato, rng, false)
		if resultado_playoff["goles_visitante"] > resultado_playoff["goles_local"]:
			peor.equipos.erase(candidato)
			mejor.equipos.append(candidato)
			mejor.equipos.erase(defensor)
			peor.equipos.append(defensor)
			movimientos.append({"equipo": candidato.nombre, "tipo": "ascenso por playoff", "de_division": limite + 2, "a_division": limite + 1})
			movimientos.append({"equipo": defensor.nombre, "tipo": "descenso por playoff", "de_division": limite + 1, "a_division": limite + 2})

		for i in [18, 19]:
			var equipo: Team = orden_mejor[i]
			mejor.equipos.erase(equipo)
			peor.equipos.append(equipo)
			movimientos.append({"equipo": equipo.nombre, "tipo": "descenso directo", "de_division": limite + 1, "a_division": limite + 2})

	return movimientos
