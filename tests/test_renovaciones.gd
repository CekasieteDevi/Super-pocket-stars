extends SceneTree

## Club > Renovaciones (core/renovaciones.gd): el contrato del club del
## jugador humano dejo de renovarse solo, y retenerlo es una negociacion
## de ida y vuelta.
##
## Antes, al equipo protegido se le renovaba TODO en el cierre, por 2 a 4
## años al azar y con el sueldo recalculado al valor de hoy. La masa
## salarial subia sola todas las temporadas contra un ingreso que tiene
## techo duro (el aforo clampea a 1.0), y el club no tenia forma de decir
## que no. Poder dejar ir a un veterano caro es el freno que faltaba.
##
## Correr con: godot --headless --script tests/test_renovaciones.gd

const SEED := 909

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_solo_muestra_los_que_se_vencen(rng)
	_test_el_contrato_largo_le_baja_el_sueldo_al_veterano(rng)
	_test_acepta_lo_que_pide(rng)
	_test_contraoferta_cede_ronda_a_ronda(rng)
	_test_termina_firmando_por_menos(rng)
	_test_la_oferta_insultante_lo_bloquea(rng)
	_test_el_bloqueo_se_va_con_los_dias(rng)
	_test_sin_presupuesto_no_se_firma(rng)
	_test_sin_renovar_se_va_libre(rng)

	print("\nFALLOS=%d" % fallos)
	quit()


func _verificar(condicion: bool, ok: String, falla: String) -> void:
	if condicion:
		print("OK: %s" % ok)
	else:
		print("FALLA: %s" % falla)
		fallos += 1


## Un club con plata de sobra y un jugador con el contrato por vencer.
func _armar(rng: RandomNumberGenerator, semilla: int) -> Array:
	var equipo := Team.generar("ClubR%d" % semilla, rng, semilla)
	equipo.caja["contratos"] = 10000000.0
	var jugador: Dictionary = equipo.jugadores[0]
	equipo.contratos[jugador["id"]] = 1
	return [equipo, jugador]


func _test_solo_muestra_los_que_se_vencen(rng: RandomNumberGenerator) -> void:
	print("=== pendientes(): solo un año o menos de contrato ===")
	var equipo := Team.generar("ClubP", rng, 100)
	for id in equipo.contratos:
		equipo.contratos[id] = 4

	var vacio := Renovaciones.pendientes(equipo).size()

	var elegidos := []
	var i := 0
	for id in equipo.contratos:
		if i < 3:
			equipo.contratos[id] = 1
			elegidos.append(id)
		i += 1

	var ids := []
	for j in Renovaciones.pendientes(equipo):
		ids.append(int(j["id"]))
	elegidos.sort()
	ids.sort()

	_verificar(vacio == 0 and ids == elegidos,
		"con los contratos largos la lista esta vacia, y aparecen los 3 que quedan en un año.",
		"vacio=%d esperados=%s obtenidos=%s" % [vacio, elegidos, ids])


func _test_el_contrato_largo_le_baja_el_sueldo_al_veterano(rng: RandomNumberGenerator) -> void:
	print("\n=== Los años mueven lo que pide, y para cada lado ===")
	var equipo := Team.generar("ClubV", rng, 200)

	var veterano: Dictionary = equipo.jugadores[0]
	veterano["edad"] = 33
	var joven: Dictionary = equipo.jugadores[1]
	joven["edad"] = 22

	var vet_corto := Renovaciones.sueldo_pretendido(equipo, veterano, 2)
	var vet_largo := Renovaciones.sueldo_pretendido(equipo, veterano, 5)
	var jov_corto := Renovaciones.sueldo_pretendido(equipo, joven, 2)
	var jov_largo := Renovaciones.sueldo_pretendido(equipo, joven, 5)

	_verificar(vet_largo < vet_corto and jov_largo > jov_corto,
		"al veterano el contrato largo le baja el sueldo (%s -> %s) y al joven se lo sube (%s -> %s)." % [
			Economia.formato_dinero(vet_corto), Economia.formato_dinero(vet_largo),
			Economia.formato_dinero(jov_corto), Economia.formato_dinero(jov_largo)],
		"veterano %.0f->%.0f joven %.0f->%.0f" % [vet_corto, vet_largo, jov_corto, jov_largo])


