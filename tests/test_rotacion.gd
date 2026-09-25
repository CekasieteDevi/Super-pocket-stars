extends SceneTree

## Cansancio y rotación (core/cansancio.gd, Alineacion.rotar).
##
## Simula diez partidos seguidos de un mismo club, alternando liga
## (prioridad alta) y copa de división (prioridad baja) con tres o cuatro
## días entre partidos. Imprime la energía con la que llega cada titular y
## si jugó (J) o descansó (-). Tiene que verse rotación en las copas y a
## los titulares en la liga, salvo los que llegan con 50% o menos.

const SEED := 90210

var fallos := 0


func _init() -> void:
	_test_franjas()
	_test_prioridad_de_torneo()
	_test_diez_partidos()
	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, texto_ok: String, texto_falla: String) -> void:
	if condicion:
		print("OK: " + texto_ok)
	else:
		print("FALLA: " + texto_falla)
		fallos += 1


func _test_franjas() -> void:
	print("\n=== Franjas de energía: un jugador de 80 ===")
	print("energía | franja       | factor | atributo 80")
	var casos := [[1.00, 1.0], [0.76, 1.0], [0.75, 0.90], [0.51, 0.90],
		[0.50, 0.80], [0.26, 0.80], [0.25, 0.65], [0.10, 0.65]]
	var bien := true
	for caso in casos:
		var e: float = caso[0]
		var f := Cansancio.factor_stats(e)
		print("%6d%% | %-12s | %.2f   | %.0f" % [Cansancio.porcentaje(e),
			Cansancio.NOMBRE_FRANJA[Cansancio.franja(e)], f,
			Duel.atributo_efectivo(80.0, "tecnico", e)])
		bien = bien and is_equal_approx(f, float(caso[1]))
	_ok(bien, "las franjas cortan en 76/51/26 y castigan 0/10/20/35%.",
		"alguna franja no da el factor esperado.")
	_ok(Cansancio.riesgo_lesion(0.25) > Cansancio.riesgo_lesion(0.26),
		"el agotado (25% o menos) tiene más riesgo de lesión.",
		"el agotado no suma riesgo de lesión.")


func _test_prioridad_de_torneo() -> void:
	print("\n=== Prioridad de cada torneo ===")
	var bajas := ["Copa Division 3", "Copa del Rey", "Copa Nacional"]
	var altas := ["Liga", "Copa de Guerreros - Eliminacion", "Playoff"]
	var bien := true
	for n in bajas:
		bien = bien and Cansancio.prioridad_de_torneo(n) == Cansancio.BAJA
	for n in altas:
		bien = bien and Cansancio.prioridad_de_torneo(n) == Cansancio.ALTA
	_ok(bien, "copas de división y nacional son baja; el resto, alta.",
		"alguna prioridad de torneo está mal.")


