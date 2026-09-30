extends SceneTree

## Etapa 2 del Motor V2 (docs/motor_v2.md): el cuerpo en C++
## (CuerposV2Nativos), sin pantalla.
## - Locomoción: arranca según su aceleración, llega frenando sin pasarse,
##   ningún paso mueve a nadie más de lo que da su velocidad, y nadie gira
##   180° en el lugar corriendo a velocidad máxima.
## - Reserva de sprint y cansancio bajan la punta.
## - Acciones: cada clip de data/acciones_v2.json dura lo que dura el clip y
##   abre y cierra la ventana de contacto en su cuadro; no se pisan; un gesto
##   que no se hace corriendo frena al cuerpo.
## - data/acciones_v2.json coincide con los GLB, los valores de cuerpo.h son
##   los de los JSON y la misma orden da la misma huella.

const SEED := 20260930
const PASO := 1.0 / 60.0
const RAPIDO := {"velocidad": 90.0, "aceleracion": 90.0, "agilidad": 90.0}
const LENTO := {"velocidad": 30.0, "aceleracion": 30.0, "agilidad": 30.0}

var fallos := 0
var _param: Dictionary
var _clips: Dictionary


func _init() -> void:
	if not ClassDB.class_exists("CuerposV2Nativos"):
		_ok(false, "la extensión motor_v2 está armada para esta plataforma (motor_v2/bin)")
		print("FALLOS=%d" % fallos)
		quit(1)
		return
	_param = FisicaV2.parametros_cuerpo()
	_clips = FisicaV2.clips()
	_arranque()
	_frenar_y_saltos()
	_media_vuelta()
	_giro_de_90()
	_reserva_y_cansancio()
	_acciones()
	_acciones_trabadas()
	_huellas()
	_clips_contra_glb()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _nuevo(fisico: Dictionary, pos := Vector2.ZERO, rumbo := PI * 0.5, param := _param) -> Object:
	var c: Object = ClassDB.instantiate("CuerposV2Nativos")
	c.configurar(param, _clips)
	c.agregar(pos, rumbo, fisico)
	return c


## Segundos hasta el 90% de la punta, corriendo derecho.
func _hasta_punta(fisico: Dictionary) -> float:
	var c := _nuevo(fisico)
	c.ir_a(0, Vector2(200.0, 0.0), 1.0, false)
	for k in 600:
		c.avanzar()
		if c.get_rapidez()[0] >= 0.9 * float(fisico["vel_max"]):
			return (k + 1) * PASO
	return INF


## Metros que hace en `segundos` arrancando parado.
func _metros_en(fisico: Dictionary, segundos: float) -> float:
	var c := _nuevo(fisico)
	c.ir_a(0, Vector2(200.0, 0.0), 1.0, false)
	for k in int(segundos / PASO):
		c.avanzar()
	return (c.get_pos()[0] as Vector2).x


func _arranque() -> void:
	var rapido := FisicaV2.fisico_de(RAPIDO)
	var lento := FisicaV2.fisico_de(LENTO)
	var solo_arranque := FisicaV2.fisico_de({"velocidad": 30.0, "aceleracion": 90.0, "agilidad": 30.0})
	var m_rapido := _metros_en(rapido, 1.5)
	var m_lento := _metros_en(lento, 1.5)
	var m_arranque := _metros_en(solo_arranque, 1.0)
	var m_sin := _metros_en(lento, 1.0)
	_ok(m_rapido > m_lento, "en 1,5 s el rápido hace más metros (%.1f contra %.1f)" % [m_rapido, m_lento])
	_ok(m_arranque > m_sin, "con la misma punta, más aceleración gana el primer segundo (%.2f contra %.2f m)"
		% [m_arranque, m_sin])
	var t := _hasta_punta(rapido)
	_ok(t > 0.8 and t < 3.0, "nadie llega a su punta de golpe ni tarda una eternidad (%.2f s)" % t)


