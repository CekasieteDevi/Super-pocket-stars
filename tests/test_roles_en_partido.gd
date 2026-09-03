extends SceneTree

## Que los roles lleguen de verdad a la cancha (core/motor_espacial.gd).
##
## test_roles.gd prueba la logica de core/roles.gd sola. Esto prueba lo
## otro: que el motor espacial la consulte. Sin esta prueba se podia
## elegir pateador en la pantalla y que el partido siguiera pateando con
## el de siempre.
##
## El caso que origino todo: "acabo de ver al golero patear un penal".
##
## Los penales se montan a mano en vez de esperarlos: medido, el motor
## cobra uno cada veinte partidos, asi que probarlos jugando pediria
## cientos de simulaciones para juntar una muestra.

const SEED := 8123
const JUGADAS := 30
const PARTIDOS := 20


func _init() -> void:
	var fallas := 0
	fallas += _test_el_arquero_no_patea_penales()
	fallas += _test_el_penal_lo_patea_el_designado()
	fallas += _test_el_arquero_no_patea_corners()
	fallas += _test_el_corner_lo_patea_el_designado()
	print("FALLOS=%d" % fallas)
	quit()


## Un estado de partido listo para montarle una jugada encima, igual que
## hace el Laboratorio.
func _estado(rng: RandomNumberGenerator, local: Team, visitante: Team) -> Dictionary:
	local.reset_partido()
	visitante.reset_partido()
	local.local = true
	visitante.local = false
	local.clima_partido = Clima.generar(rng)
	visitante.clima_partido = local.clima_partido
	local.arbitro_partido = Arbitro.generar(rng)
	visitante.arbitro_partido = local.arbitro_partido
	var estado := MotorEspacial.crear_estado(local, visitante, rng)
	MotorEspacial._reiniciar_desde_medio(estado, true, 1)
	for i in range(6):
		MotorEspacial._tick(estado, false)
	return estado


## Le pone al arquero el mejor tiro/centros/libres del plantel. Si el
## motor lo mirara, patearia todo el.
func _arquero_crack(equipo: Team) -> int:
	var maximos := {"tiro": 0.0, "centros": 0.0, "tiros_libres": 0.0}
	for j in equipo.todos_los_jugadores():
		for a in maximos:
			maximos[a] = maxf(maximos[a], float(j["atributos"][a]))
	var id := -1
	for j in equipo.todos_los_jugadores():
		if str(j["posicion"]) != "ARQ":
			continue
		for a in maximos:
			j["atributos"][a] = minf(99.0, maximos[a] + 15.0)
		if id == -1:
			id = int(j["id"])
	return id


## El peor titular para este rol. Titular y no del plantel entero: el
## designado tiene que estar en la cancha para patear.
func _peor_titular(equipo: Team, clave: String) -> int:
	var peor := -1
	var peor_valor := INF
	for j in equipo.jugadores:
		if str(j["posicion"]) == "ARQ":
			continue
		var v := Roles.valor_de(j, clave)
		if v < peor_valor:
			peor_valor = v
			peor = int(j["id"])
	return peor


func _posicion_de(equipo: Team, jugador_id: int) -> String:
	for j in equipo.todos_los_jugadores():
		if int(j["id"]) == jugador_id:
			return str(j["posicion"])
	return "?"


func _test_el_arquero_no_patea_penales() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var arqueros := 0
	var montados := 0
	for i in range(JUGADAS):
		var local := Team.generar("Local", rng, 0)
		var visita := Team.generar("Visita", rng, 1000)
		_arquero_crack(local)
		var estado := _estado(rng, local, visita)
		MotorEspacial._cobrar_penal(estado, true, 20)
		var bp: Dictionary = estado.get("balon_parado", {})
		if not bp.has("pateador_id"):
			continue
		montados += 1
		if _posicion_de(local, int(bp["pateador_id"])) == "ARQ":
			arqueros += 1
	if montados == 0:
		print("FALLA: no se monto ningun penal; la prueba no prueba nada.")
		return 1
	if arqueros > 0:
		print("FALLA: el arquero pateo %d de %d penales." % [arqueros, montados])
		return 1
	print("OK: con el mejor tiro del equipo, el arquero no pateo ninguno de %d penales." % montados)
	return 0


