extends SceneTree

## Cuánto le suma a un equipo en el partido cada jugada preparada, en los
## dos motores. A sabe UNA jugada y B no sabe ninguna; mismos planteles y
## mismas semillas para cada jugada, así la diferencia contra "ninguna" es
## de la jugada y no del sorteo.
##
## Sirve para calibrar Jugadas.EQUIVALENCIA: el efecto de cada jugada
## tiene que dar parecido en el MotorEspacial y en el MatchEngine. Además
## cuenta cuántas veces por partido se usó la jugada en el espacial y
## cuántos offsides le cobraron a B, que es lo que mueve la defensa
## adelantada.
##
##   <godot> --path . --headless --script tests/_diag_jugadas_partido.gd [-- jugada ...]
##
## Con jugadas después de "--" mide solo esas (más "ninguna", que es la
## base). Sirve para repartir la corrida en varios procesos.

const SEED := 9200
const PARTIDOS := 400
const DIVISION := 4


func _init() -> void:
	print("%d partidos por fila, division %d" % [PARTIDOS, DIVISION + 1])
	print("jugada               | espacial GF   GC  dif  usos offB | abstracto GF   GC  dif")
	var pedidos := OS.get_cmdline_user_args()
	var corridas := [""]
	for id in Jugadas.LISTA:
		if pedidos.is_empty() or pedidos.has(id):
			corridas.append(id)
	var base := {}
	for id in corridas:
		var esp := _medir(id, true)
		var abs_ := _medir(id, false)
		if base.is_empty():
			base = {"esp": esp, "abs": abs_}
		print("%-20s | %+5.2f %+5.2f %+5.2f %5.2f %4.2f | %+5.2f %+5.2f %+5.2f" % [
			id if id != "" else "ninguna",
			esp[0] - base["esp"][0], esp[1] - base["esp"][1],
			(esp[0] - esp[1]) - (base["esp"][0] - base["esp"][1]),
			esp[2], esp[3],
			abs_[0] - base["abs"][0], abs_[1] - base["abs"][1],
			(abs_[0] - abs_[1]) - (base["abs"][0] - base["abs"][1])])
	print("(ninguna: espacial %.2f-%.2f, abstracto %.2f-%.2f)" % [
		base["esp"][0], base["esp"][1], base["abs"][0], base["abs"][1]])
	quit()


## [goles de A, goles de B, usos de la jugada de A, offsides de B] por partido.
func _medir(id: String, espacial: bool) -> Array:
	var ga := 0
	var gb := 0
	var usos := 0
	var off_b := 0
	for i in range(PARTIDOS):
		var r1 := RandomNumberGenerator.new()
		r1.seed = SEED + i
		var a := Team.generar("A", r1, 0, NivelDivision.potencial(DIVISION),
			"Uruguay", NivelDivision.realizacion(DIVISION))
		var b := Team.generar("B", r1, 400, NivelDivision.potencial(DIVISION),
			"Uruguay", NivelDivision.realizacion(DIVISION))
		a.jugadas_aprendidas = [] if id == "" else [id]
		b.jugadas_aprendidas = []
		# Mitad de local y mitad de visitante: la localía no se mezcla con
		# la jugada.
		var a_local: bool = i % 2 == 0
		var home: Team = a if a_local else b
		var away: Team = b if a_local else a
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED * 7 + i
		var res: Dictionary = MotorEspacial.simular(home, away, r2, false) if espacial \
			else MatchEngine.simular(home, away, r2)
		var gl := int(res["goles_local"])
		var gv := int(res["goles_visitante"])
		ga += gl if a_local else gv
		gb += gv if a_local else gl
		if espacial:
			var st: Dictionary = res.get("stats", {}).get("jugadas", {})
			var lado_a := "local" if a_local else "visitante"
			var lado_b := "visitante" if a_local else "local"
			usos += int((st.get(lado_a, {}) as Dictionary).get(id, 0))
			off_b += int((st.get("offsides", {}) as Dictionary).get(lado_b, 0))
	return [float(ga) / PARTIDOS, float(gb) / PARTIDOS, float(usos) / PARTIDOS, float(off_b) / PARTIDOS]
