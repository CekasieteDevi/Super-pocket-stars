extends SceneTree
## Caras de los jugadores 3D (tools/generar_caras.py, Jugador3D, GestosCara):
##
## 1. El atlas tiene 20 caras x 5 gestos, cada celda dibujada, adentro de la
##    cara (debajo del flequillo y arriba del mentón), y las 20 distintas.
## 2. Un plantel sale con caras variadas y cada jugador tiene siempre la misma.
## 3. GestosCara: dolor en la caída y la lesión, alegría y tristeza en el gol.
## 4. En un partido real reproducido con VistaCancha3D (división 1, semilla
##    22: cae en el tick 24, lesión en el 93, gol visitante en el 112 y local
##    en el 186), cada persona dibujada tiene el gesto que corresponde.

const SEED := 22
const DIVISION := 0

var fallos := 0
var _rep: VistaPartido
var _vista: VistaCancha3D
var _cuadros := 0
var _fase := 0
var _espera := 0
var _vistos := {}
var _datos := {}


func _initialize() -> void:
	_probar_atlas()
	_probar_reparto()
	_probar_gestos()
	process_frame.connect(_cuadro)


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("OK: ", texto)
	else:
		fallos += 1
		print("FALLA: ", texto)


func _terminar() -> void:
	print("FALLOS=", fallos)
	quit(1 if fallos > 0 else 0)


# ------------------------------------------------------------ 1. atlas

func _probar_atlas() -> void:
	var img: Image = Jugador3D.ATLAS_CARAS.get_image()
	if img.is_compressed():
		img.decompress()
	var gestos := Jugador3D.Gesto.size()
	var ancho := img.get_width() / gestos
	var alto := img.get_height() / Jugador3D.CANTIDAD_CARAS
	_ok(ancho * gestos == img.get_width() and alto * Jugador3D.CANTIDAD_CARAS == img.get_height(),
		"atlas de %dx%d: %d gestos x %d caras" % [img.get_width(), img.get_height(), gestos, Jugador3D.CANTIDAD_CARAS])
	var r := Jugador3D.RECT_CARA
	# Del mentón (1.18) a las puntas del flequillo (1.66, la gota de sudor
	# llega a 1.63): lo que caiga afuera no se vería o quedaría en el cuello.
	var fila_arriba := int((r.end.y - 1.66) / r.size.y * alto)
	var fila_abajo := int((r.end.y - 1.18) / r.size.y * alto)
	var vacias := 0
	var afuera := 0
	for n in Jugador3D.CANTIDAD_CARAS:
		for g in gestos:
			var pintados := 0
			for y in alto:
				for x in range(0, ancho, 2):
					if img.get_pixel(g * ancho + x, n * alto + y).a > 0.1:
						pintados += 1
						if y < fila_arriba or y > fila_abajo:
							afuera += 1
			if pintados < 200:
				vacias += 1
	_ok(vacias == 0, "cada celda tiene su dibujo (vacías: %d)" % vacias)
	_ok(afuera == 0, "nada se dibuja arriba del flequillo ni debajo del mentón (%d píxeles)" % afuera)
	# Las 20 caras normales son distintas de a pares, y cada gesto cambia la cara.
	var parecidas := 0
	var diferencia_minima := INF
	for a in Jugador3D.CANTIDAD_CARAS:
		for b in range(a + 1, Jugador3D.CANTIDAD_CARAS):
			var d := _diferencia(img, 0, a, 0, b, ancho, alto)
			diferencia_minima = minf(diferencia_minima, d)
			if d < 0.01:
				parecidas += 1
	_ok(parecidas == 0, "las 20 caras son distintas (menor diferencia %.3f)" % diferencia_minima)
	var gestos_iguales := 0
	for n in Jugador3D.CANTIDAD_CARAS:
		for g in [Jugador3D.Gesto.FELIZ, Jugador3D.Gesto.DOLOR, Jugador3D.Gesto.TRISTE, Jugador3D.Gesto.PARPADEO]:
			if _diferencia(img, 0, n, g, n, ancho, alto) < 0.004:
				gestos_iguales += 1
	_ok(gestos_iguales == 0, "cada gesto cambia la cara de todos (%d iguales a la normal)" % gestos_iguales)


