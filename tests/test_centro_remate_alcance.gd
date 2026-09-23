extends SceneTree

## Un remate aereo tras un centro solo existe si el atacante llega a la
## pelota en el aire. Reportado el 2026-09-22: un centro le llegaba rodando
## a los pies y el delantero la metia de palomita.
const SEED := 9261
const PARTIDOS := 12
const AEREAS := ["palomita", "cabecea", "volea", "chilena"]

var fallos := 0


func _init() -> void:
	var aereos := 0
	var lejos := 0
	var dobles := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var partido_rng := RandomNumberGenerator.new()
		partido_rng.seed = SEED + 10000 + i
		var lista: Array = MotorEspacial.simular(casa, visita, partido_rng, true)["fotogramas"]
		for k in range(1, lista.size()):
			var f: Dictionary = lista[k]
			var por_clave := {}
			for a in f.get("acciones", []):
				var clave := int(a["clave"])
				por_clave[clave] = por_clave.get(clave, []) + [str(a["accion"])]
			for clave in por_clave:
				var acciones: Array = por_clave[clave]
				var aerea := ""
				for a in acciones:
					if a in AEREAS:
						aerea = a
				if aerea.is_empty():
					continue
				if "pecho" in acciones:
					dobles += 1
				# La pelota venia del aire: en el tick anterior no rodaba por el piso.
				var antes: Dictionary = lista[k - 1]["pelota"]
				if float(antes.get("z", 0.0)) > 0.0 or bool(antes.get("es_pase", false)):
					aereos += 1
					continue
				lejos += 1
				print("  rasa: partido=%d tick=%d accion=%s" % [i, k, aerea])
	_ok(aereos > 0, "hay remates aereos para medir (%d)" % aereos)
	_ok(lejos == 0, "ningun remate aereo a una pelota que llega rodando (%d)" % lejos)
	_ok(dobles == 0, "el remate aereo no se anota junto a un pecho (%d)" % dobles)
	print("FALLOS=%d" % fallos)
	quit()


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("OK: " + texto)
	else:
		fallos += 1
		print("FALLA: " + texto)
