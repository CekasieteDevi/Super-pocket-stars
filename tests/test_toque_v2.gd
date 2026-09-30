extends SceneTree

## Etapa 3 del Motor V2 (docs/motor_v2.md): tocar la pelota, en C++
## (CanchitaV2Nativa), sin pantalla.
## - Lo que planean todos es lo que hace la pelota: la predicción coincide
##   con la física paso por paso mientras nadie la toca.
## - Recepción según la altura: pie, muslo, pecho y cabeza, cada una con su
##   clip, y la parte coincide con la altura de la pelota en el toque.
## - Intercepción = el primero que la alcanza, de cualquier equipo.
## - Rondo 4 vs 2 y partidito 5 vs 5: cero correcciones de la pelota, cortes
##   solo con el pie del defensor en la pelota, ningún receptor frena en seco
##   ni espera parado, y la conducción es por toques.
## - Misma semilla = misma huella; toque.h tiene los valores del JSON.

const SEED := 20261001
const PASO := 1.0 / 60.0
const MEDIO := {"velocidad": 70.0, "aceleracion": 70.0, "agilidad": 70.0, "pases": 70.0, "control": 70.0}

var fallos := 0
var _toque: Dictionary


func _init() -> void:
	if not ClassDB.class_exists("CanchitaV2Nativa"):
		_ok(false, "la extensión motor_v2 está armada para esta plataforma (motor_v2/bin)")
		print("FALLOS=%d" % fallos)
		quit(1)
		return
	_toque = FisicaV2.parametros_toque()
	_prediccion_exacta()
	_recepcion_por_altura()
	_intercepcion()
	_juegos()
	_huellas()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _nueva(toque := _toque) -> Object:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	c.configurar(FisicaV2.parametros(), FisicaV2.parametros_cuerpo(), FisicaV2.clips(), toque)
	return c


## Nadie la toca: lo que se predijo al lanzarla es lo que hace, con efecto
## y todo, y cae en el mismo lugar.
func _prediccion_exacta() -> void:
	var c := _nueva()
	c.agregar(0, FisicaV2.jugador_de(MEDIO))
	c.empezar(CanchitaV2Nativa.PRUEBA, SEED)
	c.poner_jugador(0, Vector2(0.0, 14.0), 0.0)
	c.lanzar(Vector3(-15.0, 0.11, -10.0), Vector3(14.0, 6.0, 3.0), Vector3(0.0, 20.0, 0.0), 1)
	var prevista: PackedVector3Array = c.prediccion()
	var peor := 0.0
	for k in 180:
		c.avanzar()
		peor = maxf(peor, c.get_pelota_pos().distance_to(prevista[k]))
	_ok(peor == 0.0, "la trayectoria que planean todos es la de la física (peor diferencia %s m)" % peor)