## Diferencia media de alfa entre dos celdas (0 = iguales).
static func _diferencia(img: Image, g1: int, n1: int, g2: int, n2: int, ancho: int, alto: int) -> float:
	var suma := 0.0
	var cuenta := 0
	for y in range(0, alto, 2):
		for x in range(0, ancho, 2):
			var p := img.get_pixel(g1 * ancho + x, n1 * alto + y)
			var q := img.get_pixel(g2 * ancho + x, n2 * alto + y)
			suma += absf(p.a - q.a) + (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) * minf(p.a, q.a) / 3.0
			cuenta += 1
	return suma / float(cuenta)


# ---------------------------------------------------------- 2. reparto

func _probar_reparto() -> void:
	var usos := {}
	for id in range(1, 2001):
		var c := Jugador3D.cara_de(id)
		usos[c] = int(usos.get(c, 0)) + 1
	var menos := 2000
	var mas := 0
	for c in Jugador3D.CANTIDAD_CARAS:
		menos = mini(menos, int(usos.get(c, 0)))
		mas = maxi(mas, int(usos.get(c, 0)))
	# Parejo: cada cara entre la mitad y el doble del 5% esperado.
	_ok(menos >= 50 and mas <= 200, "2000 jugadores: cada cara entre %d y %d veces" % [menos, mas])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipo := Team.generar("Caras FC", rng)
	var distintas := {}
	for j in equipo.jugadores:
		distintas[Jugador3D.cara_de(int(j["id"]))] = true
	var rival := Team.generar("Espejo FC", rng, 1000)
	var iguales := 0
	for i in mini(equipo.jugadores.size(), rival.jugadores.size()):
		if Jugador3D.cara_de(int(equipo.jugadores[i]["id"])) == Jugador3D.cara_de(int(rival.jugadores[i]["id"])):
			iguales += 1
	_ok(iguales <= 3, "el rival no repite las caras en el mismo orden (%d de %d iguales)" % [iguales, rival.jugadores.size()])
	_ok(distintas.size() >= 7, "un plantel de %d tiene %d caras distintas" % [equipo.jugadores.size(), distintas.size()])
	_ok(Jugador3D.cara_de(12345) == Jugador3D.cara_de(12345), "el mismo jugador tiene siempre la misma cara")


# ----------------------------------------------------------- 3. gestos

