class_name CanchitaV2
extends RefCounted

## Arma la canchita de la etapa 3 (CanchitaV2Nativa, docs/motor_v2.md) para
## el laboratorio, los tests y las mediciones: rondo 4 contra 2 o partidito 5
## contra 5, con jugadores distintos entre 45 y 85 de velocidad, aceleración,
## agilidad, pases y control, sacados de la semilla.


## `toque`: los de FisicaV2.parametros_toque() si viene vacío.
static func armar(modo: int, semilla: int, toque := {}) -> Object:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	c.configurar(FisicaV2.parametros(), FisicaV2.parametros_cuerpo(), FisicaV2.clips(),
		toque if not toque.is_empty() else FisicaV2.parametros_toque())
	var equipos := [4, 2] if modo == CanchitaV2Nativa.RONDO else [5, 5]
	for e in 2:
		for n in equipos[e]:
			var a := {}
			for clave in ["velocidad", "aceleracion", "agilidad", "pases", "control"]:
				a[clave] = rng.randf_range(45.0, 85.0)
			c.agregar(e, FisicaV2.jugador_de(a))
	c.empezar(modo, semilla)
	return c
