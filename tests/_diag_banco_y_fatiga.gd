extends SceneTree

## Cuantos suplentes hay por puesto, y con cuanta resistencia arranca
## cada partido un titular que juega todas las fechas.

const SEED := 2200


func _init() -> void:
	_composicion()
	_recuperacion()
	_temporada()
	_lo_que_ve_el_jugador()
	quit()


func _composicion() -> void:
	print("=== Plantel por formacion ===")
	for f in Formaciones.lista():
		var titulares := {}
		for r in Formaciones.roles(f):
			titulares[r] = int(titulares.get(r, 0)) + 1
		var banco := {}
		for r in Formaciones.banco_para(f):
			banco[r] = int(banco.get(r, 0)) + 1
		var linea := []
		var claves := titulares.keys()
		claves.sort()
		for r in claves:
			linea.append("%s %d+%d" % [r, int(titulares[r]), int(banco.get(r, 0))])
		var sin_suplente := []
		for r in claves:
			if int(banco.get(r, 0)) == 0:
				sin_suplente.append(r)
		print("  %-14s %s   | sin suplente: %s" % [
			f, " ".join(linea), "-" if sin_suplente.is_empty() else str(sin_suplente)])


func _recuperacion() -> void:
	print("\n=== Cuantos dias para volver al 100%% ===")
	print("  recuperacion base: %.1f%% por dia" % (Team.RECUPERACION_FATIGA_POR_DIA * 100.0))
	for desde in [0.55, 0.65, 0.75, 0.85]:
		var dias := int(ceil((1.0 - desde) / Team.RECUPERACION_FATIGA_POR_DIA))
		print("  desde %.0f%% -> %d dias (hoy entre fechas pasan 7)" % [desde * 100.0, dias])


func _temporada() -> void:
	print("\n=== Con que resistencia arranca cada fecha un titular fijo ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[9]
	var mio: Team = liga.equipos[0]
	# El delantero titular: el puesto del que se queja el jugador.
	var dc := {}
	for j in mio.jugadores:
		if str(j["posicion"]) == "DC":
			dc = j
			break
	if dc.is_empty():
		print("  (este plantel no tiene DC)")
		return
	print("  siguiendo a %s %s (DC, energia %d)" % [
		dc["nombre"], dc["apellido"], int(dc["atributos"]["energia"])])
	var linea := []
	for fecha in range(mini(10, liga.fixture.size())):
		linea.append("%.0f%%" % (mio.fatiga_acumulada.get(dc["id"], 1.0) * 100.0))
		# CON equipo_jugador: sus partidos los resuelve el motor espacial,
		# que es el que ve el jugador y desgasta distinto.
		liga.jugar_fecha(fecha, rng, mio)
		for l in piramide.divisiones:
			l.avanzar_dias(7)
	print("  al empezar cada fecha: %s" % " ".join(linea))
	print("
  todo el once titular al empezar la fecha 10:")
	for j in mio.jugadores.slice(0, 11):
		print("    %-4s %-22s energia %3d -> arranca al %3.0f%%" % [
			str(j["posicion"]), "%s %s" % [j["nombre"], j["apellido"]],
			int(j["atributos"]["energia"]),
			mio.fatiga_acumulada.get(j["id"], 1.0) * 100.0])


## Lo que MUESTRA la UI contra lo que el jugador va a tener de verdad
## cuando arranque el proximo partido.
func _lo_que_ve_el_jugador() -> void:
	print("\n=== Lo que muestra la pantalla vs. lo real ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 5
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[9]
	var mio: Team = liga.equipos[0]
	liga.jugar_fecha(0, rng, mio)
	for l in piramide.divisiones:
		l.avanzar_dias(7)
	print("  (justo despues de jugar la fecha y avanzar los 7 dias)")
	for j in mio.todos_los_jugadores():
		print("    %-4s %-22s la UI dice %3.0f%%  | va a arrancar al %3.0f%%" % [
			str(j["posicion"]), "%s %s" % [j["nombre"], j["apellido"]],
			mio.resistencia_pct(j["id"]) * 100.0,
			mio.fatiga_acumulada.get(j["id"], 1.0) * 100.0])
