extends SceneTree

## §9.3 rework: negociar con el club y despues con el jugador.

const SEED := 6060


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_el_club_pide_mas_de_lo_que_vale(rng)
	_test_una_oferta_justa_se_acepta(rng)
	_test_una_miseria_te_bloquea(rng)
	_test_el_bloqueo_caduca(rng)
	_test_nadie_baja_de_categoria_por_gusto(rng)
	_test_la_plata_compra_las_ganas(rng)
	_test_el_que_la_esta_pasando_mal_se_quiere_ir(rng)
	_test_hincha_y_mercenario(rng)
	_test_guardado_del_bloqueo(rng)
	quit()


func _test_el_club_pide_mas_de_lo_que_vale(rng: RandomNumberGenerator) -> void:
	print("=== El club pide mas que el valor de mercado ===")
	# Lo que pide = valor + lo que le duele soltarlo. Si pidiera justo el
	# valor, comprar seria una calculadora y no una negociacion.
	var club := Team.generar("Vendedor", rng, 0)
	var j: Dictionary = club.jugadores[9]
	var valor := ValorJugador.calcular(j, club.animo.get(j["id"], 50.0), club.contratos.get(j["id"], 3))
	var pedido := Negociacion.precio_pedido(club, j)
	if pedido > valor:
		print("OK: vale %s y piden %s (+%.0f%%)." % [
			Economia.formato_dinero(valor), Economia.formato_dinero(pedido),
			(pedido / valor - 1.0) * 100.0])
	else:
		print("FALLA: piden %s por algo que vale %s." % [pedido, valor])


func _test_una_oferta_justa_se_acepta(rng: RandomNumberGenerator) -> void:
	print("\n=== Pagando lo que piden, aceptan ===")
	var club := Team.generar("Vendedor2", rng, 0)
	var j: Dictionary = club.jugadores[5]
	var pedido := Negociacion.precio_pedido(club, j)
	var r := Negociacion.evaluar_oferta(club, j, pedido)
	var r_corta := Negociacion.evaluar_oferta(club, j, pedido * 0.8)
	if r["acepta"] and not r_corta["acepta"] and not r_corta["insulto"]:
		print("OK: %s acepta; el 80%% no alcanza pero tampoco ofende." % Economia.formato_dinero(pedido))
	else:
		print("FALLA: justa=%s corta=%s" % [r, r_corta])


func _test_una_miseria_te_bloquea(rng: RandomNumberGenerator) -> void:
	print("\n=== Ofertar una miseria te cierra la puerta ===")
	# Este es el castigo por no investigar: si no sabes cuanto vale, podes
	# tirar un numero que ofenda y perder al jugador por una temporada.
	var club := Team.generar("Vendedor3", rng, 0)
	var j: Dictionary = club.jugadores[3]
	var id := int(j["id"])
	var pedido := Negociacion.precio_pedido(club, j)
	var r := Negociacion.evaluar_oferta(club, j, pedido * 0.2)
	if not r["insulto"]:
		print("FALLA: el 20%% del precio no se tomo como insulto.")
		return
	Negociacion.bloquear(club, id, 3)
	if Negociacion.bloqueado(club, id, 3):
		print("OK: 20% del precio = insulto, y queda vetado la temporada 3.")
	else:
		print("FALLA: no quedo bloqueado.")


func _test_el_bloqueo_caduca(rng: RandomNumberGenerator) -> void:
	print("\n=== El bloqueo dura y despues se levanta ===")
	var club := Team.generar("Vendedor4", rng, 0)
	var id: int = int(club.jugadores[0]["id"])
	Negociacion.bloquear(club, id, 5)
	var durante := Negociacion.bloqueado(club, id, 5)
	var despues := Negociacion.bloqueado(club, id, 6)
	if durante and not despues:
		print("OK: vetado en la 5, libre en la 6.")
	else:
		print("FALLA: durante=%s despues=%s" % [durante, despues])


