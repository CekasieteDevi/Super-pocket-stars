extends SceneTree

## El presupuesto de Contratos tiene que moverse con la planilla salarial:
## el que llega lo consume, el que se va lo devuelve. Antes no se tocaba
## nunca y podias comprar toda la temporada sin gastar un peso de ahi.
const SEED := 12345


func _sueldos_totales(equipo: Team) -> float:
	var total := 0.0
	for id in equipo.sueldos:
		total += equipo.sueldos[id]
	return total


func _init() -> void:
	var fallos := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var comprador := Team.generar("Comprador", rng, 0)
	var vendedor := Team.generar("Vendedor", rng, 500)
	for equipo in [comprador, vendedor]:
		equipo.caja["fichajes"] = 5000000.0
		equipo.caja["contratos"] = 1000000.0

	var id: int = vendedor.jugadores[0]["id"]
	var contratos_antes: float = comprador.caja["contratos"]
	var planilla_antes := _sueldos_totales(comprador)
	var resultado := Mercado.comprar_al_contado(comprador, vendedor, id, rng, true)

	if not resultado["exito"]:
		print("FALLA: la compra no se concreto: ", resultado["motivo"])
		fallos += 1
	else:
		# La caja de Contratos baja exactamente lo que subio la planilla:
		# el fichado empieza a cobrar y el que sale deja de cobrar.
		var gastado: float = contratos_antes - comprador.caja["contratos"]
		var subio_planilla: float = _sueldos_totales(comprador) - planilla_antes
		if absf(gastado - subio_planilla) > 0.01:
			print("FALLA: Contratos se movio %f pero la planilla %f" % [gastado, subio_planilla])
			fallos += 1
		else:
			print("OK: Contratos sigue a la planilla (%f)" % gastado)
		if not comprador.sueldos.has(id):
			print("FALLA: el fichado no quedo en la planilla del comprador")
			fallos += 1
		else:
			print("OK: el fichado cobra en el comprador")

	print("FALLOS=%d" % fallos)
	quit()
