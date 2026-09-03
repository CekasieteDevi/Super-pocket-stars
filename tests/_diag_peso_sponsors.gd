extends SceneTree

## Cuanto pesan los sponsors en el ingreso de una temporada.
##
## Se compara un club sin ningun sponsor contra el mismo club con los
## diez lugares llenos, en cada division. El club con sponsors toma los
## diez mejores que puede firmar con la reputacion y la hinchada de un
## club normal recien generado.

const PARTIDOS := 38
const POSICION := 10
const EQUIPOS := 20


func _init() -> void:
	print("division | ingreso sin sponsors | con 10 sponsors | de los sponsors | peso")
	for d in range(10):
		var rng := RandomNumberGenerator.new()
		rng.seed = 5000 + d
		var base := Team.generar("Club D%d" % (d + 1), rng, 0,
			NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
		base.division_actual = d
		base.fans = Fans.inicial(d)
		base.reputacion = Economia.reputacion_inicial(base.media_equipo())

		var sin_sponsors := Team.cargar(base.guardar())
		var informe_sin := Economia.procesar_temporada(sin_sponsors, POSICION, EQUIPOS, d)

		var con_sponsors := Team.cargar(base.guardar())
		_llenar_sponsors(con_sponsors, d)
		for p in range(PARTIDOS):
			Sponsors.registrar_partido(con_sponsors)
		Sponsors.cobrar_temporada(con_sponsors)
		var de_sponsors: float = con_sponsors.ingresos_sponsors
		var informe_con := Economia.procesar_temporada(con_sponsors, POSICION, EQUIPOS, d)

		var peso: float = de_sponsors / float(informe_con["ingresos"]) * 100.0
		print("   D%-2d   | %18s | %15s | %15s | %4.1f%%" % [
			d + 1,
			Economia.formato_dinero(informe_sin["ingresos"]),
			Economia.formato_dinero(informe_con["ingresos"]),
			Economia.formato_dinero(de_sponsors), peso])
	quit()


## Los diez que mas pagan de los que este club puede firmar hoy.
func _llenar_sponsors(equipo: Team, division: int) -> void:
	var posibles := []
	for s in Sponsors.catalogo()[division]:
		var requisito := str(s["requisito"])
		if not Sponsors.tiene_el_nombre(equipo, requisito, division):
			continue
		posibles.append({
			"nombre": str(s["nombre"]), "requisito": requisito,
			"pago": Sponsors.pago_de(requisito, float(s["factor"]), division),
			"division": division + 1, "desde": 1, "cobrado": 0.0, "partidos": 0,
		})
	posibles.sort_custom(func(a, b): return a["pago"] > b["pago"])
	equipo.sponsors = posibles.slice(0, Sponsors.LUGARES)