func _test_nadie_baja_de_categoria_por_gusto(rng: RandomNumberGenerator) -> void:
	print("\n=== Un jugador de primera no se va a decima por el mismo sueldo ===")
	var club := Team.generar("Grande", rng, 0)
	var j: Dictionary = club.jugadores[7]
	var r := Negociacion.interes_jugador(j, 60.0, 100000.0, 100000.0, 0, 9)
	if not r["acepta"]:
		print("OK: interes %.2f, no acepta. Motivo: %s" % [r["interes"], Negociacion.motivo_rechazo(r)])
	else:
		print("FALLA: acepto irse de primera a decima sin mejora (%.2f)." % r["interes"])


func _test_la_plata_compra_las_ganas(rng: RandomNumberGenerator) -> void:
	print("\n=== ...pero con un contrato jugoso si ===")
	var club := Team.generar("Grande2", rng, 0)
	var j: Dictionary = club.jugadores[7]
	var pobre := Negociacion.interes_jugador(j, 60.0, 100000.0, 100000.0, 0, 9)
	var rico := Negociacion.interes_jugador(j, 60.0, 100000.0, 600000.0, 0, 9)
	if not pobre["acepta"] and rico["acepta"]:
		print("OK: al mismo sueldo %.2f (no), sextuplicandolo %.2f (si)." % [
			pobre["interes"], rico["interes"]])
	else:
		print("FALLA: pobre=%.2f rico=%.2f" % [pobre["interes"], rico["interes"]])


func _test_el_que_la_esta_pasando_mal_se_quiere_ir(rng: RandomNumberGenerator) -> void:
	print("\n=== El que la esta pasando mal se quiere ir ===")
	var club := Team.generar("Grande3", rng, 0)
	var j: Dictionary = club.jugadores[7]
	var comodo := Negociacion.interes_jugador(j, 80.0, 100000.0, 110000.0, 0, 3)
	var amargado := Negociacion.interes_jugador(j, 5.0, 100000.0, 110000.0, 0, 3)
	if amargado["interes"] > comodo["interes"] and amargado["acepta"]:
		print("OK: con animo 80 da %.2f y con animo 5 da %.2f." % [
			comodo["interes"], amargado["interes"]])
	else:
		print("FALLA: comodo=%.2f amargado=%.2f" % [comodo["interes"], amargado["interes"]])


func _test_hincha_y_mercenario(rng: RandomNumberGenerator) -> void:
	print("\n=== Hincha del club y Mercenario cambian la cuenta ===")
	var club := Team.generar("Grande4", rng, 0)
	var base: Dictionary = club.jugadores[7].duplicate(true)
	base["personalidades"] = {}
	var hincha: Dictionary = base.duplicate(true)
	hincha["personalidades"] = {"positiva": "Hincha del club", "negativa": ""}
	var merc: Dictionary = base.duplicate(true)
	merc["personalidades"] = {"positiva": "", "negativa": "Mercenario"}

	# Bajar tres divisiones con el doble de sueldo.
	var r_base := Negociacion.interes_jugador(base, 50.0, 100000.0, 200000.0, 0, 3)
	var r_hincha := Negociacion.interes_jugador(hincha, 50.0, 100000.0, 200000.0, 0, 3)
	var r_merc := Negociacion.interes_jugador(merc, 50.0, 100000.0, 200000.0, 0, 3)
	if r_hincha["interes"] < r_base["interes"] and r_merc["interes"] > r_base["interes"]:
		print("OK: normal %.2f, hincha %.2f (menos), mercenario %.2f (mas)." % [
			r_base["interes"], r_hincha["interes"], r_merc["interes"]])
	else:
		print("FALLA: base=%.2f hincha=%.2f merc=%.2f" % [
			r_base["interes"], r_hincha["interes"], r_merc["interes"]])


func _test_guardado_del_bloqueo(rng: RandomNumberGenerator) -> void:
	print("\n=== Los bloqueos sobreviven al guardado ===")
	var club := Team.generar("Vendedor5", rng, 0)
	var id: int = int(club.jugadores[2]["id"])
	Negociacion.bloquear(club, id, 7)
	var vuelto := Team.cargar(JSON.parse_string(JSON.stringify(club.guardar())))
	if Negociacion.bloqueado(vuelto, id, 7):
		print("OK: el veto sigue puesto despues de guardar y cargar.")
	else:
		print("FALLA: se perdio el veto (%s)." % [vuelto.bloqueos_mercado])
