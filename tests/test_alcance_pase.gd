extends SceneTree

## Hasta donde llega una patada es FISICO: depende de la pierna del que
## la pega, no de contra quien juega.
##
## El alcance salia de _por_atributo normalizado al nivel del partido, o
## sea medido contra el rival. Consecuencia medida: las 10 divisiones
## daban la MISMA distribucion de distancias — un plantel con fuerza
## media 37 ponia la misma pelota de 60 m que uno de 87, porque en una
## liga de burros todos son "promedio" y por lo tanto todos llegan lejos.

const SEED := 5150
const PARTIDOS := 12


func _init() -> void:
	_test_el_flojo_no_llega_tan_lejos_como_el_bueno()
	_test_nadie_pasa_de_area_a_area()
	_test_el_flojo_remata_desde_mas_cerca()
	quit()


func _distancias(division: int) -> Dictionary:
	var pelotazos := []
	var pases := []
	for i in range(PARTIDOS):
		var r1 := RandomNumberGenerator.new()
		r1.seed = SEED + i
		var a := Team.generar("A", r1, 0, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var b := Team.generar("B", r1, 400, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := MotorEspacial.simular(a, b, r2, false)
		pelotazos.append_array(res["stats"]["dist_pelotazos"])
		pases.append_array(res["stats"]["dist_pases"])
	return {"pelotazos": pelotazos, "pases": pases}


func _maximo(valores: Array) -> float:
	var m := 0.0
	for v in valores:
		m = maxf(m, float(v))
	return m


func _media(valores: Array) -> float:
	if valores.is_empty():
		return 0.0
	var s := 0.0
	for v in valores:
		s += float(v)
	return s / valores.size()


func _test_el_flojo_no_llega_tan_lejos_como_el_bueno() -> void:
	print("=== Un plantel flojo no pone la pelota tan lejos ===")
	# Decima contra primera: fuerza media ~38 contra ~87.
	var baja := _distancias(9)
	var alta := _distancias(0)
	var m_baja := _media(baja["pelotazos"])
	var m_alta := _media(alta["pelotazos"])
	# Margen amplio a proposito: lo que se fija es que HAYA diferencia, no
	# el numero exacto, que se recalibra con _diag_goles_motores.
	if m_alta - m_baja < 6.0:
		print("FALLA: pelotazo medio %.1f m en decima contra %.1f en primera." % [
			m_baja, m_alta])
		return
	var max_baja := _maximo(baja["pelotazos"])
	var max_alta := _maximo(alta["pelotazos"])
	if max_alta - max_baja < 5.0:
		print("FALLA: el pelotazo mas largo fue %.1f m en decima y %.1f en primera." % [
			max_baja, max_alta])
		return
	print("OK: pelotazo medio %.1f m en decima contra %.1f en primera (maximos %.0f y %.0f)." % [
		m_baja, m_alta, max_baja, max_alta])


func _test_nadie_pasa_de_area_a_area() -> void:
	print("\n=== Nadie la pone de un area a la otra ===")
	# Son 72 m entre areas. Que ni el mejor plantel llegue es lo que hace
	# que un pelotazo se lea como un pelotazo y no como un teletransporte.
	var alta := _distancias(0)
	var todos: Array = alta["pelotazos"] + alta["pases"]
	var maximo := _maximo(todos)
	var de_area_a_area: float = MotorEspacial.LARGO - 33.0
	if maximo >= de_area_a_area:
		print("FALLA: el pase mas largo de primera fue de %.1f m (area a area son %.0f)." % [
			maximo, de_area_a_area])
		return
	print("OK: el pase mas largo de primera fue de %.1f m, contra %.0f de area a area." % [
		maximo, de_area_a_area])


## Y desde donde se ANIMAN a patear tambien depende del nivel: un
## delantero flojo se tiene que meter, uno bueno le pega de media
## distancia. Antes decima y quinta remataban desde exactamente la misma
## distancia, que fue el reporte que abrio esto.
func _test_el_flojo_remata_desde_mas_cerca() -> void:
	print("\n=== El flojo se tiene que meter para rematar ===")
	var baja := _remates(9)
	var alta := _remates(0)
	if baja.is_empty() or alta.is_empty():
		print("FALLA: no se remato en alguna de las dos divisiones.")
		return
	baja.sort()
	alta.sort()
	var p90_baja: float = float(baja[int(baja.size() * 0.9)])
	var p90_alta: float = float(alta[int(alta.size() * 0.9)])
	# Margen chico a proposito: la diferencia es real pero moderada, y
	# ensancharla cuesta paridad de goles (ver mezcla_fisica_rango_tiro).
	if p90_alta - p90_baja < 1.0:
		print("FALLA: p90 de %.1f m en decima contra %.1f en primera." % [
			p90_baja, p90_alta])
		return
	print("OK: p90 del remate %.1f m en decima contra %.1f en primera." % [
		p90_baja, p90_alta])


func _remates(division: int) -> Array:
	var tiros := []
	for i in range(PARTIDOS):
		var r1 := RandomNumberGenerator.new()
		r1.seed = SEED + i
		var a := Team.generar("A", r1, 0, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var b := Team.generar("B", r1, 400, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		tiros.append_array(MotorEspacial.simular(a, b, r2, false)["stats"]["dist_tiros"])
	return tiros
