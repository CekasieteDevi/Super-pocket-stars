extends SceneTree

## Banco de 7 y reservas: quien va al partido y quien no. Correr con:
## godot --headless --script tests/test_reservas.gd

const SEED := 6161

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_el_banco_no_pasa_de_siete(rng)
	_test_la_reserva_no_entra_al_partido(rng)
	_test_mover_entre_banco_y_reservas(rng)
	_test_la_reserva_no_cuenta_para_presentarse(rng)
	_test_la_emergencia_usa_reservas_antes_que_juveniles(rng)
	_test_sobreviven_al_guardado(rng)
	print("\nFALLOS=%d" % fallos)
	quit()


func _ok(t: String) -> void:
	print("OK: %s" % t)


func _falla(t: String) -> void:
	fallos += 1
	print("FALLA: %s" % t)


## Un club con `cuantos` jugadores de mas, todos en reservas.
func _con_reservas(rng: RandomNumberGenerator, cuantos: int, media: float = 60.0) -> Team:
	var t := Team.generar("ClubHondo", rng, 0)
	for i in range(cuantos):
		var j := PlayerGenerator.generate(50000 + i, rng, "MC", 70)
		j["media"] = media
		t.mover_a_banco(j)
		t._registrar_fichaje(j, ValorJugador.calcular(j, 50.0, 3))
	return t


func _test_el_banco_no_pasa_de_siete(rng: RandomNumberGenerator) -> void:
	print("=== El banco se queda en 7 y el resto va a reservas ===")
	var t := _con_reservas(rng, 5)
	if t.banco.size() == Team.max_suplentes() and t.reservas.size() == 5:
		_ok("banco %d, reservas %d, plantel %d." % [
			t.banco.size(), t.reservas.size(), t.todos_los_jugadores().size()])
	else:
		_falla("banco %d, reservas %d." % [t.banco.size(), t.reservas.size()])


func _test_la_reserva_no_entra_al_partido(rng: RandomNumberGenerator) -> void:
	print("\n=== Una reserva no entra por un cambio ni tapa a un titular ===")
	var t := _con_reservas(rng, 3, 99.0)
	# Media 99: si el motor la mirara, entraria siempre.
	var ids_reservas := []
	for j in t.reservas:
		ids_reservas.append(int(j["id"]))

	# Todo el banco afuera: no queda ningun suplente legitimo.
	for j in t.banco.duplicate():
		t.lesionar(int(j["id"]), "Desgarro", 30)

	var titular: Dictionary = t.jugadores[7]
	var reemplazo := Alineacion.reemplazo_para(t, titular, [])
	var entra_por_cambio = MatchEngine._mejor_suplente_para(t, str(titular["posicion"]))

	var ok: bool = reemplazo.is_empty() or not ids_reservas.has(int(reemplazo["id"]))
	ok = ok and (entra_por_cambio == null or not ids_reservas.has(int(entra_por_cambio["id"])))
	if ok:
		_ok("con el banco entero lesionado, las tres reservas de media 99 igual no juegan.")
	else:
		_falla("una reserva entro al partido: reemplazo=%s cambio=%s" % [reemplazo, entra_por_cambio])


func _test_mover_entre_banco_y_reservas(rng: RandomNumberGenerator) -> void:
	print("\n=== Subir y bajar entre banco y reservas ===")
	var t := _con_reservas(rng, 2)
	var id_reserva := int(t.reservas[0]["id"])

	# Con el banco lleno no se puede subir: hay que cambiarlo por alguien.
	var lleno := t.mover_entre_banco_y_reservas(id_reserva)
	if bool(lleno.get("exito", false)):
		_falla("subio al banco con los 7 suplentes puestos.")
		return

	var id_suplente := int(t.banco[3]["id"])
	var baja := t.mover_entre_banco_y_reservas(id_suplente)
	var sube := t.mover_entre_banco_y_reservas(id_reserva)
	var ok: bool = bool(baja.get("exito", false)) and bool(sube.get("exito", false))
	ok = ok and t.banco.size() == Team.max_suplentes()
	var en_banco := false
	for j in t.banco:
		if int(j["id"]) == id_reserva:
			en_banco = true
	ok = ok and en_banco

	# Un titular no baja de una: primero hay que sacarlo del once.
	var titular := t.mover_entre_banco_y_reservas(int(t.jugadores[0]["id"]))
	ok = ok and not bool(titular.get("exito", false))

	# Y el arrastre (intercambiar) cambia a dos, esten donde esten.
	var id_r2 := int(t.reservas[0]["id"])
	var id_s2 := int(t.banco[0]["id"])
	ok = ok and t.intercambiar(id_r2, id_s2)
	ok = ok and int(t.banco[0]["id"]) == id_r2 and int(t.reservas[0]["id"]) == id_s2

	if ok:
		_ok("baja uno, sube el otro, el titular no baja solo y el arrastre los cambia.")
	else:
		_falla("baja=%s sube=%s banco=%d titular=%s" % [baja, sube, t.banco.size(), titular])