func _test_el_penal_lo_patea_el_designado() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var aciertos := 0
	var montados := 0
	for i in range(JUGADAS):
		var local := Team.generar("Local", rng, 0)
		var visita := Team.generar("Visita", rng, 1000)
		# El PEOR tiro DE LOS TITULARES: asi no puede coincidir por
		# casualidad con el que habria elegido el automatico, y ademas
		# arranca en la cancha. Un designado que empieza en el banco no
		# patea hasta que entre, y eso es lo correcto.
		var designado := _peor_titular(local, Roles.PENALES)
		Roles.asignar(local, Roles.PENALES, designado)

		var estado := _estado(rng, local, visita)
		MotorEspacial._cobrar_penal(estado, true, 20)
		var bp: Dictionary = estado.get("balon_parado", {})
		if not bp.has("pateador_id"):
			continue
		montados += 1
		if int(bp["pateador_id"]) == designado:
			aciertos += 1
	if montados == 0:
		print("FALLA: no se monto ningun penal.")
		return 1
	if aciertos != montados:
		print("FALLA: el designado pateo %d de %d penales." % [aciertos, montados])
		return 1
	print("OK: el designado pateo los %d penales, aun siendo el peor tirador del equipo." % montados)
	return 0


## Los corners si son frecuentes, asi que se miran jugando partidos
## enteros: es la prueba de que el rol sobrevive a un partido de verdad,
## con cambios y expulsiones incluidos.
func _test_el_arquero_no_patea_corners() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var corners := 0
	var arqueros := 0
	for p in range(PARTIDOS):
		var local := Team.generar("Local", rng, 0)
		var visita := Team.generar("Visita", rng, 1000)
		_arquero_crack(local)
		_arquero_crack(visita)
		var r := MotorEspacial.simular(local, visita, rng, false)
		for ev in r.get("eventos", []):
			if str(ev.get("tipo", "")) != "corner":
				continue
			corners += 1
			if str(ev.get("jugador_posicion", "")) == "ARQ":
				arqueros += 1
	if corners == 0:
		print("FALLA: no hubo corners en %d partidos." % PARTIDOS)
		return 1
	if arqueros > 0:
		print("FALLA: el arquero ejecuto %d de %d corners." % [arqueros, corners])
		return 1
	print("OK: %d corners en %d partidos, ninguno pateado por un arquero." % [corners, PARTIDOS])
	return 0


## Aca no se exige el 100%: el designado tiene que poder LLEGAR al
## banderin y, si esta del otro lado de la cancha, la patea el que esta
## cerca. Es a proposito (ver DIST_MAX_EJECUTOR_DESIGNADO). Medido, el
## designado patea el 92% de los corners.
func _test_el_corner_lo_patea_el_designado() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var del_designado := 0
	var total := 0
	for p in range(PARTIDOS):
		var local := Team.generar("Local", rng, 0)
		var visita := Team.generar("Visita", rng, 1000)
		var designado := _peor_titular(local, Roles.CORNERS)
		Roles.asignar(local, Roles.CORNERS, designado)

		var r := MotorEspacial.simular(local, visita, rng, false)
		for ev in r.get("eventos", []):
			if str(ev.get("tipo", "")) != "corner":
				continue
			if str(ev.get("equipo", "")) != local.nombre:
				continue
			total += 1
			if int(ev.get("jugador_id", -1)) == designado:
				del_designado += 1
	if total == 0:
		print("FALLA: el local no pateo corners en %d partidos." % PARTIDOS)
		return 1
	var pct := 100.0 * float(del_designado) / float(total)
	if pct < 50.0:
		print("FALLA: el designado pateo %d de %d corners del local (%.0f%%)." % [
			del_designado, total, pct])
		return 1
	print("OK: el designado pateo %d de %d corners del local (%.0f%%), siendo el peor centrador." % [
		del_designado, total, pct])
	return 0