## Pelotas que llegan a distintas alturas a uno parado: las cuatro partes
## aparecen, cada toque con el clip de su parte, y la parte es la de la
## altura de la pelota en ese momento.
func _recepcion_por_altura() -> void:
	var clip_de := {"pie": _toque["clip_recepcion"][0], "muslo": _toque["clip_recepcion"][1],
		"pecho": _toque["clip_recepcion"][2], "cabeza": _toque["clip_recepcion"][3]}
	var hasta := {"pie": float(_toque["pie_hasta"]), "muslo": float(_toque["muslo_hasta"]),
		"pecho": float(_toque["pecho_hasta"]), "cabeza": float(_toque["cabeza_hasta"])}
	var vistas := {}
	var mal := []
	for vi in range(8, 17):
		for ei in range(0, 16):
			var v := float(vi)
			var e := float(ei) * 0.05
			var c := _nueva()
			c.agregar(0, FisicaV2.jugador_de(MEDIO))
			c.empezar(CanchitaV2Nativa.PRUEBA, SEED)
			c.poner_jugador(0, Vector2.ZERO, -PI * 0.5)
			c.lanzar(Vector3(-12.0, 0.11, 0.0), Vector3(v * cos(e), v * sin(e), 0.0), Vector3.ZERO, 0)
			var previa := Vector3.ZERO
			var accion := ""
			for k in 240:
				previa = c.get_pelota_pos()
				accion = c.get_accion(0)
				c.avanzar()
				if c.get_ultimo_toque() == 0:
					break
			if c.get_ultimo_toque() != 0:
				continue
			var k: Dictionary = c.contadores()
			for parte in hasta:
				if int(k[parte]) == 0:
					continue
				vistas[parte] = int(vistas.get(parte, 0)) + 1
				# En el paso del toque la pelota fue de `previa` a donde está.
				var bajo := minf(previa.y, c.get_pelota_previa().y)
				var alto := maxf(previa.y, c.get_pelota_previa().y)
				var desde: float = {"pie": 0.0, "muslo": hasta["pie"], "pecho": hasta["muslo"],
					"cabeza": hasta["pecho"]}[parte]
				var tol := float(_toque["tolerancia_alto_m"])
				if c.get_accion(0) != clip_de[parte] and accion != clip_de[parte]:
					mal.append("%s con %s (v %.0f, %.2f rad)" % [parte, c.get_accion(0), v, e])
				elif alto < desde - tol or bajo > hasta[parte] + tol:
					mal.append("%s entre %.2f y %.2f m (v %.0f, %.2f rad)" % [parte, bajo, alto, v, e])
	_ok(vistas.size() == 4, "recibe con pie, muslo, pecho y cabeza según la altura (%s)" % vistas)
	_ok(mal.is_empty(), "cada recepción usa el clip de su parte, a su altura %s" % str(mal.slice(0, 4)))


## Una pelota que cruza entre dos rivales: la toca el que llega primero.
## Cambiados de lugar, la toca el otro.
func _intercepcion() -> void:
	var quien := []
	for invertido in [false, true]:
		var c := _nueva()
		c.agregar(0, FisicaV2.jugador_de(MEDIO))
		c.agregar(1, FisicaV2.jugador_de(MEDIO))
		c.empezar(CanchitaV2Nativa.PRUEBA, SEED)
		var cerca := Vector2(2.0, 3.0)
		var lejos := Vector2(8.0, -5.0)
		c.poner_jugador(0, lejos if invertido else cerca, PI)
		c.poner_jugador(1, cerca if invertido else lejos, PI)
		c.lanzar(Vector3(-10.0, 0.11, 0.0), Vector3(9.0, 0.0, 0.0), Vector3.ZERO, 0)
		for k in 300:
			c.avanzar()
			if c.get_ultimo_toque() >= 0:
				break
		quien.append(c.get_ultimo_toque())
	_ok(quien == [0, 1], "la toca el primero que la alcanza, sea del equipo que sea (%s)" % [quien])


