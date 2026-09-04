extends SceneTree

## El tiro libre directo tiene que tener BARRERA, y la defensa tiene que
## quedar del lado del arco.
##
## Antes el acomodo empujaba a cada rival cercano en direccion opuesta a
## la pelota, hacia donde estuviera parado. O sea: nadie se ponia entre
## la pelota y el arco, y al que habia quedado adelantado lo mandaba
## todavia mas adelante. En la cancha se veia a la defensa irse ATRAS DE
## LA PELOTA y al pateador rematando solo de frente al arco.

const SEED := 7710


func _init() -> void:
	_test_hay_barrera_en_la_linea()
	_test_la_defensa_no_queda_adelante_de_la_pelota()
	_test_la_barrera_bloquea_alguna_vez()
	quit()


## Desde que la decision de patear al arco mira `tiros_libres` del
## ejecutante (ver MotorEspacial.tipo_de_falta), que una falta sea DIRECTA
## depende de QUIEN la patea y no solo de donde fue. Estos tests miden la
## BARRERA, no la clasificacion: si el plantel sorteado no tiene un
## pateador que llegue desde 24 m, la falta se clasifica como centro, no
## hay barrera y el test falla por una razon que no es la que mide.
##
## Por eso se le fija el atributo al plantel: 24 m piden 56 y el sorteo no
## lo garantiza. Que la clasificacion escale con el atributo lo cubre
## tests/_diag_tipos_libre.gd.
const TIROS_LIBRES_DEL_PATEADOR := 90


func _armar_estado(rng: RandomNumberGenerator) -> Dictionary:
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	for equipo in [casa, visita]:
		for j in equipo.jugadores:
			j["atributos"]["tiros_libres"] = TIROS_LIBRES_DEL_PATEADOR
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	MotorEspacial._reiniciar_desde_medio(estado, true, 1)
	return estado


## Una falta de frente al arco, afuera del area: la clase de pelota
## parada que el jugador vio terminar en gol dos veces en un partido.
func _falta_de_frente(estado: Dictionary, ataca_local: bool) -> Vector2:
	var arco := MotorEspacial.arco_rival(ataca_local)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	return Vector2(arco.x + hacia * 24.0, 3.0)


## Corre los ticks del congelado y del acomodo, y para JUSTO antes de
## que se ejecute: es el fotograma en el que se mira la foto del tiro
## libre.
func _correr_hasta_el_saque(estado: Dictionary) -> void:
	for t in range(MotorEspacial.TICKS_CONGELADO_FALTA
			+ int(MotorEspacial.TICKS_DETENIDO["falta"]) - 1):
		MotorEspacial._tick(estado, false)


func _test_hay_barrera_en_la_linea() -> void:
	print("=== Se arma una barrera entre la pelota y el arco ===")
	for ataca_local in [true, false]:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		var estado := _armar_estado(rng)
		var pos := _falta_de_frente(estado, ataca_local)
		var arco := MotorEspacial.arco_rival(ataca_local)
		MotorEspacial._tiro_libre(estado, pos, ataca_local, 24)
		if not estado.has("balon_parado") or str(estado["balon_parado"]["tipo"]) != "directo":
			print("FALLA: no se cobro un libre directo (tipo '%s')." % str(
				estado.get("balon_parado", {}).get("tipo", "-")))
			return
		# La barrera se arma DESPUES del congelado: los dos primeros
		# segundos nadie se mueve, que es donde se ve la infraccion.
		_correr_hasta_el_saque(estado)

		var en_la_linea := 0
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			if e["equipo_local"] == ataca_local or str(e["rol"]) == "ARQ":
				continue
			# Cerca del segmento pelota-arco y mas o menos a los 9,15: eso
			# es estar en la barrera y no en cualquier lado. La tolerancia
			# es amplia porque ya no se teletransportan: llegan trotando y
			# alguno queda un par de metros corto.
			var d_linea: float = MotorEspacial._dist_a_segmento(e["pos"], pos, arco)
			var d_pelota: float = pos.distance_to(e["pos"])
			if d_linea <= 3.5 and absf(d_pelota - 9.15) <= 3.0:
				en_la_linea += 1
		if en_la_linea < 2:
			print("FALLA: atacando el arco en x=%.0f solo %d en la barrera." % [
				arco.x, en_la_linea])
			return
	print("OK: en los dos arcos se paran al menos 2 en la linea, a 9,15 m.")


