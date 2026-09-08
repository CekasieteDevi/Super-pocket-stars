extends SceneTree

## Dorsales (numero de camiseta): reparto inicial, intercambio al elegir
## uno ocupado, y que sobrevivan al guardado. El intercambio es lo unico
## que no se ve solo: al que le sacan el numero se queda con el viejo, no
## sin numero.

const SEED := 7


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var e := Team.generar("Prueba", rng)
	var fallos := 0
	var x := int(e.jugadores[0]["id"])   # dorsal 1
	var y := int(e.jugadores[9]["id"])   # dorsal 10
	if e.dorsal_de(x) != 1 or e.dorsal_de(y) != 10:
		print("FALLA: reparto inicial"); fallos += 1
	e.asignar_dorsal(x, 10)
	if e.dorsal_de(x) != 10 or e.dorsal_de(y) != 1:
		print("FALLA: intercambio %d/%d" % [e.dorsal_de(x), e.dorsal_de(y)]); fallos += 1
	# numero libre: nadie mas lo toca
	e.asignar_dorsal(x, 77)
	if e.dorsal_de(x) != 77 or e.dorsal_de(y) != 1:
		print("FALLA: numero libre"); fallos += 1
	if e.asignar_dorsal(x, 0) or e.asignar_dorsal(x, 100):
		print("FALLA: acepta fuera de rango"); fallos += 1
	if e.dorsal_de(x) != 77:
		print("FALLA: rango invalido movio el dorsal"); fallos += 1
	# sobrevive al guardado
	var t2 := Team.cargar(JSON.parse_string(JSON.stringify(e.guardar())))
	if t2.dorsal_de(x) != 77:
		print("FALLA: no sobrevive el guardado (%d)" % t2.dorsal_de(x)); fallos += 1
	# el que se va libera el numero, el que entra toma el mas chico
	var libre_antes := e.jugador_con_dorsal(1)
	e.jugadores.remove_at(0)
	if e.dorsal_de(x) != 0 or e.jugador_con_dorsal(77) != 0:
		print("FALLA: no libera el numero del que se fue"); fallos += 1
	if e.jugador_con_dorsal(1) != libre_antes:
		print("FALLA: se movio el dorsal de otro"); fallos += 1
	# todos distintos
	var vistos := {}
	for j in e.todos_los_jugadores():
		var d := e.dorsal_de(int(j["id"]))
		if d < 1 or d > Team.DORSAL_MAXIMO or vistos.has(d):
			print("FALLA: dorsal repetido o fuera de rango %d" % d); fallos += 1
		vistos[d] = true
	print("OK: dorsales unicos, intercambio y guardado")
	print("FALLOS=%d" % fallos)
	quit()
