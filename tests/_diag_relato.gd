extends SceneTree

## Recorre un partido y muestra el relato que veria el usuario. Sirve
## para chequear que los eventos traen la clave (o sea, apellidos reales
## y no roles sueltos) y que las tarjetas no se pierden.

const SEMILLA := 20260818


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	var local := Team.generar("Atletico Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var r := MotorEspacial.simular(local, visita, rng, true)
	var nombres := VistaPartido.construir_nombres(local, visita)

	var lineas := 0
	var sin_nombre := 0
	var tarjetas := 0
	var por_peso := {}
	for f in r["fotogramas"]:
		var mejor = null
		var peso := RelatoPartido.NADA
		for ev in f.get("eventos", []):
			if str(ev.get("tipo", "")) == "tarjeta":
				tarjetas += 1
			var p := RelatoPartido.importancia(ev)
			if p > peso:
				peso = p
				mejor = ev
		if mejor == null:
			continue
		var e: Dictionary = mejor
		if not e.has("clave") and e.has("jugador_id"):
			e = e.duplicate()
			e["clave"] = MotorEspacial.clave_de(int(e["jugador_id"]),
				str(e.get("equipo", "")) == local.nombre)
		var texto := RelatoPartido.linea(e, nombres)
		if texto == "":
			continue
		lineas += 1
		por_peso[peso] = int(por_peso.get(peso, 0)) + 1
		if not e.has("clave") or not nombres.has(int(e["clave"])):
			sin_nombre += 1
		if lineas <= 14:
			print("  %s" % texto)
	print("lineas de relato: %d (una cada %.0f fotogramas)" % [
		lineas, float(r["fotogramas"].size()) / maxf(lineas, 1)])
	print("  sin apellido (cae al rol): %d" % sin_nombre)
	print("  tarjetas en fotogramas: %d" % tarjetas)
	print("  por importancia: %s" % [por_peso])
	quit()
