extends SceneTree

## Vuelca los 200 sponsors con sus requisitos y sus minimos calculados.
##
## Los numeros los calcula el codigo del juego, no se estiman a mano:
## Sponsors.pago_de, Sponsors.reputacion_minima y Fans.fans_para_apoyo.

const SALIDA := "user://tabla_sponsors.json"


func _init() -> void:
	var filas := []
	var catalogo := Sponsors.catalogo()
	for d in range(catalogo.size()):
		for s in catalogo[d]:
			var requisito := str(s["requisito"])
			var apoyo: float = float(Sponsors.MINIMO_APOYO.get(requisito, 0.0))
			filas.append({
				"nombre": str(s["nombre"]),
				"division": d + 1,
				"requisito": requisito,
				"deportivo": str(Sponsors.TEXTO_REQUISITO.get(requisito, "")),
				"factor": float(s["factor"]),
				"pago": Sponsors.pago_de(requisito, float(s["factor"]), d),
				"reputacion_minima": Sponsors.reputacion_minima(requisito, d),
				"apoyo_minimo": apoyo,
				"hinchada_minima": Fans.fans_para_apoyo(apoyo, d),
			})

	var referencias := []
	for d in range(catalogo.size()):
		referencias.append({
			"division": d + 1,
			"reputacion_referencia": Reputacion.referencia(d),
			"hinchada_referencia": Fans.referencia(d),
			"hinchada_inicial": Fans.inicial(d),
		})

	var f := FileAccess.open(SALIDA, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"sponsors": filas,
		"referencias": referencias,
		"escalones": Sponsors.MINIMO_REPUTACION.keys(),
	}))
	f.close()
	print("escrito en %s (%d sponsors)" % [ProjectSettings.globalize_path(SALIDA), filas.size()])
	quit()
