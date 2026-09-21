extends SceneTree

## §7.4.2: ejercicios de entrenamiento del equipo, una ranura física y
## una táctica.

const SEED := 5150

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_elegir_no_regala_crecimiento()
	_test_ejercicio_chico_empuja_mas_por_atributo()
	_test_arqueros_crecen_parejo()
	_test_cambiar_a_mitad_de_temporada_reparte(rng)
	_test_reinicio_por_temporada(rng)
	_test_la_ia_entrena_lo_que_juega(rng)
	_test_guardado(rng)
	_test_guardado_viejo_migra(rng)
	_test_bonus_solo_del_elegido(rng)
	_test_penal_es_una_situacion(rng)
	_test_correr_cansa_menos(rng)
	_test_penales_suma_en_la_tanda(rng)
	print("\nFALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, texto_ok: String, texto_falla: String) -> void:
	if condicion:
		print("OK: " + texto_ok)
	else:
		print("FALLA: " + texto_falla)
		fallos += 1


func _total(mult: Dictionary) -> float:
	var t := 0.0
	for k in mult:
		t += float(mult[k])
	return t


func _test_elegir_no_regala_crecimiento() -> void:
	print("=== Elegir reparte, no regala ===")
	# Si el total subiera al elegir, "libre" no lo elegiria nadie y el
	# ejercicio seria un boton de mas-es-mejor en vez de una decision.
	var attrs := PlayerGenerator.get_all_attributes()
	var base := _total(Entrenamiento.multiplicadores({}, attrs))
	var peor := 0.0
	for ranura in Entrenamiento.RANURAS:
		for ejercicio in Entrenamiento.EJERCICIOS[ranura]:
			peor = maxf(peor, absf(_total(Entrenamiento.multiplicadores({ejercicio: 1.0}, attrs)) - base))
	var par := _total(Entrenamiento.multiplicadores({"correr": 1.0, "presion": 1.0}, attrs))
	_ok(peor < 0.01 and absf(par - base) < 0.01,
		"cada ejercicio y un par suman lo mismo que libre (%.1f)." % base,
		"un ejercicio se aparta %.2f y el par suma %.2f contra %.2f." % [peor, par, base])


func _test_ejercicio_chico_empuja_mas_por_atributo() -> void:
	print("\n=== Un ejercicio chico empuja mas por atributo ===")
	# Con un bonus fijo por atributo, el ejercicio de mas atributos seria
	# siempre mejor y no habria nada que elegir.
	var attrs := PlayerGenerator.get_all_attributes()
	var chico := Entrenamiento.multiplicadores({"presion": 1.0}, attrs)
	var grande := Entrenamiento.multiplicadores({"correr": 1.0}, attrs)
	_ok(float(chico["quite"]) > float(grande["velocidad"]),
		"quite con presion x%.2f > velocidad con correr x%.2f." % [chico["quite"], grande["velocidad"]],
		"quite x%.2f no supera a velocidad x%.2f." % [chico["quite"], grande["velocidad"]])


func _test_arqueros_crecen_parejo() -> void:
	print("\n=== Ningun ejercicio es de arqueros ===")
	var grupos: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/attribute_groups.json"))
	var arquero: Array = grupos["arquero"]
	var tocados := []
	for ejercicio in Entrenamiento.ATRIBUTOS:
		for attr in Entrenamiento.atributos_de(ejercicio):
			if arquero.has(attr):
				tocados.append(attr)
	_ok(tocados.is_empty(), "ningun ejercicio lista atributos de arquero.",
		"atributos de arquero en ejercicios: %s." % [tocados])


func _test_cambiar_a_mitad_de_temporada_reparte(rng: RandomNumberGenerator) -> void:
	print("\n=== Cambiar a mitad de temporada reparte ===")
	var e := Team.generar("Reparto", rng, 0)
	e.reiniciar_carga()
	e.ejercicio_fisico = "correr"
	e.ejercicio_tactico = "penales"
	e.avanzar_dias(70)   # 10 semanas
	e.ejercicio_fisico = "gimnasio"
	e.avanzar_dias(70)   # otras 10
	var reparto := e.reparto_ejercicios()
	var c: float = float(reparto.get("correr", 0.0))
	var g: float = float(reparto.get("gimnasio", 0.0))
	var p: float = float(reparto.get("penales", 0.0))
	# Cada ranura se reparte por su lado: penales estuvo toda la temporada.
	_ok(absf(c - 0.5) < 0.01 and absf(g - 0.5) < 0.01 and absf(p - 1.0) < 0.01,
		"50% correr y 50% gimnasio; penales 100% en su ranura.",
		"reparto correr %.2f / gimnasio %.2f / penales %.2f." % [c, g, p])


func _test_reinicio_por_temporada(rng: RandomNumberGenerator) -> void:
	print("\n=== El reparto se reinicia con la temporada ===")
	var e := Team.generar("Reinicio", rng, 0)
	e.ejercicio_fisico = "correr"
	e.avanzar_dias(70)
	e.reiniciar_carga()
	_ok(e.reparto_ejercicios().is_empty(), "arranca la temporada nueva sin semanas acumuladas.",
		"quedaron semanas de la temporada anterior: %s" % [e.reparto_ejercicios()])


func _test_la_ia_entrena_lo_que_juega(rng: RandomNumberGenerator) -> void:
	print("\n=== Los clubes de la IA entrenan segun su estilo ===")
	# Sin esto los 200 clubes entrenarian "libre" y el sistema solo
	# existiria para el jugador.
	var piramide := Piramide.generar(rng)
	var vistos := {}
	var coherentes := 0
	var total := 0
	for liga in piramide.divisiones:
		for e in liga.equipos:
			vistos[e.ejercicio_fisico] = true
			vistos[e.ejercicio_tactico] = true
			total += 1
			if [e.ejercicio_fisico, e.ejercicio_tactico] == Entrenamiento.para_estilo(e.estilo):
				coherentes += 1
	_ok(coherentes == total and vistos.size() >= 6,
		"los %d clubes entrenan segun su estilo, %d ejercicios distintos." % [total, vistos.size()],
		"%d/%d coherentes, %d ejercicios distintos." % [coherentes, total, vistos.size()])


func _test_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== Los ejercicios sobreviven al guardado ===")
	var e := Team.generar("Guardado", rng, 0)
	e.reiniciar_carga()
	e.ejercicio_fisico = "obstaculos"
	e.ejercicio_tactico = "centros"
	e.avanzar_dias(35)
	var vuelto := Team.cargar(JSON.parse_string(JSON.stringify(e.guardar())))
	var r_antes := e.reparto_ejercicios()
	var r_despues := vuelto.reparto_ejercicios()
	_ok(vuelto.ejercicio_fisico == "obstaculos" and vuelto.ejercicio_tactico == "centros" \
			and absf(float(r_antes.get("centros", 0.0)) - float(r_despues.get("centros", 0.0))) < 0.01,
		"ejercicios y semanas acumuladas iguales despues de guardar y cargar.",
		"quedo %s + %s con reparto %s." % [vuelto.ejercicio_fisico, vuelto.ejercicio_tactico, r_despues])


func _test_guardado_viejo_migra(rng: RandomNumberGenerator) -> void:
	print("\n=== Una partida con foco de area pasa a ejercicios ===")
	var e := Team.generar("Viejo", rng, 0)
	var datos: Dictionary = JSON.parse_string(JSON.stringify(e.guardar()))
	datos.erase("ejercicio_fisico")
	datos.erase("ejercicio_tactico")
	datos.erase("ejercicio_semanas")
	datos["foco_equipo"] = "defensivo"
	datos["foco_semanas"] = {"defensivo": 4.0}
	var vuelto := Team.cargar(datos)
	_ok(vuelto.ejercicio_fisico == "libre" and vuelto.ejercicio_tactico == "presion",
		"foco defensivo pasa a libre + presion.",
		"foco defensivo quedo %s + %s." % [vuelto.ejercicio_fisico, vuelto.ejercicio_tactico])


func _test_bonus_solo_del_elegido(rng: RandomNumberGenerator) -> void:
	print("\n=== El bonus del partido es del ejercicio puesto hoy ===")
	var e := Team.generar("Bonus", rng, 0)
	e.ejercicio_fisico = "rondo"
	e.ejercicio_tactico = "libre"
	var con := Entrenamiento.bonus_duelo(e, "pases")
	var ajeno := Entrenamiento.bonus_duelo(e, "tiros_libres")
	# Semanas de rondo acumuladas no sostienen el bonus: se cambia y se va.
	e.avanzar_dias(70)
	e.ejercicio_fisico = "libre"
	var despues := Entrenamiento.bonus_duelo(e, "pases")
	_ok(con == Entrenamiento.BONUS_DUELO and ajeno == 0.0 and despues == 0.0,
		"rondo suma %.1f en pases, nada en tiros libres, y nada al sacarlo." % con,
		"pases %.1f, tiros libres %.1f, pases sin rondo %.1f." % [con, ajeno, despues])


func _test_penal_es_una_situacion(rng: RandomNumberGenerator) -> void:
	print("\n=== Penales suma en el penal y no en cualquier remate ===")
	var e := Team.generar("Penal", rng, 0)
	e.ejercicio_fisico = "libre"
	e.ejercicio_tactico = "penales"
	var penal := Entrenamiento.bonus_duelo(e, "tiro", Entrenamiento.SITUACION_PENAL)
	var remate := Entrenamiento.bonus_duelo(e, "tiro")
	_ok(penal == Entrenamiento.BONUS_DUELO and remate == 0.0,
		"penal +%.1f, remate comun +0." % penal,
		"penal %.1f, remate comun %.1f." % [penal, remate])


func _test_correr_cansa_menos(rng: RandomNumberGenerator) -> void:
	print("\n=== Correr: el plantel se cansa menos en el partido ===")
	var a := Team.generar("Corre", rng, 0)
	var b := Team.generar("NoCorre", rng, 100)
	a.ejercicio_fisico = "correr"
	b.ejercicio_fisico = "libre"
	var ja: Dictionary = a.jugadores[5]
	var jb: Dictionary = b.jugadores[5]
	for _i in range(40):
		a.desgastar(ja["id"], 50)
		b.desgastar(jb["id"], 50)
	var gasto_a := 1.0 - a.resistencia_pct(ja["id"])
	var gasto_b := 1.0 - b.resistencia_pct(jb["id"])
	_ok(gasto_a < gasto_b,
		"con correr pierde %.3f de resistencia; sin correr, %.3f." % [gasto_a, gasto_b],
		"con correr %.3f, sin correr %.3f." % [gasto_a, gasto_b])


func _test_penales_suma_en_la_tanda(rng: RandomNumberGenerator) -> void:
	print("\n=== Penales suma en la tanda ===")
	var e := Team.generar("Tanda", rng, 0)
	var pateador: Dictionary = e.jugadores[10]
	var arquero := e.arquero()
	var sin := Penales._chance_gol(pateador, arquero)
	e.ejercicio_tactico = "penales"
	var con := Penales._chance_gol(pateador, arquero, Entrenamiento.bonus_tanda(e))
	_ok(con > sin, "la chance pasa de %.3f a %.3f." % [sin, con],
		"la chance no sube: %.3f contra %.3f." % [con, sin])