func _test_acepta_lo_que_pide(rng: RandomNumberGenerator) -> void:
	print("\n=== Le ofreces lo que pide y firma, cobrando la diferencia a Contratos ===")
	var armado := _armar(rng, 300)
	var equipo: Team = armado[0]
	var jugador: Dictionary = armado[1]
	var id: int = jugador["id"]

	var cobraba: float = equipo.sueldos[id]
	var caja_antes: float = equipo.caja["contratos"]
	var pide := Renovaciones.pide_ahora(equipo, jugador, 3)

	var r := Renovaciones.ofrecer(equipo, jugador, 3, pide)
	var firma := Renovaciones.firmar(equipo, jugador, 3, pide)
	var gastado: float = caja_antes - equipo.caja["contratos"]

	_verificar(str(r["respuesta"]) == "acepta"
			and bool(firma.get("exito", false))
			and is_equal_approx(gastado, pide - cobraba)
			and equipo.contratos[id] == 3
			and is_equal_approx(equipo.sueldos[id], pide)
			and not equipo.renovaciones.has(id),
		"firmo por 3 años a %s y a Contratos le salio %s, la diferencia con lo que ya cobraba." % [
			Economia.formato_dinero(pide), Economia.formato_dinero(gastado)],
		"r=%s firma=%s gastado=%.2f esperado=%.2f" % [r, firma, gastado, pide - cobraba])


func _test_contraoferta_cede_ronda_a_ronda(rng: RandomNumberGenerator) -> void:
	print("\n=== Contraoferta: cede parte de la brecha en cada ronda ===")
	var armado := _armar(rng, 400)
	var equipo: Team = armado[0]
	var jugador: Dictionary = armado[1]

	var pide_inicial := Renovaciones.pide_ahora(equipo, jugador, 2)
	# 85%: arriba del insulto (75%) y abajo de la tolerancia.
	var oferta: float = pide_inicial * 0.85

	var r1 := Renovaciones.ofrecer(equipo, jugador, 2, oferta)
	var pide_r1: float = float(r1["pide"])
	var r2 := Renovaciones.ofrecer(equipo, jugador, 2, oferta)
	var pide_r2: float = float(r2["pide"])

	_verificar(str(r1["respuesta"]) == "contraoferta"
			and str(r2["respuesta"]) == "contraoferta"
			and pide_r1 < pide_inicial and pide_r2 < pide_r1
			and Renovaciones.ronda(equipo, jugador["id"]) == 2,
		"pedia %s, bajo a %s y despues a %s sin que subieras la oferta." % [
			Economia.formato_dinero(pide_inicial), Economia.formato_dinero(pide_r1),
			Economia.formato_dinero(pide_r2)],
		"r1=%s r2=%s" % [r1, r2])


func _test_termina_firmando_por_menos(rng: RandomNumberGenerator) -> void:
	print("\n=== El ida y vuelta termina en acuerdo, y por menos de lo que pedia ===")
	var armado := _armar(rng, 500)
	var equipo: Team = armado[0]
	var jugador: Dictionary = armado[1]

	var pide_inicial := Renovaciones.pide_ahora(equipo, jugador, 2)
	var oferta: float = pide_inicial * 0.85

	var rondas := 0
	var respuesta := "contraoferta"
	while respuesta == "contraoferta" and rondas < 20:
		var r := Renovaciones.ofrecer(equipo, jugador, 2, oferta)
		respuesta = str(r["respuesta"])
		rondas += 1
	# Nunca puede quedar dando vueltas: o cierra o lo termina el.
	var termino: bool = respuesta != "contraoferta"

	# El piso existe para que la paciencia no lo regale: si la oferta
	# queda por debajo de PISO_DE_CESION nunca cierra, y eso esta bien.
	var piso: float = pide_inicial * Renovaciones.PISO_DE_CESION
	var deberia_cerrar: bool = oferta >= piso * Renovaciones.TOLERANCIA

	_verificar(termino and deberia_cerrar == (respuesta == "acepta")
			and rondas <= Renovaciones.RONDAS_MAX + 1,
		"con %s sobre un pedido de %s termino en %d rondas con \"%s\" (piso %s)." % [
			Economia.formato_dinero(oferta), Economia.formato_dinero(pide_inicial),
			rondas, respuesta, Economia.formato_dinero(piso)],
		"respuesta=%s rondas=%d oferta=%.0f piso=%.0f" % [respuesta, rondas, oferta, piso])


func _test_la_oferta_insultante_lo_bloquea(rng: RandomNumberGenerator) -> void:
	print("\n=== Una oferta muy por debajo lo ofende y corta la negociacion ===")
	var armado := _armar(rng, 600)
	var equipo: Team = armado[0]
	var jugador: Dictionary = armado[1]
	var id: int = jugador["id"]

	var pide := Renovaciones.pide_ahora(equipo, jugador, 3)
	var insulto: float = pide * (Renovaciones.FRACCION_INSULTO - 0.05)

	var r := Renovaciones.ofrecer(equipo, jugador, 3, insulto)
	# Y despues del enojo no atiende ni una oferta buena.
	var r2 := Renovaciones.ofrecer(equipo, jugador, 3, pide * 2.0)
	var firma := Renovaciones.firmar(equipo, jugador, 3, pide * 2.0)

	_verificar(str(r["respuesta"]) == "insulto"
			and Renovaciones.dias_bloqueado(equipo, id) == Renovaciones.DIAS_BLOQUEO
			and str(r2["respuesta"]) == "bloqueado"
			and not bool(firma.get("exito", false)),
		"le ofreciste el %.0f%% de lo que pedia, se ofendio y no atiende por %d dias ni pagando el doble." % [
			(insulto / pide) * 100.0, Renovaciones.DIAS_BLOQUEO],
		"r=%s r2=%s bloqueo=%d" % [r, r2, Renovaciones.dias_bloqueado(equipo, id)])


