extends SceneTree

## Sponsors: el catalogo, la escala de pago por division, las reglas de
## los lugares y los requisitos.

const SEED := 9090


func _init() -> void:
	var fallas := 0
	fallas += _test_catalogo()
	fallas += _test_escala()
	fallas += _test_lugares()
	fallas += _test_requisitos()
	fallas += _test_peso_en_la_economia()
	fallas += _test_cobro_por_temporada()
	print("FALLOS=%d" % fallas)
	quit()


func _test_catalogo() -> int:
	var fallas := 0
	var cat := Sponsors.catalogo()
	if cat.size() != 10:
		print("FALLA: el catalogo tiene %d divisiones y tienen que ser 10." % cat.size())
		fallas += 1
	var vistos := {}
	for d in range(cat.size()):
		if cat[d].size() != 20:
			print("FALLA: la division %d tiene %d sponsors y tienen que ser 20." % [
				d + 1, cat[d].size()])
			fallas += 1
		for s in cat[d]:
			if vistos.has(str(s["nombre"])):
				print("FALLA: \"%s\" esta repetido." % s["nombre"])
				fallas += 1
			vistos[str(s["nombre"])] = true
			if not Sponsors.PAGO_D10.has(str(s["requisito"])):
				print("FALLA: \"%s\" pide un requisito que no existe (%s)." % [
					s["nombre"], s["requisito"]])
				fallas += 1
	if fallas == 0:
		print("OK: 10 divisiones x 20 sponsors, %d nombres distintos, todos con requisito valido." % vistos.size())
	return fallas


## El mismo requisito paga MUCHO mas arriba: es la razon por la que
## cancelar al kiosco cuando ascendes vale la pena.
func _test_escala() -> int:
	var d10 := Sponsors.pago_de("no_ultimo", 1.0, 9)
	var d1 := Sponsors.pago_de("no_ultimo", 1.0, 0)
	if absf(d10 - Sponsors.PAGO_D10["no_ultimo"]) > 0.01:
		print("FALLA: en division 10 el pago no es el de PAGO_D10 (%.1f)." % d10)
		return 1
	if d1 < d10 * 100.0:
		print("FALLA: primera paga %.0f y decima %.0f, muy poca diferencia." % [d1, d10])
		return 1
	print("OK: el mismo sponsor paga %s por temporada en decima y %s en primera." % [
		Economia.formato_dinero(d10), Economia.formato_dinero(d1)])
	# Y el mas exigente paga mas que el que no pide nada.
	if Sponsors.pago_de("campeon", 1.0, 9) <= Sponsors.pago_de("ninguno", 1.0, 9):
		print("FALLA: pedir el campeonato no paga mas que no pedir nada.")
		return 1
	print("OK: cuanto mas piden, mas pagan.")
	return 0


func _test_lugares() -> int:
	var fallas := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipo := Team.generar("Prueba", rng, 0)

	# Con los diez lugares llenos NO llega ninguna oferta.
	for i in range(Sponsors.LUGARES):
		equipo.sponsors.append({"nombre": "Relleno %d" % i, "requisito": "ninguno",
			"pago": 10.0, "division": 10, "desde": 1, "cobrado": 0.0, "partidos": 0})
	var llegaron := 0
	for dia in range(400):
		llegaron += Sponsors.tirar_ofertas(equipo, 9, 1, 20, rng).size()
	if llegaron == 0:
		print("OK: con los diez lugares ocupados no llega ni una oferta en 400 dias.")
	else:
		print("FALLA: llegaron %d ofertas con los lugares llenos." % llegaron)
		fallas += 1

	# Aceptar con todo lleno tampoco se puede.
	equipo.sponsors_ofertas.append({"nombre": "Colado", "requisito": "ninguno",
		"pago": 10.0, "division": 10, "dias": 5})
	var r := Sponsors.aceptar(equipo, "Colado", 1)
	if not r["exito"]:
		print("OK: no se puede aceptar sin lugar (%s)." % r["motivo"])
	else:
		print("FALLA: se acepto un sponsor numero 11.")
		fallas += 1

	# Con un lugar libre si llegan.
	equipo.sponsors.remove_at(0)
	equipo.sponsors_ofertas = []
	llegaron = 0
	for dia in range(400):
		llegaron += Sponsors.tirar_ofertas(equipo, 9, 1, 20, rng).size()
		Sponsors.avanzar_dias(equipo, 1)
	if llegaron > 0:
		print("OK: con un lugar libre llegaron %d ofertas en 400 dias." % llegaron)
	else:
		print("FALLA: con lugar libre no llego ninguna oferta.")
		fallas += 1

	# Al que va ultimo le escriben MENOS que al que va primero.
	var como_primero := _contar_ofertas(1, 20)
	var como_ultimo := _contar_ofertas(20, 20)
	if como_primero > como_ultimo:
		print("OK: al puntero le escriben %d veces y al ultimo %d." % [
			como_primero, como_ultimo])
	else:
		print("FALLA: al ultimo le escriben igual o mas que al puntero (%d vs %d)." % [
			como_ultimo, como_primero])
		fallas += 1
	return fallas