## Llega frenando al punto, sin pasarse, y ningún paso es un salto.
func _frenar_y_saltos() -> void:
	var fisico := FisicaV2.fisico_de(RAPIDO)
	var c := _nuevo(fisico)
	c.ir_a(0, Vector2(20.0, 0.0), 1.0, true)
	var se_paso := 0.0
	var peor := 0.0
	var llego := -1.0
	var r_previa := 0.0
	for k in 600:
		c.avanzar()
		var p: Vector2 = c.get_pos()[0]
		var d := p.distance_to(c.get_pos_previa()[0])
		var r: float = c.get_rapidez()[0]
		peor = maxf(peor, d - maxf(r, r_previa) * PASO)
		r_previa = r
		se_paso = maxf(se_paso, p.x - 20.0)
		if c.get_eventos(0) & CuerposV2Nativos.LLEGO and llego < 0.0:
			llego = (k + 1) * PASO
	var fin: Vector2 = c.get_pos()[0]
	_ok(llego > 0.0 and fin.distance_to(Vector2(20.0, 0.0)) < 0.001 and c.get_rapidez()[0] == 0.0,
		"llega frenando a 20 m y queda parado (en %.2f s)" % llego)
	_ok(se_paso <= 0.0001, "no se pasa del punto (%.4f m)" % se_paso)
	_ok(peor <= 1e-6, "ningún paso lo mueve más que su velocidad (exceso %s m)" % peor)


## Corriendo a su punta hacia +x, le piden volver a -x.
func _media_vuelta() -> void:
	var fisico := FisicaV2.fisico_de(RAPIDO)
	var vmax: float = fisico["vel_max"]
	var c := _nuevo(fisico, Vector2(-40.0, 0.0))
	c.ir_a(0, Vector2(200.0, 0.0), 1.0, false)
	for k in 300:
		c.avanzar()
	_ok(c.get_rapidez()[0] > 0.95 * vmax, "antes de girar corre a su punta (%.1f m/s)" % c.get_rapidez()[0])
	c.ir_a(0, Vector2(-200.0, 0.0), 1.0, false)
	var giro_acel: float = _param["giro_acel"]
	var peor_giro := 0.0
	var peor_rumbo := 0.0
	var minima := INF
	var tarda := 0.0
	var vel_previa: Vector2 = c.get_vel(0)
	var rumbo_previo: float = c.get_rumbo()[0]
	for k in 600:
		c.avanzar()
		var v: Vector2 = c.get_vel(0)
		var r := v.length()
		minima = minf(minima, r)
		if r > 0.8 * vmax and vel_previa.length() > 0.8 * vmax:
			# Rapidez angular de la carrera contra lo que deja giro_acel.
			var w := absf(vel_previa.angle_to(v)) / PASO
			peor_giro = maxf(peor_giro, w / (giro_acel / r))
		var rumbo: float = c.get_rumbo()[0]
		peor_rumbo = maxf(peor_rumbo, absf(wrapf(rumbo - rumbo_previo, -PI, PI)) / PASO / float(fisico["giro"]))
		rumbo_previo = rumbo
		vel_previa = v
		if v.x < -0.9 * vmax and tarda == 0.0:
			tarda = (k + 1) * PASO
	_ok(peor_giro <= 1.01, "dándose vuelta, a más del 80%% de su punta la carrera gira como mucho giro_acel/v (%.3f del tope)" % peor_giro)
	_ok(peor_rumbo <= 1.01, "el cuerpo gira como mucho su agilidad por segundo (%.3f del tope)" % peor_rumbo)
	_ok(minima < 1.0, "para darse vuelta frena hasta casi parar (%.2f m/s)" % minima)
	_ok(tarda >= 2.0 * 0.9 * vmax / giro_acel, "tarda %.2f s en volver a correr al revés" % tarda)


## Corriendo a su punta le piden doblar 90°: la curva sale abierta, con un
## radio de al menos v²/giro_acel.
func _giro_de_90() -> void:
	var fisico := FisicaV2.fisico_de(RAPIDO)
	var vmax: float = fisico["vel_max"]
	var giro_acel: float = _param["giro_acel"]
	var c := _nuevo(fisico, Vector2(-40.0, 0.0))
	c.ir_a(0, Vector2(200.0, 0.0), 1.0, false)
	for k in 300:
		c.avanzar()
	var inicio: Vector2 = c.get_pos()[0]
	c.ir_a(0, Vector2(inicio.x, 200.0), 1.0, false)
	var peor := 0.0
	var vel_previa: Vector2 = c.get_vel(0)
	var giro_total := 0.0
	for k in 240:
		c.avanzar()
		var v: Vector2 = c.get_vel(0)
		var w := absf(vel_previa.angle_to(v)) / PASO
		giro_total += w * PASO
		if v.length() > 0.5 * vmax:
			peor = maxf(peor, w / (giro_acel / v.length()))
		vel_previa = v
	var adelante: float = (c.get_pos()[0] as Vector2).x - inicio.x
	# La velocidad llega en float de 32 bits: el 1% de margen es redondeo.
	_ok(peor <= 1.01 and giro_total > 1.2, "doblando 90° a su punta gira como mucho giro_acel/v (%.3f del tope, %.2f rad en 4 s)"
		% [peor, giro_total])
	_ok(adelante > 2.0, "la curva sale abierta: sigue %.1f m hacia adelante antes de doblar" % adelante)


