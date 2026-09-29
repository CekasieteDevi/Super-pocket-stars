extends SceneTree

## Relatos de pérdidas y de jugadas menores: mal pase, control que se va,
## centro rechazado, regate con nombre, rebote del arquero. Y que el mismo
## evento se narre siempre igual (la variante sale del evento, no de un rng).


func _init() -> void:
	var nombres := {1: "MC Pérez", 2: "DFC Gómez", 3: "EXT Silva"}

	var corte := {"tipo": "pase", "resultado": "pierde", "minuto": 10, "clave": 2,
		"pasador_clave": 1, "corte": true, "rival": "Visita"}
	assert(RelatoPartido.importancia(corte) == RelatoPartido.MENOR)
	var texto_corte := RelatoPartido.linea(corte, nombres)
	assert(texto_corte.contains("MC Pérez") and texto_corte.contains("DFC Gómez"))
	assert(texto_corte == RelatoPartido.linea(corte, nombres))
	# Una pelota suelta cortada no tiene pasador: no se inventa un "mal pase".
	var suelta := {"tipo": "pase", "resultado": "pierde", "clave": 2, "pasador_clave": -1,
		"corte": true, "rival": "Visita"}
	assert(RelatoPartido.linea(suelta, nombres) == "La corta DFC Gómez (Visita)")
	var completo := {"tipo": "pase", "resultado": "avanza", "clave": 1}
	assert(RelatoPartido.importancia(completo) == RelatoPartido.NADA)

	var control := {"tipo": "control", "resultado": "se_le_va", "clave": 3, "minuto": 4}
	assert(RelatoPartido.importancia(control) == RelatoPartido.MENOR)
	assert(RelatoPartido.linea(control, nombres).contains("EXT Silva"))

	var centro := {"tipo": "centro", "resultado": "despeja", "clave": 2, "centrador_clave": 3, "minuto": 1}
	var texto_centro := RelatoPartido.linea(centro, nombres)
	assert(texto_centro.contains("de EXT Silva") and texto_centro.contains("DFC Gómez"))
	centro["centrador_clave"] = -1
	assert(not RelatoPartido.linea(centro, nombres).contains(" de "))

	var regate := {"tipo": "gambeta", "resultado": "pasa", "clave": 3, "defensor_clave": 2,
		"regate": "globito"}
	assert(RelatoPartido.importancia(regate) == RelatoPartido.MENOR)
	assert(RelatoPartido.linea(regate, nombres) == "¡Sombrerito de EXT Silva! Deja atrás a DFC Gómez")

	var autogol := {"tipo": "rebote_arquero", "resultado": "gol", "autogol": true, "equipo": "Casa"}
	assert(RelatoPartido.importancia(autogol) == RelatoPartido.MAXIMA)
	assert(RelatoPartido.linea(autogol, nombres).begins_with("¡GOL!"))
	var rebote := {"tipo": "rebote_arquero", "resultado": "control_atacante", "clave": 3}
	assert(RelatoPartido.linea(rebote, nombres).contains("EXT Silva"))
	var salida := {"tipo": "rebote_arquero", "resultado": "alto", "clave": 9}
	assert(RelatoPartido.importancia(salida) == RelatoPartido.NADA)
	print("OK: relatos de pérdidas, centros, regates y rebotes.")
	quit()