func _test_la_reserva_no_cuenta_para_presentarse(rng: RandomNumberGenerator) -> void:
	print("\n=== Tener reservas no te salva de no llegar al minimo ===")
	var t := _con_reservas(rng, 6)
	# Cuatro titulares lesionados: 18 convocados - 4 = 14, bajo el minimo.
	for i in range(4):
		t.lesionar(int(t.jugadores[i]["id"]), "Desgarro grave", 40)
	var sanos := t.jugadores_sanos_count()
	if sanos < Liga.MINIMO_DISPONIBLES and t.reservas.size() == 6:
		_ok("%d sanos entre los convocados con 6 reservas sanas guardadas." % sanos)
	else:
		_falla("sanos %d con %d reservas: las reservas estan contando." % [sanos, t.reservas.size()])


func _test_la_emergencia_usa_reservas_antes_que_juveniles(rng: RandomNumberGenerator) -> void:
	print("\n=== La emergencia sube reservas antes que hacer debutar a un pibe ===")
	var t := _con_reservas(rng, 6)
	t.generar_camada(rng, 5)
	var cantera_antes := t.cantera.size()
	for i in range(4):
		t.lesionar(int(t.jugadores[i]["id"]), "Desgarro grave", 40)

	var r := t.ajustar_convocatorias_de_emergencia(Liga.MINIMO_DISPONIBLES)
	var ok: bool = t.jugadores_sanos_count() >= Liga.MINIMO_DISPONIBLES
	ok = ok and t.cantera.size() == cantera_antes  # ningun juvenil debuto
	ok = ok and not r["subidos"].is_empty()
	if ok:
		_ok("subieron %d reservas, la cantera quedo intacta y llega a %d disponibles." % [
			r["subidos"].size(), t.jugadores_sanos_count()])
	else:
		_falla("subidos %d, cantera %d -> %d, sanos %d." % [
			r["subidos"].size(), cantera_antes, t.cantera.size(), t.jugadores_sanos_count()])


func _test_sobreviven_al_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== Las reservas sobreviven a guardar y cargar ===")
	var t := _con_reservas(rng, 4)
	var vuelto := Team.cargar(JSON.parse_string(JSON.stringify(t.guardar())))
	var ok: bool = vuelto.reservas.size() == 4 and vuelto.banco.size() == Team.max_suplentes()
	ok = ok and vuelto.todos_los_jugadores().size() == t.todos_los_jugadores().size()

	# Una partida vieja traia todo el plantel en el banco: al cargar, lo
	# que pasa del tope baja a reservas.
	var datos: Dictionary = t.guardar()
	var banco_viejo: Array = datos["banco"].duplicate()
	banco_viejo.append_array(datos["reservas"])
	datos["banco"] = banco_viejo
	datos.erase("reservas")
	var migrado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))
	ok = ok and migrado.banco.size() == Team.max_suplentes() and migrado.reservas.size() == 4

	if ok:
		_ok("vuelven 4 reservas del JSON, y un banco viejo de 11 se parte en 7 + 4.")
	else:
		_falla("vuelto banco %d reservas %d, migrado banco %d reservas %d." % [
			vuelto.banco.size(), vuelto.reservas.size(),
			migrado.banco.size(), migrado.reservas.size()])