func _test_la_defensa_no_queda_adelante_de_la_pelota() -> void:
	print("\n=== La defensa queda del lado del arco, no atras de la pelota ===")
	var adelantados := 0
	var mirados := 0
	for i in range(20):
		for ataca_local in [true, false]:
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i
			var estado := _armar_estado(rng)
			var pos := _falta_de_frente(estado, ataca_local)
			var arco := MotorEspacial.arco_rival(ataca_local)
			var hacia: float = -1.0 if arco.x > 0.0 else 1.0
			MotorEspacial._tiro_libre(estado, pos, ataca_local, 24)
			_correr_hasta_el_saque(estado)
			for id in estado["jugadores"]:
				var e: Dictionary = estado["jugadores"][id]
				if e["equipo_local"] == ataca_local or str(e["rol"]) == "ARQ":
					continue
				# Los de arriba del que defiende se quedan arriba
				# esperando el rechazo: un delantero no se vuelve 28
				# metros porque le cobraron una falta a su equipo. Lo que
				# no puede pasar es que baje la DEFENSA.
				if MotorEspacial.ROLES_QUE_ATACAN.has(str(e["rol"])):
					continue
				mirados += 1
				# "Adelante de la pelota" es del lado contrario al arco:
				# ahi el defensor no defiende nada.
				if (e["pos"].x - pos.x) * hacia > 2.0:
					adelantados += 1
	# No es cero: alguno estaba muy metido en campo rival cuando se
	# cobro y no llega a volver antes del saque, que es lo que pasa de
	# verdad. Lo que se fija es que sea la excepcion y no la regla: con
	# el bug viejo eran 6 de cada 10.
	var pct: float = 100.0 * adelantados / maxf(mirados, 1)
	if pct > 8.0:
		print("FALLA: %d de %d defensores (%.0f%%) quedaron adelante de la pelota." % [
			adelantados, mirados, pct])
		return
	print("OK: solo %d de %d defensores (%.0f%%) quedaron adelante de la pelota." % [
		adelantados, mirados, pct])


func _test_la_barrera_bloquea_alguna_vez() -> void:
	print("\n=== La barrera bloquea alguna vez ===")
	# Si nunca bloquea es decorado: el pateador remata igual de solo que
	# antes, solo que ahora hay gente parada al lado.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 100
	var libres := 0
	var bloqueados := 0
	for i in range(60):
		var estado := _armar_estado(rng)
		var pos := _falta_de_frente(estado, true)
		MotorEspacial._tiro_libre(estado, pos, true, 24)
		var eventos_antes: int = estado["eventos"].size()
		for t in range(MotorEspacial.TICKS_DETENIDO["falta"] + 12):
			MotorEspacial._tick(estado, false)
		for k in range(eventos_antes, estado["eventos"].size()):
			var ev: Dictionary = estado["eventos"][k]
			if str(ev.get("tipo", "")) != "tiro" and str(ev.get("tipo", "")) != "tiro_puerta":
				continue
			libres += 1
			if str(ev.get("resultado", "")) == "bloqueado":
				bloqueados += 1
			break
	if libres == 0:
		print("FALLA: no se remato ningun tiro libre.")
		return
	if bloqueados == 0:
		print("FALLA: %d tiros libres y la barrera no bloqueo ninguno." % libres)
		return
	print("OK: la barrera bloqueo %d de %d tiros libres (%.0f%%)." % [
		bloqueados, libres, 100.0 * bloqueados / libres])