func _reserva_y_cansancio() -> void:
	var fisico := FisicaV2.fisico_de(RAPIDO)
	var vmax: float = fisico["vel_max"]
	var c := _nuevo(fisico, Vector2(-5000.0, 0.0))
	c.ir_a(0, Vector2(5000.0, 0.0), 1.0, false)
	for k in 60 * 60:
		c.avanzar()
	var r: float = c.get_rapidez()[0]
	var piso: float = _param["piso_sprint"]
	_ok(c.get_reserva(0) < 0.3, "un minuto de pique vacía la reserva (%.2f)" % c.get_reserva(0))
	_ok(r < 0.95 * vmax and r >= piso * vmax - 0.01, "sin reserva baja la punta, no más que piso_sprint (%.2f de %.2f m/s)" % [r, vmax])
	var cansado := FisicaV2.fisico_de(RAPIDO, 0.2)
	var t := _nuevo(cansado)
	t.ir_a(0, Vector2(200.0, 0.0), 1.0, false)
	for k in 240:
		t.avanzar()
	_ok(t.get_rapidez()[0] < 0.95 * vmax, "con poca energía corre menos (%.2f contra %.2f m/s)" % [t.get_rapidez()[0], vmax])


## Cada clip que no es de andar, empezado parado: dura lo que el clip y abre y
## cierra la ventana en su cuadro de contacto.
func _acciones() -> void:
	var ventana: float = _param["ventana_contacto_seg"]
	var malas := []
	var probados := 0
	for nombre in _clips:
		var clip: Dictionary = _clips[nombre]
		if clip["locomocion"]:
			continue
		probados += 1
		var c := _nuevo(FisicaV2.fisico_de(RAPIDO))
		if not c.empezar_accion(0, nombre):
			malas.append("%s: no arranca" % nombre)
			continue
		if c.empezar_accion(0, "Cabecear"):
			malas.append("%s: acepta otra acción encima" % nombre)
		var abre := -1.0
		var cierra := -1.0
		var termina := -1.0
		var fase_max := 0
		var retrocede := false
		for k in int(float(clip["duracion"]) / PASO) + 5:
			c.avanzar()
			var e: int = c.get_eventos(0)
			var t := (k + 1) * PASO
			if e & CuerposV2Nativos.ABRE_CONTACTO:
				abre = t
			if e & CuerposV2Nativos.CIERRA_CONTACTO:
				cierra = t
			if e & CuerposV2Nativos.TERMINA_ACCION:
				termina = t
				break
			var f: int = c.get_fase(0)
			retrocede = retrocede or f < fase_max
			fase_max = maxi(fase_max, f)
		var dur: float = clip["duracion"]
		if absf(termina - dur) > PASO:
			malas.append("%s: dura %.3f y el clip %.3f" % [nombre, termina, dur])
		if retrocede:
			malas.append("%s: las fases vuelven atrás" % nombre)
		if clip["contacto"] != null:
			var tc: float = float(clip["contacto"]) * dur
			var esperado := maxf(tc - ventana * 0.5, 0.0)
			if abre < 0.0 or absf(abre - maxf(esperado, PASO)) > PASO + 1e-6:
				malas.append("%s: abre el contacto en %.3f y el clip toca en %.3f" % [nombre, abre, tc])
			if cierra < abre:
				malas.append("%s: no cierra el contacto" % nombre)
		elif abre >= 0.0:
			malas.append("%s: abre contacto sin tener" % nombre)
		if c.get_accion(0) != "" or not c.empezar_accion(0, "Cabecear"):
			malas.append("%s: al terminar no queda libre" % nombre)
	for m in malas:
		_ok(false, m)
	_ok(malas.is_empty() and probados > 30, "los %d clips con gesto duran lo del clip y abren el contacto en su cuadro" % probados)


