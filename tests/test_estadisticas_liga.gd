extends SceneTree

## Estadisticas individuales de la liga: que se acumulen, que sumen lo
## mismo que la tabla y que sobrevivan al guardado.

const SEED := 9137
const FECHAS := 6


func _init() -> void:
	var fallas := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var liga := Liga.new()
	var nombres := []
	for i in range(10):
		nombres.append("Club %d" % i)
	liga.inicializar(nombres, rng, 0, 5)
	liga.iniciar_temporada()

	var seguido: Team = liga.equipos[0]
	for f in range(FECHAS):
		liga.jugar_fecha(f, rng, seguido)

	# Los 0-3 por no presentarse suman a la tabla pero no los hizo nadie:
	# no hay partido. Se descuentan para poder comparar.
	var goles_tabla := 0
	for n in liga.tabla:
		goles_tabla += int(liga.tabla[n]["gf"])
	for noticia in liga.noticias:
		if str(noticia).contains("pierde 0-3"):
			goles_tabla -= 3
	var goles_ind := 0
	var asist := 0
	var amarillas := 0
	var vallas := 0
	for k in liga.estadisticas:
		var fila: Dictionary = liga.estadisticas[k]
		goles_ind += int(fila["goles"])
		asist += int(fila["asistencias"])
		amarillas += int(fila["amarillas"])
		vallas += int(fila["vallas"])

	if goles_ind == goles_tabla:
		print("OK: los %d goles de la tabla estan repartidos entre jugadores." % goles_tabla)
	else:
		print("FALLA: la tabla tiene %d goles y las individuales %d." % [goles_tabla, goles_ind])
		fallas += 1

	if asist > 0 and asist <= goles_ind:
		print("OK: %d asistencias en %d goles (%.0f%%)." % [
			asist, goles_ind, 100.0 * asist / maxi(goles_ind, 1)])
	else:
		print("FALLA: asistencias fuera de rango (%d sobre %d goles)." % [asist, goles_ind])
		fallas += 1

	if amarillas > 0:
		print("OK: %d amarillas acumuladas." % amarillas)
	else:
		print("FALLA: no se acumulo ninguna amarilla.")
		fallas += 1

	# Un partido 0-x le da valla invicta a UN arquero, nunca a dos del
	# mismo equipo, y como mucho hay 2 por partido (0-0).
	var partidos: int = FECHAS * int(liga.equipos.size() / 2.0)
	if vallas >= 0 and vallas <= partidos * 2:
		print("OK: %d vallas invictas en %d partidos." % [vallas, partidos])
	else:
		print("FALLA: %d vallas invictas en %d partidos, imposible." % [vallas, partidos])
		fallas += 1

	# Todas las vallas tienen que ser de arqueros.
	for k in liga.estadisticas:
		var fila: Dictionary = liga.estadisticas[k]
		if int(fila["vallas"]) > 0 and str(fila["posicion"]) != "ARQ":
			print("FALLA: %s (%s) tiene valla invicta sin ser arquero." % [
				fila["nombre"], fila["posicion"]])
			fallas += 1
			break

	var top := EstadisticasLiga.ranking(liga.estadisticas, "goles", 5)
	if top.size() > 0 and int(top[0]["goles"]) >= int(top[top.size() - 1]["goles"]):
		print("OK: el ranking de goleadores viene ordenado (lider %s con %d)." % [
			top[0]["nombre"], int(top[0]["goles"])])
	else:
		print("FALLA: el ranking de goleadores no viene ordenado.")
		fallas += 1

	# Guardar y cargar: los numeros no pueden volver como float ni perderse.
	var texto := JSON.stringify(liga.guardar())
	var recargada := Liga.cargar(JSON.parse_string(texto))
	var goles_recargados := 0
	for k in recargada.estadisticas:
		goles_recargados += int(recargada.estadisticas[k]["goles"])
	if goles_recargados == goles_ind \
			and recargada.estadisticas.size() == liga.estadisticas.size():
		print("OK: sobreviven al guardado (%d filas, %d goles)." % [
			recargada.estadisticas.size(), goles_recargados])
	else:
		print("FALLA: al recargar quedaron %d filas / %d goles (habia %d / %d)." % [
			recargada.estadisticas.size(), goles_recargados,
			liga.estadisticas.size(), goles_ind])
		fallas += 1

	# Temporada nueva: las individuales arrancan de cero, como la tabla.
	liga.iniciar_temporada()
	if liga.estadisticas.is_empty():
		print("OK: la temporada nueva arranca sin estadisticas viejas.")
	else:
		print("FALLA: quedaron %d filas de la temporada anterior." % liga.estadisticas.size())
		fallas += 1

	print("FALLOS=%d" % fallas)
	quit()
