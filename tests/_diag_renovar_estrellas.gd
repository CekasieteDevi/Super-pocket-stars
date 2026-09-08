extends SceneTree

## ¿Le da la plata a un club de division 8, 9 o 10 para renovarle a sus
## mejores jugadores?
##
## Mide el presupuesto de Contratos que deja el cierre de temporada contra
## la DIFERENCIA de sueldo que cuesta renovar (Renovaciones.firmar cobra
## sueldo nuevo - sueldo viejo). Prueba dos precios: lo que el jugador
## pide de entrada y el piso al que baja negociando (PISO_DE_CESION).

const SEED := 777
const ANIOS_OFERTA := 3
const CUANTOS_MEJORES := 3


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)

	print("SEED=%d  oferta=%d anios  mejores=%d" % [SEED, ANIOS_OFERTA, CUANTOS_MEJORES])
	print("")
	print("div | presup.contratos | costo mejor (pide) | (piso) | costo top3 (pide) | (piso) | clubes que pagan mejor | top3")
	for d in range(7, 10):
		var liga: Liga = piramide.divisiones[d]
		var n: int = liga.equipos.size()
		var suma_presup := 0.0
		var suma_uno := 0.0
		var suma_uno_piso := 0.0
		var suma_tres := 0.0
		var suma_tres_piso := 0.0
		var pagan_uno := 0
		var pagan_uno_piso := 0
		var pagan_tres := 0
		var pagan_tres_piso := 0
		for i in range(n):
			var e: Team = liga.equipos[i]
			Economia.procesar_temporada(e, i + 1, n, d)
			var presup: float = e.caja.get("contratos", 0.0)
			suma_presup += presup

			var mejores := _mejores(e, CUANTOS_MEJORES)
			var costo_uno := 0.0
			var costo_uno_piso := 0.0
			var costo_tres := 0.0
			var costo_tres_piso := 0.0
			for k in range(mejores.size()):
				var j: Dictionary = mejores[k]
				var pide := Renovaciones.sueldo_pretendido(e, j, ANIOS_OFERTA)
				var viejo: float = float(e.sueldos.get(int(j["id"]), 0.0))
				var dif: float = maxf(0.0, pide - viejo)
				var dif_piso: float = maxf(0.0, pide * Renovaciones.PISO_DE_CESION - viejo)
				if k == 0:
					costo_uno = dif
					costo_uno_piso = dif_piso
				costo_tres += dif
				costo_tres_piso += dif_piso
			suma_uno += costo_uno
			suma_uno_piso += costo_uno_piso
			suma_tres += costo_tres
			suma_tres_piso += costo_tres_piso
			if presup >= costo_uno:
				pagan_uno += 1
			if presup >= costo_uno_piso:
				pagan_uno_piso += 1
			if presup >= costo_tres:
				pagan_tres += 1
			if presup >= costo_tres_piso:
				pagan_tres_piso += 1

		print("%3d | %16s | %18s | %6s | %17s | %6s | %2d/%d (piso %2d/%d) | %2d/%d (piso %2d/%d)" % [
			d + 1,
			Economia.formato_dinero(suma_presup / n),
			Economia.formato_dinero(suma_uno / n),
			Economia.formato_dinero(suma_uno_piso / n),
			Economia.formato_dinero(suma_tres / n),
			Economia.formato_dinero(suma_tres_piso / n),
			pagan_uno, n, pagan_uno_piso, n,
			pagan_tres, n, pagan_tres_piso, n])

	print("")
	print("Detalle: division 10, cinco clubes de muestra (posicion de tabla = indice+1)")
	var liga10: Liga = piramide.divisiones[9]
	for i in [0, 4, 9, 14, 19]:
		var e: Team = liga10.equipos[i]
		var presup: float = e.caja.get("contratos", 0.0)
		var mejores := _mejores(e, CUANTOS_MEJORES)
		var j: Dictionary = mejores[0]
		var pide := Renovaciones.sueldo_pretendido(e, j, ANIOS_OFERTA)
		var viejo: float = float(e.sueldos.get(int(j["id"]), 0.0))
		print("  pos %2d %-22s contratos=%10s | mejor media %2d edad %2d: cobra %8s, pide %8s (dif %8s, piso %8s)" % [
			i + 1, e.nombre, Economia.formato_dinero(presup),
			int(j.get("media", 0)), int(j.get("edad", 0)),
			Economia.formato_dinero(viejo), Economia.formato_dinero(pide),
			Economia.formato_dinero(pide - viejo),
			Economia.formato_dinero(pide * Renovaciones.PISO_DE_CESION - viejo)])
	quit()


## Los mejores por valor de mercado, que es con lo que se calcula el
## sueldo pretendido.
func _mejores(equipo: Team, cuantos: int) -> Array:
	var lista: Array = equipo.jugadores.duplicate()
	lista.sort_custom(func(a, b):
		return ValorJugador.calcular(a, 50.0, ANIOS_OFERTA) > ValorJugador.calcular(b, 50.0, ANIOS_OFERTA))
	return lista.slice(0, mini(cuantos, lista.size()))