func _test_diez_partidos() -> void:
	print("\n=== Diez partidos seguidos: energía al llegar y quién jugó ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var club := Team.generar("Grande", rng, 0, NivelDivision.potencial(0),
		"Uruguay", NivelDivision.realizacion(0))
	club.rotacion_automatica = true
	# Los rivales de liga son del mismo nivel. Los de copa, de dos
	# divisiones más abajo: el caso "equipo grande contra uno de tercera".
	var rival_liga := Team.generar("Par", rng, 400, NivelDivision.potencial(0),
		"Uruguay", NivelDivision.realizacion(0))
	var rival_copa := Team.generar("Chico", rng, 800, NivelDivision.potencial(3),
		"Uruguay", NivelDivision.realizacion(3))
	for rival in [rival_liga, rival_copa]:
		rival.rotacion_automatica = false

	var prioridades := [Cansancio.ALTA, Cansancio.BAJA, Cansancio.ALTA, Cansancio.ALTA,
		Cansancio.BAJA, Cansancio.ALTA, Cansancio.BAJA, Cansancio.ALTA, Cansancio.ALTA, Cansancio.BAJA]
	var dias_despues := [3, 4, 3, 4, 3, 4, 3, 4, 3, 4]
	var titulares: Array = []
	for j in club.jugadores:
		titulares.append(j)
	var filas := {}
	for t in titulares:
		filas[int(t["id"])] = ""

	var alta_mal := 0
	var alta_cansados_afuera := 0
	var alta_cansados := 0
	var descansos_baja := 0
	var baja_jugados := 0
	var bajo_en_el_partido := true
	var recupero := true
	for i in range(prioridades.size()):
		var prioridad: int = prioridades[i]
		var rival: Team = rival_liga if prioridad == Cansancio.ALTA else rival_copa
		var energia_antes := {}
		# Con dos partidos por semana el plantel entero se funde, y a veces
		# no queda nadie más descansado para el puesto. Ese titular juega
		# igual: no cuenta como una rotación que faltó.
		var sin_reemplazo := {}
		for t in titulares:
			energia_antes[int(t["id"])] = club.energia_proximo_partido(int(t["id"]))
		var rotados := Alineacion.rotar_partido(club, rival, prioridad)
		var once := {}
		for j in club.jugadores:
			once[int(j["id"])] = true
		# El titular que ya descansó hoy tampoco sirve de reemplazo.
		var ocupados: Array = once.keys()
		for paso in rotados.get(club, []):
			ocupados.append(int(paso["sale"]))
		for t in titulares:
			var id_t := int(t["id"])
			if once.has(id_t) and Alineacion._reemplazo_descansado(club, t,
					energia_antes[id_t], INF, ocupados).is_empty():
				sin_reemplazo[id_t] = true
		MatchEngine.simular(club, rival, rng)
		club.registrar_desgaste_partido()
		rival.registrar_desgaste_partido()
		Alineacion.deshacer_partido(rotados)

		for t in titulares:
			var id := int(t["id"])
			var e: float = energia_antes[id]
			var jugo: bool = once.has(id)
			filas[id] += " %3d%s" % [Cansancio.porcentaje(e), "J" if jugo else "-"]
			if not club.puede_jugar(id):
				continue
			if jugo and club.energia_proximo_partido(id) >= e:
				bajo_en_el_partido = false
			if prioridad == Cansancio.ALTA:
				if Cansancio.franja(e) >= 2 and sin_reemplazo.has(id):
					pass
				elif Cansancio.franja(e) >= 2:
					alta_cansados += 1
					if not jugo:
						alta_cansados_afuera += 1
				elif not jugo:
					alta_mal += 1
			else:
				if jugo:
					baja_jugados += 1
				else:
					descansos_baja += 1

		var antes_de_descansar := club.energia_proximo_partido(int(titulares[0]["id"]))
		for eq in [club, rival_liga, rival_copa]:
			eq.avanzar_dias(int(dias_despues[i]))
		if club.energia_proximo_partido(int(titulares[0]["id"])) < antes_de_descansar:
			recupero = false

	var encabezado := "puesto  "
	for p in prioridades:
		encabezado += "  %s " % ("LIG" if p == Cansancio.ALTA else "COP")
	print(encabezado)
	for t in titulares:
		print("%-7s%s" % [str(t["posicion"]), filas[int(t["id"])]])

	_ok(bajo_en_el_partido, "todo titular que jugó terminó con menos energía.",
		"alguien jugó y no se cansó.")
	_ok(recupero, "los días entre partidos devuelven energía.",
		"los días de descanso no recuperaron.")
	_ok(alta_mal == 0,
		"en la liga jugaron todos los titulares con más de 50%.",
		"en la liga descansaron %d titulares que estaban arriba de 50%%." % alta_mal)
	_ok(alta_cansados_afuera == alta_cansados,
		"en la liga descansaron los %d que llegaron con 50%% o menos." % alta_cansados,
		"en la liga jugaron %d titulares con 50%% o menos." % (alta_cansados - alta_cansados_afuera))
	_ok(descansos_baja > baja_jugados,
		"en las copas descansaron %d titulares y jugaron %d." % [descansos_baja, baja_jugados],
		"en las copas casi no hubo rotación: descansaron %d y jugaron %d." % [descansos_baja, baja_jugados])