func _probar_gestos() -> void:
	var G := Jugador3D.Gesto
	var fotos := []
	for k in 60:
		fotos.append({"detenido": 0, "eventos": [], "jugadores": [
			{"id": 1, "equipo_local": true}, {"id": 2, "equipo_local": false}]})
	# Gol del local en el 10: el juego queda parado hasta el saque del 20.
	fotos[10]["eventos"] = [{"tipo": "tiro_puerta", "resultado": "gol", "equipo": "Local", "rival": "Visita", "clave": 1}]
	for k in range(10, 20):
		fotos[k]["detenido"] = 20 - k
	# Gol en contra del visitante (lo suma el local) en el 40, sin pausa grabada.
	fotos[40]["eventos"] = [{"tipo": "rebote_arquero", "resultado": "gol", "autogol": true, "equipo": "Local", "rival": "Visita"}]
	fotos[50]["eventos"] = [{"tipo": "lesion", "resultado": "lesion", "clave": 2, "equipo": "Visita"}]
	var d := GestosCara.preparar(fotos, "Local")
	_ok(GestosCara.gesto(d, 1, true, "", 5.0) == G.NORMAL, "antes del gol, cara normal")
	_ok(GestosCara.gesto(d, 1, true, "", 10.0) == G.FELIZ, "el que hizo el gol, feliz")
	_ok(GestosCara.gesto(d, 2, false, "", 10.0) == G.TRISTE, "el que lo recibió, triste")
	_ok(GestosCara.gesto(d, 2, false, "", 20.0 + GestosCara.EMOCION_TRAS_SAQUE_TICKS) == G.TRISTE,
		"sigue triste un rato después del saque")
	_ok(GestosCara.gesto(d, 2, false, "", 21.0 + GestosCara.EMOCION_TRAS_SAQUE_TICKS) == G.NORMAL,
		"después vuelve a la cara normal")
	_ok(GestosCara.gesto(d, 1, true, "", 41.0) == G.FELIZ and GestosCara.gesto(d, 2, false, "", 41.0) == G.TRISTE,
		"gol en contra: festeja el que lo suma")
	_ok(GestosCara.gesto(d, 1, true, "cae", 30.0) == G.DOLOR, "el que cae por una falta, dolor")
	_ok(GestosCara.gesto(d, 1, true, "cae", 12.0) == G.DOLOR, "el dolor manda sobre el festejo")
	_ok(GestosCara.gesto(d, 2, false, "", 49.5) == G.NORMAL and GestosCara.gesto(d, 2, false, "", 55.0) == G.DOLOR,
		"el lesionado tiene dolor desde que se lastima")
	_ok(GestosCara.gesto(d, 1, true, "", 55.0) == G.NORMAL, "los demás no")
	_ok(GestosCara.gesto(d, 1, true, MotorEspacial.ACCION_FESTEJA, 30.0) == G.FELIZ, "el que festeja, feliz")
	var tanda := [{"detenido": 0, "eventos": [{"tipo": "penal_tanda", "resultado": "gol", "equipo": "Visita", "rival": "Local", "clave": 2}], "jugadores": []}]
	var dt := GestosCara.preparar(tanda, "Local")
	_ok(GestosCara.gesto(dt, 2, false, "", 3.0) == G.FELIZ and GestosCara.gesto(dt, 1, true, "", 3.0) == G.TRISTE,
		"penal convertido en la tanda")


# ------------------------------------------------- 4. partido reproducido

func _armar_partido() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var potencial := NivelDivision.potencial(DIVISION)
	var realizacion := NivelDivision.realizacion(DIVISION)
	var local := Team.generar("Atlético Prueba", rng, 0, potencial, "Uruguay", realizacion)
	var visita := Team.generar("Deportivo Banco", rng, 1000, potencial, "Uruguay", realizacion)
	var r := MotorEspacial.simular(local, visita, rng, true)
	_datos = GestosCara.preparar(r["fotogramas"], local.nombre)
	_rep = VistaPartido.new()
	root.add_child(_rep)
	# Como Prototipo3D._cambiar_a_3d: la cancha 3D en el lugar de la 2D.
	var vieja := _rep.vista
	_vista = VistaCancha3D.new()
	_rep.add_child(_vista)
	_rep.move_child(_vista, vieja.get_index())
	_rep.remove_child(vieja)
	vieja.queue_free()
	_rep.vista = _vista
	var colores := ColoresClub.par(local.nombre, visita.nombre)
	_rep.iniciar(r["fotogramas"], colores[0], colores[1], local.nombre, visita.nombre,
		VistaPartido.construir_nombres(local, visita),
		VistaCancha.nivel_estadio_desde_calidad(local.calidad_cancha))
	_rep.velocidad = 4.0


## Gesto de la persona que muestra la clave `clave` en este cuadro, o -1.
func _gesto_de(clave: int) -> int:
	for p in _vista._personas.values():
		var j := p as Jugador3D
		if j.visible and j.clave_motor == clave:
			return j.gesto
	return -1