func _contar_ofertas(puesto: int, total: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + puesto
	var equipo := Team.generar("Prueba", rng, 0)
	var n := 0
	for dia in range(2000):
		n += Sponsors.tirar_ofertas(equipo, 9, puesto, total, rng).size()
		equipo.sponsors_ofertas = []
	return n


func _test_requisitos() -> int:
	var fallas := 0
	var casos := [
		["ninguno", 20, 20, true], ["no_ultimo", 20, 20, false],
		["no_ultimo", 19, 20, true], ["mitad_tabla", 10, 20, true],
		["mitad_tabla", 11, 20, false], ["top5", 5, 20, true],
		["top5", 6, 20, false], ["top3", 3, 20, true],
		["campeon", 1, 20, true], ["campeon", 2, 20, false],
	]
	for c in casos:
		if Sponsors.cumple(str(c[0]), int(c[1]), int(c[2])) != bool(c[3]):
			print("FALLA: %s saliendo %d de %d dio lo contrario de lo esperado." % [
				c[0], c[1], c[2]])
			fallas += 1
	if fallas == 0:
		print("OK: los %d casos de requisito dan lo esperado." % casos.size())

	# Al cerrar la temporada se va el que no cumplio y se queda el que si.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# Un club de decima como la gente: desde la v1.5 los sponsors tambien
	# miran reputacion e hinchada, asi que un equipo con reputacion 0 y
	# cero hinchas perderia hasta el kiosco y no probaria lo que se
	# quiere probar aca, que es el requisito DEPORTIVO.
	var equipo := Team.generar("Prueba", rng, 0,
		NivelDivision.potencial(9), "Uruguay", NivelDivision.realizacion(9))
	equipo.division_actual = 9
	equipo.reputacion = Reputacion.MAXIMO
	equipo.fans = Fans.fans_para_apoyo(1.0, 9)
	equipo.sponsors = [
		{"nombre": "Kiosco", "requisito": "ninguno", "pago": 10.0, "division": 10,
			"desde": 1, "cobrado": 380.0, "partidos": 38},
		{"nombre": "Grande", "requisito": "campeon", "pago": 100.0, "division": 10,
			"desde": 1, "cobrado": 3800.0, "partidos": 38},
	]
	var caidos := Sponsors.evaluar_temporada(equipo, 7, 20, 9)
	if caidos.size() == 1 and str(caidos[0]["nombre"]) == "Grande" \
			and equipo.sponsors.size() == 1:
		print("OK: saliendo 7°, el que pedia el campeonato se va y el otro se queda.")
	else:
		print("FALLA: la evaluacion de fin de temporada dejo %s y echo %s." % [
			equipo.sponsors, caidos])
		fallas += 1
	if absf(float(equipo.sponsors[0]["cobrado"])) < 0.01:
		print("OK: lo cobrado se reinicia con la temporada.")
	else:
		print("FALLA: el contador de cobrado no se reinicio (%s)." % equipo.sponsors[0]["cobrado"])
		fallas += 1
	return fallas


## Cuanto pesan los sponsors en el ingreso del club. Tienen que ser una
## fuente de plata que valga la pena administrar, no el ingreso entero.
func _test_peso_en_la_economia() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	var fallas := 0
	for d in [0, 4, 9]:
		var equipo: Team = piramide.divisiones[d].equipos[0]
		var r := Economia.procesar_temporada(equipo, 10, 20, d)
		var ingreso: float = float(r["ingresos"])
		# Diez sponsors del escalon medio de esa division, a año completo.
		var por_temporada: float = Sponsors.pago_de("no_ultimo", 1.0, d) * 10.0
		var pct: float = 100.0 * por_temporada / ingreso
		print("   division %2d: 10 sponsors dan %s por temporada, %.0f%% del ingreso (%s)" % [
			d + 1, Economia.formato_dinero(por_temporada), pct,
			Economia.formato_dinero(ingreso)])
		if pct < 10.0 or pct > 60.0:
			print("FALLA: en division %d los sponsors serian el %.0f%% del ingreso." % [d + 1, pct])
			fallas += 1
	if fallas == 0:
		print("OK: en las tres divisiones medidas los sponsors pesan entre 10% y 60% del ingreso.")
	return fallas


## Los sponsors cobran al CERRAR la temporada, no fecha a fecha.
##
## Antes cobraban por partido y la plata iba a un acumulador que no se
## veia hasta el cierre: un sponsor que decia "paga por partido" no movia
## el presupuesto en ningun partido. Ahora el numero es el del año.
func _test_cobro_por_temporada() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var fallas := 0
	var fechas := Sponsors.partidos_de_liga()

	# Un sponsor que estuvo todo el año cobra el pago entero.
	var entero := Team.generar("ClubEntero", rng, 0)
	entero.sponsors = [_sponsor(1000.0)]
	for f in range(fechas):
		Sponsors.registrar_partido(entero)
	# Durante la temporada NO entra plata.
	if absf(entero.ingresos_sponsors) > 0.01:
		print("FALLA: entro plata durante la temporada (%s)." % entero.ingresos_sponsors)
		fallas += 1
	var cobrado := Sponsors.cobrar_temporada(entero)
	if absf(cobrado - 1000.0) > 0.01:
		print("FALLA: el año completo cobro %.2f y tendria que cobrar 1000." % cobrado)
		fallas += 1
	if absf(entero.ingresos_sponsors - 1000.0) > 0.01:
		print("FALLA: el acumulador del club quedo en %.2f." % entero.ingresos_sponsors)
		fallas += 1

	# El que firma con el año empezado cobra la parte proporcional.
	var mitad := Team.generar("ClubMitad", rng, 0)
	mitad.sponsors = [_sponsor(1000.0)]
	for f in range(fechas / 2):
		Sponsors.registrar_partido(mitad)
	var parcial := Sponsors.cobrar_temporada(mitad)
	if absf(parcial - 500.0) > 30.0:
		print("FALLA: media temporada cobro %.2f y tendria que cobrar ~500." % parcial)
		fallas += 1

	# Y el que firma sobre el final casi no cobra: si cobrara el año
	# entero, convendria dejar los diez lugares vacios hasta la ultima
	# fecha.
	var tarde := Team.generar("ClubTarde", rng, 0)
	tarde.sponsors = [_sponsor(1000.0)]
	Sponsors.registrar_partido(tarde)
	var poco := Sponsors.cobrar_temporada(tarde)
	if poco > 100.0:
		print("FALLA: firmando en la ultima fecha cobro %.2f." % poco)
		fallas += 1

	if fallas == 0:
		print("OK: %d fechas cobran %s, media temporada %s y una sola fecha %s." % [
			fechas, Economia.formato_dinero(cobrado),
			Economia.formato_dinero(parcial), Economia.formato_dinero(poco)])
	return fallas


func _sponsor(pago: float) -> Dictionary:
	return {
		"nombre": "Marca de prueba", "requisito": "ninguno", "pago": pago,
		"division": 10, "desde": 1, "cobrado": 0.0, "partidos": 0,
	}
