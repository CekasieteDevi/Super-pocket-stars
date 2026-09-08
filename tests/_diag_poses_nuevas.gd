extends SceneTree

## Cuenta cuantas veces sale cada accion animada a lo largo de varios
## partidos. Sirve para verificar que las poses nuevas (cabezazo, festejo)
## se disparan de verdad: una pose que el motor nunca emite es un sprite
## que nadie ve nunca.

const SEMILLA := 20260908
const PARTIDOS := 20


func _init() -> void:
	var conteo := {}
	var goles := 0
	var numeros := {}
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEMILLA + i
		var local := Team.generar("Local %d" % i, rng)
		var visita := Team.generar("Visita %d" % i, rng, 1000)
		var r := MotorEspacial.simular(local, visita, rng, true)
		goles += int(r["goles_local"]) + int(r["goles_visitante"])
		for f in r["fotogramas"]:
			for a in f.get("acciones", []):
				conteo[a["accion"]] = int(conteo.get(a["accion"], 0)) + 1
		# El dorsal tiene que llegar al fotograma: si sale 0 el sprite no
		# estampa nada y el numero de camiseta no existe en pantalla.
		for j in r["fotogramas"][0]["jugadores"]:
			numeros[int(j.get("numero", 0))] = true

	print("partidos: %d, goles: %d" % [PARTIDOS, goles])
	for k in conteo:
		print("  %s: %d" % [k, conteo[k]])
	var lista := numeros.keys()
	lista.sort()
	print("  dorsales vistos: %s" % str(lista))
	quit()
