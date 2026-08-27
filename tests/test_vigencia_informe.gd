extends SceneTree

## §9.4: un informe de scouting caduca a las tres temporadas.

const SEED := 5511


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_caduca_a_las_tres_temporadas(rng)
	_test_se_puede_renovar(rng)
	_test_la_vigencia_sobrevive_al_guardado(rng)
	_test_migracion_de_guardado_viejo(rng)
	quit()


func _investigar_ya(mio: Team, otro: Team, id: int) -> void:
	Investigadores.investigar(mio, id, otro.nombre, "X")
	mio.avanzar_dias(int(Investigadores.dias_de_informe(1)) + 1)


func _test_caduca_a_las_tres_temporadas(rng: RandomNumberGenerator) -> void:
	print("=== El informe se vence a las tres temporadas ===")
	var mio := Team.generar("Mio", rng, 0)
	var otro := Team.generar("Otro", rng, 1000)
	var id: int = otro.jugadores[4]["id"]
	_investigar_ya(mio, otro, id)
	if not Investigadores.conoce(mio, id):
		print("FALLA: no llego a conocerlo.")
		return
	var al_inicio := Investigadores.vigencia(mio, id)

	# Dos temporadas: sigue vigente.
	mio.avanzar_dias(532)
	var sigue := Investigadores.conoce(mio, id)
	# La tercera lo vence.
	mio.avanzar_dias(300)
	var vencio := not Investigadores.conoce(mio, id)
	if sigue and vencio and al_inicio == Investigadores.DIAS_VIGENCIA:
		print("OK: arranca con %d dias, a las 2 temporadas sigue, a las 3 se vencio." % al_inicio)
	else:
		print("FALLA: inicio=%d sigue=%s vencio=%s" % [al_inicio, sigue, vencio])


func _test_se_puede_renovar(rng: RandomNumberGenerator) -> void:
	print("\n=== Vencido, se puede volver a investigar ===")
	var mio := Team.generar("Mio2", rng, 0)
	var otro := Team.generar("Otro2", rng, 1000)
	var id: int = otro.jugadores[6]["id"]
	_investigar_ya(mio, otro, id)
	mio.avanzar_dias(Investigadores.DIAS_VIGENCIA + 10)
	if Investigadores.conoce(mio, id):
		print("FALLA: no se vencio.")
		return
	# Y el investigador quedo libre para volver a mandarlo.
	var r := Investigadores.investigar(mio, id, otro.nombre, "X")
	if not r["exito"]:
		print("FALLA: no se pudo reinvestigar (%s)." % r["motivo"])
		return
	mio.avanzar_dias(int(Investigadores.dias_de_informe(1)) + 1)
	if Investigadores.conoce(mio, id):
		print("OK: se vencio y se pudo volver a investigar de cero.")
	else:
		print("FALLA: no quedo conocido tras reinvestigar.")


func _test_la_vigencia_sobrevive_al_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== La vigencia sobrevive al guardado ===")
	var mio := Team.generar("Mio3", rng, 0)
	var otro := Team.generar("Otro3", rng, 1000)
	var id: int = otro.jugadores[2]["id"]
	_investigar_ya(mio, otro, id)
	mio.avanzar_dias(200)
	var antes := Investigadores.vigencia(mio, id)
	var vuelto := Team.cargar(JSON.parse_string(JSON.stringify(mio.guardar())))
	var despues := Investigadores.vigencia(vuelto, id)
	if antes == despues and antes > 0:
		print("OK: quedaban %d dias antes y despues de guardar." % antes)
	else:
		print("FALLA: antes=%d despues=%d" % [antes, despues])


func _test_migracion_de_guardado_viejo(rng: RandomNumberGenerator) -> void:
	print("\n=== Un guardado viejo (sin caducidad) se migra ===")
	# Antes el valor era `true`: el informe no vencia nunca. Sin migrar,
	# float(true) daria 1 dia y el conocimiento se evaporaria en la
	# primera semana.
	var mio := Team.generar("Mio4", rng, 0)
	var datos: Dictionary = JSON.parse_string(JSON.stringify(mio.guardar()))
	datos["conocimiento"] = {"777": true}
	var vuelto := Team.cargar(datos)
	if Investigadores.vigencia(vuelto, 777) == Investigadores.DIAS_VIGENCIA:
		print("OK: al informe viejo se le da el plazo entero (%d dias)." % Investigadores.DIAS_VIGENCIA)
	else:
		print("FALLA: quedo en %d" % Investigadores.vigencia(vuelto, 777))