## Gestos de los que se ven, por equipo: {true: [...], false: [...]}.
func _gestos_por_equipo() -> Dictionary:
	var por := {true: [], false: []}
	var locales := {}
	for j in _vista._jugadores_cuadro:
		locales[int(j["id"])] = bool(j["equipo_local"])
	for p in _vista._personas.values():
		var j := p as Jugador3D
		if j.visible and j.clave_motor >= 0 and locales.has(j.clave_motor):
			(por[locales[j.clave_motor]] as Array).append(j.gesto)
	return por


func _cuadro() -> void:
	_cuadros += 1
	if _cuadros > 20000:
		_ok(false, "el partido reproducido llega a todos los momentos (se cortó en la fase %d)" % _fase)
		_terminar()
		return
	if _cuadros == 1:
		_armar_partido()
	if _cuadros < 3:
		return
	var G := Jugador3D.Gesto
	var t := _vista._tiempo_reproduccion
	match _fase:
		0:
			_rep.posicion = 22.0
			_fase = 1
		1:
			# Cae en el 24 (acción de 5 ticks): el 8 local.
			if t >= 25.0:
				_ok(_gesto_de(8) == G.DOLOR, "el que cae por la falta del tick 24 pone cara de dolor (%d)" % _gesto_de(8))
				_rep.posicion = 90.0
				_fase = 2
		2:
			if t >= 91.0 and t < 92.0:
				_vistos["antes"] = _gesto_de(5)
			if t >= 95.0:
				_ok(int(_vistos.get("antes", -1)) in [G.NORMAL, G.PARPADEO], "antes de lesionarse, el 5 tiene cara normal (%d)" % int(_vistos.get("antes", -1)))
				_ok(_gesto_de(5) == G.DOLOR, "el 5 se lesiona en el tick 93 y pone cara de dolor (%d)" % _gesto_de(5))
				_rep.posicion = 108.0
				_fase = 3
		3:
			# Gol visitante en el 112: el festejo congela la reproducción ahí.
			if _rep._idx_congelado == 112:
				_espera += 1
				if _espera == 5:
					var por := _gestos_por_equipo()
					_ok(not por[false].is_empty() and (por[false] as Array).all(func(g): return g == G.FELIZ),
						"gol visitante: todos los visitantes que se ven, felices %s" % str(por[false]))
					# El 5 lesionado sigue con dolor si todavía está en la cancha.
					var locales := (por[true] as Array).filter(func(g): return g != G.DOLOR)
					_ok(not locales.is_empty() and locales.all(func(g): return g == G.TRISTE),
						"gol visitante: los locales, tristes %s" % str(por[true]))
			elif _espera >= 5 and _rep._idx_congelado == -1:
				# Terminado el festejo, la reproducción sigue desde el saque.
				_vistos["saque"] = t
				_fase = 4
		4:
			var hasta: float = _datos["goles"][0][1]
			if t <= hasta - 1.0:
				var por := _gestos_por_equipo()
				_vistos["tras_saque"] = (por[false] as Array).all(func(g): return g == G.FELIZ)
			elif t > hasta + 1.0:
				_ok(bool(_vistos.get("tras_saque", false)), "después del saque del medio siguen felices hasta el tick %.0f" % hasta)
				var por := _gestos_por_equipo()
				_ok((por[false] as Array).all(func(g): return g in [G.NORMAL, G.PARPADEO, G.DOLOR]),
					"pasado ese rato, los visitantes vuelven a la cara normal %s" % str(por[false]))
				_rep.posicion = 183.0
				_espera = 0
				_fase = 5
		5:
			# Gol local en el 186.
			if _rep._idx_congelado == 186:
				_espera += 1
				if _espera == 5:
					var por := _gestos_por_equipo()
					var locales := (por[true] as Array).filter(func(g): return g != G.DOLOR)
					_ok(not locales.is_empty() and locales.all(func(g): return g == G.FELIZ),
						"gol local: los locales, felices %s" % str(por[true]))
					_ok(not por[false].is_empty() and (por[false] as Array).all(func(g): return g == G.TRISTE),
						"gol local: los visitantes, tristes %s" % str(por[false]))
					_terminar()
