extends SceneTree

## El calendario dia a dia.
##
## Antes, al jugar una fecha pasaban los 7 dias de un saque: todo lo que
## vencia en el medio —la respuesta de un club, una recuperacion, un
## informe— aparecia junto al final y no habia forma de frenar antes. El
## motor ya corria por dias; lo que faltaba era poder pasarlos de a uno.

const SEED := 4747


func _init() -> void:
	_test_la_fecha_avanza_de_a_un_dia()
	_test_no_se_puede_saltear_un_partido()
	_test_la_semana_de_copa_sigue_apretada()
	_test_una_temporada_entera_cierra_bien()
	_test_el_guardado_viejo_no_se_rompe()
	quit()


## El autoload no existe en modo --script, pero el script si se puede
## instanciar a mano: es un Node comun.
const GUION := preload("res://game/game_state.gd")


func _nueva_partida(desplazamiento: int = 0) -> Node:
	var gs = GUION.new()
	gs.partida_nueva(SEED + desplazamiento)
	return gs


func _test_la_fecha_avanza_de_a_un_dia() -> void:
	print("=== Un dia por vez ===")
	var gs := _nueva_partida()
	if not gs.hay_partido_hoy():
		print("FALLA: la partida no arranca con partido el dia 0.")
		return
	gs.jugar_siguiente_fecha()
	if gs.hay_partido_hoy():
		print("FALLA: despues de jugar sigue habiendo partido hoy.")
		return
	if gs.dias_hasta_el_partido() != 7:
		print("FALLA: el proximo partido esta a %d dias." % gs.dias_hasta_el_partido())
		return

	var dias := 0
	while not gs.hay_partido_hoy() and dias < 20:
		gs.avanzar_un_dia()
		dias += 1
	if dias != 7:
		print("FALLA: tardo %d dias en llegar al siguiente partido." % dias)
		return
	print("OK: se juega, y hay que pasar 7 dias de a uno hasta el siguiente.")


func _test_no_se_puede_saltear_un_partido() -> void:
	print("\n=== Con partido hoy no se avanza el dia ===")
	var gs := _nueva_partida()
	var dia_antes: int = gs.dia_temporada
	var novedades: Array = gs.avanzar_un_dia()
	if gs.dia_temporada != dia_antes or not novedades.is_empty():
		print("FALLA: avanzo el dia con un partido pendiente.")
		return
	print("OK: el dia no avanza hasta que se juega.")


func _test_la_semana_de_copa_sigue_apretada() -> void:
	print("\n=== La semana de copa sigue siendo dos partidos en 7 dias ===")
	# Es lo que le da sentido a elegir la carga de entrenamiento: si la
	# ronda de copa se corriera a una semana aparte, no habria semana
	# apretada nunca.
	var gs := _nueva_partida()
	var copas := 0
	for fecha in range(GUION.FECHAS_ENTRE_RONDAS_COPA):
		gs.jugar_siguiente_fecha()
		if gs.dia_proxima_copa >= 0:
			if gs.dia_proxima_copa - (gs.dia_proximo_partido - GUION.DIAS_ENTRE_FECHAS) \
					!= GUION.DIAS_HASTA_COPA:
				print("FALLA: la copa no quedo a %d dias de la fecha." % GUION.DIAS_HASTA_COPA)
				return
			copas += 1
		for d in range(GUION.DIAS_ENTRE_FECHAS):
			gs.avanzar_un_dia()
	if copas == 0:
		print("FALLA: en %d fechas no se agendo ninguna ronda de copa." % GUION.FECHAS_ENTRE_RONDAS_COPA)
		return
	print("OK: se agendo la copa al dia %d de la semana, %d vez/veces." % [
		GUION.DIAS_HASTA_COPA, copas])


func _test_una_temporada_entera_cierra_bien() -> void:
	print("\n=== Una temporada entera, dia por dia ===")
	var gs := _nueva_partida()
	var temporada: int = gs.temporada_actual
	var vueltas := 0
	while gs.temporada_actual == temporada and vueltas < 4000:
		if gs.hay_partido_hoy():
			gs.jugar_siguiente_fecha()
		else:
			gs.avanzar_un_dia()
		vueltas += 1
	if gs.temporada_actual == temporada:
		print("FALLA: no cerro la temporada en %d pasos." % vueltas)
		return
	# La temporada nueva NO arranca al dia siguiente: hay receso, y el
	# calendario queda parado antes del dia 0 hasta llegar a marzo. Sin
	# receso la temporada se corre en el almanaque —dura 266 dias— y los
	# meses del libro de pases caerian en otro momento cada ano.
	if gs.dia_temporada >= 0 or gs.dia_proximo_partido != 0:
		print("FALLA: no quedo en receso: dia %d, partido el %d." % [
			gs.dia_temporada, gs.dia_proximo_partido])
		return
	var receso: int = -gs.dia_temporada
	while gs.en_receso():
		gs.avanzar_un_dia()
	var f := Calendario.fecha(gs.dia_absoluto)
	if int(f["month"]) != Calendario.MES_INICIAL or int(f["day"]) != Calendario.DIA_INICIAL:
		print("FALLA: la temporada nueva arranca el %d/%d." % [int(f["day"]), int(f["month"])])
		return
	if gs.dia_absoluto <= 0:
		print("FALLA: el dia absoluto quedo en %d." % gs.dia_absoluto)
		return
	print("OK: cerro la temporada %d, %d dias de receso, y la nueva arranca el %s." % [
		temporada, receso, Calendario.texto_largo(gs.dia_absoluto)])


func _test_el_guardado_viejo_no_se_rompe() -> void:
	print("\n=== Un guardado sin calendario se puede cargar ===")
	var gs := _nueva_partida()
	gs.jugar_siguiente_fecha()
	# Un guardado hecho ANTES del calendario no trae ninguna de las cuatro
	# claves de dias: el diccionario vacio es exactamente ese caso.
	gs.restaurar_calendario({}, gs.liga_jugador().fixture.size())
	if not gs.hay_partido_hoy():
		print("FALLA: al cargar quedo a %d dias del partido en vez de hoy." % gs.dias_hasta_el_partido())
		return
	if gs.dia_temporada != gs.fecha_actual * GUION.DIAS_ENTRE_FECHAS:
		print("FALLA: el dia de temporada quedo en %d con la fecha %d." % [
			gs.dia_temporada, gs.fecha_actual])
		return
	print("OK: el guardado viejo cae parado en el dia del proximo partido (%s)." % [
		Calendario.texto_largo(gs.dia_absoluto)])