## Un gesto parado (Cabecear) frena al que corría y no lo deja girar; uno que
## se hace corriendo (Patear_Corriendo) no.
func _acciones_trabadas() -> void:
	var fisico := FisicaV2.fisico_de(RAPIDO)
	for caso in [["Cabecear", false], ["Patear_Corriendo", true]]:
		var c := _nuevo(fisico, Vector2(-40.0, 0.0))
		c.ir_a(0, Vector2(200.0, 0.0), 1.0, false)
		for k in 180:
			c.avanzar()
		var antes: float = c.get_rapidez()[0]
		var rumbo: float = c.get_rumbo()[0]
		c.empezar_accion(0, caso[0])
		if not caso[1]:
			# Al que está trabado le piden darse vuelta: no puede.
			c.ir_a(0, Vector2(-200.0, 50.0), 1.0, false)
		var minima := antes
		var freno_max := 0.0
		var r_previa := antes
		while c.get_accion(0) != "":
			c.avanzar()
			var r: float = c.get_rapidez()[0]
			freno_max = maxf(freno_max, (r_previa - r) / PASO)
			r_previa = r
			minima = minf(minima, r)
			if not caso[1] and absf(c.get_rumbo()[0] - rumbo) > 1e-6:
				_ok(false, "%s: gira durante el gesto" % caso[0])
				break
		if caso[1]:
			_ok(minima > 0.5 * antes, "%s: sigue corriendo (%.1f m/s como mínimo)" % [caso[0], minima])
		else:
			_ok(minima < antes - 1.0 and freno_max <= float(_param["frenada"]) + 0.001,
				"%s: frena con su frenada, sin clavarse (de %.1f a %.1f m/s)" % [caso[0], antes, minima])


## Misma orden = misma huella; y los valores por defecto de cuerpo.h son los
## de los JSON (si alguien cambia uno solo, esto lo avisa).
func _huellas() -> void:
	var h1 := _recorrido(_param)
	var h2 := _recorrido(_param)
	var h3 := _recorrido({})
	_ok(h1 == h2, "la misma orden da la misma huella")
	_ok(h1 == h3, "cuerpo.h y los JSON (utility_pesos y fisica_v2) tienen los mismos valores")


func _recorrido(param: Dictionary) -> int:
	var c: Object = ClassDB.instantiate("CuerposV2Nativos")
	c.configurar(param, _clips)
	var fisicos := [FisicaV2.fisico_de(RAPIDO), FisicaV2.fisico_de(LENTO), FisicaV2.fisico_de(RAPIDO, 0.3)]
	for i in fisicos.size():
		c.agregar(Vector2(-10.0 * i, 3.0 * i), 0.3 * i, fisicos[i])
	var puntos := [Vector2(30, 10), Vector2(-20, -5), Vector2(5, 25)]
	for k in 60 * 20:
		if k % 90 == 0:
			for i in fisicos.size():
				c.ir_a(i, puntos[(i + k / 90) % puntos.size()], 1.0, (k / 90) % 2 == 0)
		if k == 300:
			c.empezar_accion(0, "Patear_Corriendo")
			c.empezar_accion(1, "Barrida")
		c.avanzar()
	return c.huella()


## data/acciones_v2.json tiene los clips de los GLB con su duración. Si
## cambian los clips hay que rehacerlo: tools/generar_acciones_v2.py.
func _clips_contra_glb() -> void:
	var en_glb := {}
	for ruta in [VistaCancha3D.ESCENA_JUGADOR, VistaCancha3D.ESCENA_GOLERO]:
		var escena: Node = (load(ruta) as PackedScene).instantiate()
		var ap: AnimationPlayer = escena.find_children("*", "AnimationPlayer", true, false)[0]
		for n in ap.get_animation_list():
			en_glb[n] = ap.get_animation(n).length
		escena.free()
	var distintos := []
	for n in en_glb:
		if not _clips.has(n):
			distintos.append("%s falta en el JSON" % n)
		elif absf(float(_clips[n]["duracion"]) - float(en_glb[n])) > 0.001 and not _clips[n].has("duracion_golero"):
			distintos.append("%s dura %.3f en el GLB y %.3f en el JSON" % [n, en_glb[n], _clips[n]["duracion"]])
	for n in _clips:
		if not en_glb.has(n):
			distintos.append("%s está en el JSON y no en los GLB" % n)
	for d in distintos:
		_ok(false, d)
	_ok(distintos.is_empty(), "data/acciones_v2.json coincide con los GLB (%d clips)" % en_glb.size())


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