## Rondo y partidito, dos minutos cada uno.
func _juegos() -> void:
	var tolerancia := float(_toque["tolerancia_m"])
	for modo in [CanchitaV2Nativa.RONDO, CanchitaV2Nativa.PARTIDITO]:
		var nombre: String = ["rondo", "partidito"][modo]
		var c := CanchitaV2.armar(modo, SEED)
		var peor_bola := 0.0
		var lejos_conduciendo := 0.0
		var cerca_conduciendo := INF
		var conducciones_previas := 0
		var conductor := -1
		for k in 120 * 60:
			c.avanzar()
			var kk: Dictionary = c.contadores()
			# Entre toques de conducción la pelota está suelta: se separa del pie.
			if int(kk["conducciones"]) > conducciones_previas:
				conductor = c.get_ultimo_toque()
				conducciones_previas = int(kk["conducciones"])
			if conductor >= 0 and c.get_poseedor() == conductor:
				var b: Vector3 = c.get_pelota_pos()
				var d: float = c.get_pos()[conductor].distance_to(Vector2(b.x, b.z))
				lejos_conduciendo = maxf(lejos_conduciendo, d)
				cerca_conduciendo = minf(cerca_conduciendo, d)
			else:
				conductor = -1
			peor_bola = maxf(peor_bola, c.get_pelota_pos().distance_to(c.get_pelota_previa()))
		var k: Dictionary = c.contadores()
		var pases := float(k["pases"])
		var completos := (float(k["completados"]) + float(k["completados_otro"])) / maxf(pases, 1.0)
		print("  %s: %d pases (%.0f%% completos, %d cortes, %d afuera), %d conducciones, recepciones %d/%d/%d/%d" % [
			nombre, pases, completos * 100.0, k["cortes"], k["pases_afuera"], k["conducciones"], k["pie"], k["muslo"],
			k["pecho"], k["cabeza"]])
		_ok(int(k["correcciones"]) == 0, "%s: cero correcciones de velocidad de la pelota" % nombre)
		_ok(int(k["saltos_pelota"]) == 0 and peor_bola < 0.6,
			"%s: la pelota nunca salta (SALTO_PELOTA %d, peor paso %.2f m)" % [nombre, k["saltos_pelota"], peor_bola])
		_ok(int(k["cortes"]) > 0 and float(k["corte_mas_lejos_m"]) <= tolerancia,
			"%s: los pases se cortan solo con el pie del defensor en la pelota (%d cortes, el más lejos a %.2f m)"
			% [nombre, k["cortes"], k["corte_mas_lejos_m"]])
		_ok(int(k["frenadas_en_seco"]) == 0, "%s: nadie frena en seco (%d)" % [nombre, k["frenadas_en_seco"]])
		_ok(float(k["espera_media"]) < 0.2 and int(k["esperas_largas"]) <= 1,
			"%s: el receptor no espera parado (media %.2f s, más de 0,5 s: %d de %d)"
			% [nombre, k["espera_media"], k["esperas_largas"], k["recepciones_medidas"]])
		_ok(float(k["peor_salto_cuerpo_m"]) < 0.1,
			"%s: nadie se teletransporta (peor exceso %.3f m)" % [nombre, k["peor_salto_cuerpo_m"]])
		_ok(completos > 0.6, "%s: la mayoría de los pases llega (%.0f%%)" % [nombre, completos * 100.0])
		if modo == CanchitaV2Nativa.PARTIDITO:
			_ok(int(k["conducciones"]) > 0 and cerca_conduciendo < 0.5 and lejos_conduciendo > 1.0,
				"partidito: conduce por toques; entre toques la pelota se le adelanta (de %.2f a %.2f m)"
				% [cerca_conduciendo, lejos_conduciendo])


## Misma semilla = misma huella; distinta semilla, otra. Con los números por
## defecto de toque.h (solo los clips del JSON) da lo mismo que con el JSON.
func _huellas() -> void:
	var a := CanchitaV2.armar(CanchitaV2Nativa.RONDO, SEED)
	var b := CanchitaV2.armar(CanchitaV2Nativa.RONDO, SEED)
	var d := CanchitaV2.armar(CanchitaV2Nativa.RONDO, SEED + 1)
	var solo_clips := {}
	for clave in ["clip_pase", "clip_conduce", "clip_recepcion"]:
		solo_clips[clave] = _toque[clave]
	var e := CanchitaV2.armar(CanchitaV2Nativa.RONDO, SEED, solo_clips)
	for c in [a, b, d, e]:
		c.simular(30 * 60)
	_ok(a.huella() == b.huella(), "la misma semilla da la misma huella")
	_ok(a.huella() != d.huella(), "otra semilla da otra huella")
	_ok(a.huella() == e.huella(), "toque.h y data/fisica_v2.json tienen los mismos valores")


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: ", texto)
	else:
		fallos += 1
		print("FALLA: ", texto)
