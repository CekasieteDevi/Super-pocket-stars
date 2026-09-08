extends SceneTree

## ¿Le da la plata al club del jugador para renovarle a sus mejores, año
## tras año? El diag de una temporada dice que si, pero el problema
## aparece despues: la progresion sube la media, el sueldo pretendido
## sigue al valor de hoy y el ingreso tiene techo.
##
## Simula OCHO temporadas de una division suelta con un club protegido
## (el del jugador). Al empezar cada temporada mira los contratos que se
## vencen y negocia como negociaria una persona: primero tira bajo, sube
## si el otro contraoferta, y firma si le entra en el presupuesto de
## Contratos.

const SEED := 777
const TEMPORADAS := 8
const ANIOS_OFERTA := 3
## Primera oferta: apenas arriba de FRACCION_INSULTO, que es lo que hace
## cualquiera que quiera negociar y no ofender.
const PRIMERA_OFERTA := 0.78


func _init() -> void:
	for division in [7, 8, 9]:
		_correr_division(division)
	quit()


func _correr_division(division: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var nombres := []
	var usados := {}
	for i in range(20):
		nombres.append(GeneradorNombres.nombre_club(rng, usados))
	var liga := Liga.new()
	liga.inicializar(nombres, rng, 0, division)
	var club: Team = liga.equipos[0]

	print("")
	print("=== DIVISION %d — club protegido: %s ===" % [division + 1, club.nombre])
	print("temp | media | ingresos | sueldos | neto | presup.contratos | vencen | costo pedido | costo pagado | renovados | perdidos por plata")
	for t in range(TEMPORADAS):
		liga.jugar_temporada(rng, false)
		var salida := liga.nueva_temporada(rng, club, t)
		var informe := {}
		for inf in salida[0]:
			if str(inf["equipo"]) == club.nombre:
				informe = inf

		var pendientes := Renovaciones.pendientes(club)
		# De mejor a peor: el jugador renueva primero al que le importa.
		pendientes.sort_custom(func(a, b):
			return ValorJugador.calcular(a, 50.0, ANIOS_OFERTA) > ValorJugador.calcular(b, 50.0, ANIOS_OFERTA))

		var pedido_total := 0.0
		var pagado_total := 0.0
		var renovados := 0
		var perdidos := 0
		var detalle := []
		for j in pendientes:
			var id: int = int(j["id"])
			var viejo: float = float(club.sueldos.get(id, 0.0))
			var pide_tabla := Renovaciones.sueldo_pretendido(club, j, ANIOS_OFERTA)
			pedido_total += maxf(0.0, pide_tabla - viejo)
			var cerrado := _negociar(club, j)
			if cerrado["exito"]:
				pagado_total += float(cerrado["diferencia"])
				renovados += 1
			else:
				perdidos += 1
				detalle.append("%s media %d edad %d: cobra %s, cierre %s, presup %s" % [
					j["posicion"], int(j.get("media", 0)), int(j.get("edad", 0)),
					Economia.formato_dinero(viejo),
					Economia.formato_dinero(float(cerrado["costo"])),
					Economia.formato_dinero(club.caja.get("contratos", 0.0))])

		print("%4d | %5.1f | %8s | %7s | %8s | %16s | %6d | %12s | %12s | %9d | %d" % [
			t + 1, club.media_equipo(),
			Economia.formato_dinero(informe.get("ingresos", 0.0)),
			Economia.formato_dinero(informe.get("sueldos", 0.0)),
			Economia.formato_dinero(informe.get("neto", 0.0)),
			Economia.formato_dinero(club.caja.get("contratos", 0.0) + pagado_total),
			pendientes.size(),
			Economia.formato_dinero(pedido_total),
			Economia.formato_dinero(pagado_total),
			renovados, perdidos])
		for d in detalle:
			print("       no le alcanzo: %s" % d)


## Negocia como una persona: tira bajo, sube cuando el otro contraoferta,
## y firma apenas acepta. Devuelve {exito, diferencia, costo}.
##
## costo es la diferencia de sueldo del mejor acuerdo al que llego, aunque
## no lo haya podido pagar: es el numero que hay que comparar contra el
## presupuesto.
func _negociar(club: Team, jugador: Dictionary) -> Dictionary:
	var id: int = int(jugador["id"])
	var viejo: float = float(club.sueldos.get(id, 0.0))
	var fraccion := PRIMERA_OFERTA
	var ultimo_costo := 0.0
	for ronda in range(Renovaciones.RONDAS_MAX + 1):
		var pide := Renovaciones.pide_ahora(club, jugador, ANIOS_OFERTA)
		var oferta: float = pide * fraccion
		var costo: float = maxf(0.0, oferta - viejo)
		ultimo_costo = costo
		# Si el presupuesto no da ni para la oferta baja, no hay nada que
		# hablar: la negociacion no crea plata.
		if not Economia.puede_pagar_contrato(club, costo):
			# Todavia puede cerrar mas barato si el otro cede: se sigue
			# negociando con lo que pide despues de ceder.
			var r_baja := Renovaciones.ofrecer(club, jugador, ANIOS_OFERTA, oferta)
			if str(r_baja["respuesta"]) != "contraoferta":
				return {"exito": false, "diferencia": 0.0, "costo": costo}
			continue
		var r := Renovaciones.ofrecer(club, jugador, ANIOS_OFERTA, oferta)
		match str(r["respuesta"]):
			"acepta":
				var firma := Renovaciones.firmar(club, jugador, ANIOS_OFERTA, oferta)
				return {"exito": bool(firma.get("exito", false)),
					"diferencia": float(firma.get("diferencia", 0.0)), "costo": costo}
			"contraoferta":
				# El otro bajo lo que pide: la proxima vuelta se le ofrece
				# exactamente eso, que es lo que acepta.
				fraccion = 1.0
			_:
				return {"exito": false, "diferencia": 0.0, "costo": costo}
	return {"exito": false, "diferencia": 0.0, "costo": ultimo_costo}