func _test_el_bloqueo_se_va_con_los_dias(rng: RandomNumberGenerator) -> void:
	print("\n=== El enojo se le pasa con el calendario ===")
	var armado := _armar(rng, 700)
	var equipo: Team = armado[0]
	var jugador: Dictionary = armado[1]
	var id: int = jugador["id"]

	var pide := Renovaciones.pide_ahora(equipo, jugador, 3)
	Renovaciones.ofrecer(equipo, jugador, 3, pide * 0.5)
	var al_ofender := Renovaciones.dias_bloqueado(equipo, id)

	equipo.avanzar_dias(int(Renovaciones.DIAS_BLOQUEO / 2.0))
	var a_mitad := Renovaciones.dias_bloqueado(equipo, id)
	equipo.avanzar_dias(Renovaciones.DIAS_BLOQUEO)
	var despues := Renovaciones.dias_bloqueado(equipo, id)

	# Y al volver a atender, arranca de cero: vuelve a pedir lo de tabla.
	var pide_despues := Renovaciones.pide_ahora(equipo, jugador, 3)
	var r := Renovaciones.ofrecer(equipo, jugador, 3, pide_despues)

	_verificar(al_ofender == Renovaciones.DIAS_BLOQUEO
			and a_mitad > 0 and a_mitad < al_ofender
			and despues == 0 and str(r["respuesta"]) == "acepta",
		"bloqueo %d -> %d -> %d dias, y al volver a atender acepta lo que pide." % [
			al_ofender, a_mitad, despues],
		"al_ofender=%d a_mitad=%d despues=%d r=%s" % [al_ofender, a_mitad, despues, r])


func _test_sin_presupuesto_no_se_firma(rng: RandomNumberGenerator) -> void:
	print("\n=== Sin presupuesto de Contratos no se firma ===")
	var armado := _armar(rng, 800)
	var equipo: Team = armado[0]
	var jugador: Dictionary = armado[1]
	var id: int = jugador["id"]
	equipo.caja["contratos"] = 0.0

	var cobraba: float = equipo.sueldos[id]
	var pide := Renovaciones.pide_ahora(equipo, jugador, 3)
	var firma := Renovaciones.firmar(equipo, jugador, 3, pide)

	_verificar(not bool(firma.get("exito", false))
			and is_equal_approx(equipo.sueldos[id], cobraba)
			and equipo.contratos[id] == 1,
		"acepto pero no se pudo firmar, y no se toco ni el sueldo ni el contrato.",
		"firma=%s sueldo=%.2f contrato=%d" % [firma, equipo.sueldos[id], equipo.contratos[id]])


func _test_sin_renovar_se_va_libre(rng: RandomNumberGenerator) -> void:
	print("\n=== Al club del jugador humano tambien se le vencen los contratos ===")
	var liga := Liga.new()
	liga.inicializar(["Protegido", "Rival"], rng, 500)
	var protegido: Team = liga.equipos[0]
	for id in protegido.contratos:
		protegido.contratos[id] = 5

	var jugador: Dictionary = protegido.jugadores[0]
	var id: int = jugador["id"]
	protegido.contratos[id] = 1

	var aparece := false
	for j in Renovaciones.pendientes(protegido):
		if int(j["id"]) == id:
			aparece = true

	var cuantos_antes: int = protegido.todos_los_jugadores().size()
	var ids_antes := {}
	for j in protegido.todos_los_jugadores():
		ids_antes[int(j["id"])] = true
	liga._avanzar_contratos(protegido, rng, true)

	# El plantel queda con UNO MENOS y no aparece nadie nuevo: al club del
	# jugador ya no se le inventa un reemplazo (ver
	# AgentesLibres._dejar_hueco). Este club nace sin cantera, asi que el
	# puesto lo tapa el banco y el hueco queda ahi.
	var nadie_nuevo := true
	for j in protegido.todos_los_jugadores():
		if not ids_antes.has(int(j["id"])):
			nadie_nuevo = false

	_verificar(aparece
			and not protegido.contratos.has(id)
			and not protegido.sueldos.has(id)
			and nadie_nuevo
			and protegido.todos_los_jugadores().size() == cuantos_antes - 1,
		"aparecio en Renovaciones, no se renovo, se fue libre y el plantel quedo con uno menos sin inventar a nadie.",
		"aparece=%s sigue=%s nadie_nuevo=%s plantel %d->%d" % [
			aparece, protegido.contratos.has(id), nadie_nuevo,
			cuantos_antes, protegido.todos_los_jugadores().size()])
