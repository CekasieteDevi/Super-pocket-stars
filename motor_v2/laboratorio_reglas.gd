extends Control

## Laboratorio de las reglas, etapa 6 de docs/motor_v2.md: un partido de 90
## minutos con reglas (CanchitaV2Nativa con configurar_reglas) dibujado con
## los Jugador3D del partido (VistaV2). Se ve cada reanudación con el que saca
## llegando a la pelota, las faltas, las tarjetas, el offside, los cambios
## (el que sale camina hasta afuera) y el segundo tiempo con los lados
## cambiados (PartidoVistoV2 gira la cancha).
##
## Con pantalla: arriba a la izquierda el reloj, el marcador, la parada y lo
## último que pasó. Una tecla o un toque: "R" arma otro partido con la semilla
## siguiente; las flechas apuran (x1, x4, x16) para llegar al segundo tiempo.
## Sin pantalla (--headless): simula `segundos=N` (300) con la vista
## dibujando, imprime con [lab_reglas] lo que contó y cuánto costó, y sale.
## Argumentos (después de `--`): `semilla=N`, `segundos=N`, `tanda`, `guion`,
## `solo=<texto>` y `capturas=<carpeta>`.
##
## Con `guion` (la escena laboratorio_reanudaciones.tscn): el partido no espera
## a que pasen las cosas. Fuerza una escena atrás de la otra (ESCENAS) con
## CanchitaV2Nativa.forzar_*, que cortan el juego con las mismas funciones del
## partido. La escena siguiente entra cuando la parada se sacó y se jugaron
## JUEGO_ENTRE_ESCENAS_SEG. "N" pasa a la siguiente ya; "R" empieza de nuevo.
## La falta espera un cruce de verdad (el que lleva la pelota con un rival
## encima): mientras tanto el texto dice "esperando un cruce".
##
## Con `solo` (laboratorio_roja.tscn usa "roja"): el guion tiene solo las
## escenas con ese texto en el nombre y, cuando termina, arma otro partido y
## las repite. Con `capturas`, guarda una imagen cada CAPTURA_CADA_SEG desde
## la primera escena forzada y sale a los CAPTURA_DURA_SEG.
##
## El árbitro (ArbitroV2) corre hasta el jugador y le muestra la tarjeta. La
## cámara se queda con el jugador hasta que la muestra. Con roja, el expulsado
## sale corriendo y la cámara lo sigue hasta la línea. Después el motor corta
## al saque, con cada uno en su lugar (como el motor espacial). Arriba se ve además un rectángulo del color de la tarjeta
## durante TARJETA_SEG. Mientras alguien sale de la cancha (expulsado,
## lesionado o cambiado) la cámara lo sigue a él, y después al que entra, en
## vez de a la pelota. El saque espera a que salga.

const PREFIJO := "[lab_reglas]"
const PASO_SEG := 1.0 / 60.0
const SEMILLA := 20261010
const VELOCIDADES := [1, 4, 16]
const NOMBRE_EVENTO := {"saque": "saque", "gol": "GOL", "falta": "falta", "amarilla": "amarilla", "roja": "ROJA",
	"offside": "offside", "lesion": "lesión", "cambio": "cambio", "fin_tiempo": "fin del tiempo",
	"penal_tanda": "penal de la tanda"}
const NOMBRE_PARADA := {"nada": "", "saque_medio": "saque del medio", "lateral": "lateral", "saque_arco": "saque de arco",
	"corner": "córner", "tiro_libre": "tiro libre", "penal": "penal"}

## El tiro libre del guion va a esta distancia del arco, casi de frente: ahí
## MotorEspacial.tipo_de_falta lo hace directo y se arma la barrera.
const TIRO_LIBRE_M := 22.0
## El guion: qué se fuerza y para quién (0 local, 1 visitante).
const ESCENAS := [
	{"nombre": "córner del local", "que": "corner", "equipo": 0, "lado": 1.0},
	{"nombre": "tiro libre con barrera del local", "que": "tiro_libre", "equipo": 0, "lado": 1.0},
	{"nombre": "penal del local (gol o atajada)", "que": "penal", "equipo": 0},
	{"nombre": "falta con amarilla", "que": "falta", "tarjeta": 1},
	{"nombre": "falta con roja: el árbitro la muestra, el expulsado sale y se corta al saque", "que": "falta", "tarjeta": 2},
	{"nombre": "falta con lesión: sale el lesionado y entra el cambio", "que": "falta", "tarjeta": 0, "lesion": true},
	{"nombre": "lateral del visitante", "que": "lateral", "equipo": 1, "lado": -1.0},
	{"nombre": "entretiempo: cambian de lado", "que": "fin_tiempo"},
	{"nombre": "córner del visitante (segundo tiempo)", "que": "corner", "equipo": 1, "lado": -1.0},
	{"nombre": "tiro libre con barrera del visitante", "que": "tiro_libre", "equipo": 1, "lado": -1.0},
	{"nombre": "penal del visitante (gol o atajada)", "que": "penal", "equipo": 1},
]
## Juego suelto entre dos escenas: alcanza para ver cómo sigue la jugada.
const JUEGO_ENTRE_ESCENAS_SEG := 5.0
## Juego antes de la primera escena, para que el saque del medio se vea.
const JUEGO_ANTES_SEG := 4.0

## Cuánto se ve la tarjeta arriba.
const TARJETA_SEG := 3.0
## Cuánto sigue la cámara al que sale antes de pasar al que entra.
const MIRA_AL_QUE_SALE_SEG := 4.0
## Cuánto sigue al que entra.
const MIRA_AL_QUE_ENTRA_SEG := 6.0
## Cuánto se acerca la cámara mientras el árbitro muestra la tarjeta.
const ACERCAMIENTO_TARJETA := 1.9

const CAPTURA_CADA_SEG := 0.5
const CAPTURA_DURA_SEG := 13.0

## Con el guion: fuerza las reanudaciones una atrás de la otra.
@export var guion := false
## Con el guion: solo las escenas con este texto en el nombre, repetidas.
@export var solo := ""

var _escenas: Array = ESCENAS
var _capturas := ""
var _capturadas := 0
## Paso en que se forzó la primera escena (-1 si todavía no).
var _forzada_en := -1

var _escena := -1
var _libre_seg := 0.0
## Pasos avanzados: el `paso` de los eventos del partido cuenta igual.
var _pasos := 0
var _tarjeta: ColorRect
var _tarjeta_seg := float(FisicaV2.parametros_reglas()["tarjeta_seg"])
var _partido: Object
var _visto: PartidoVistoV2
var _vista: VistaV2
var _etiqueta: Label
var _semilla := SEMILLA
var _tanda := false
var _acumulado := 0.0
var _velocidad := 0
var _composicion := PackedInt32Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var segundos := 300.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("segundos="):
			segundos = float(arg.get_slice("=", 1))
		elif arg.begins_with("semilla="):
			_semilla = int(arg.get_slice("=", 1))
		elif arg == "tanda":
			_tanda = true
		elif arg == "guion":
			guion = true
		elif arg.begins_with("solo="):
			guion = true
			solo = arg.get_slice("=", 1)
		elif arg.begins_with("capturas="):
			_capturas = arg.get_slice("=", 1)
	if solo != "":
		_escenas = ESCENAS.filter(func(e): return solo in str(e["nombre"]))
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		_armar()
		await get_tree().process_frame
		_medir(segundos)
		get_tree().quit()
		return
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(16, 16)
	_etiqueta.add_theme_font_size_override("font_size", 22)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 6)
	_armar()
	add_child(_etiqueta)
	_tarjeta = ColorRect.new()
	_tarjeta.size = Vector2(70, 100)
	_tarjeta.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tarjeta.position = Vector2(size.x * 0.5 - 35.0, 24.0)
	_tarjeta.visible = false
	add_child(_tarjeta)


func _armar() -> void:
	_partido = CerebroV2.armar_partido(_semilla, "", "", -1, -1, true, _tanda)
	_visto = PartidoVistoV2.new(_partido)
	_composicion = PackedInt32Array()
	_escena = -1
	_pasos = 0
	_forzada_en = -1
	_libre_seg = JUEGO_ENTRE_ESCENAS_SEG - JUEGO_ANTES_SEG
	_rearmar_vista()


## Un paso del partido. Con el guion, cuenta el juego suelto y fuerza la
## escena que sigue cuando toca.
func _paso() -> void:
	_partido.avanzar()
	_pasos += 1
	if not guion:
		return
	if str(_partido.get_estado()["parada"]) != "nada":
		_libre_seg = 0.0
		return
	_libre_seg += PASO_SEG
	if _libre_seg < JUEGO_ENTRE_ESCENAS_SEG:
		return
	if _escena < _escenas.size() - 1:
		_forzar_siguiente()
	elif solo != "" and _etiqueta != null:
		# Terminó: otro partido con las mismas escenas.
		_semilla += 1
		_armar()


func _forzar_siguiente() -> void:
	if _escena >= _escenas.size() - 1:
		return
	var e: Dictionary = _escenas[_escena + 1]
	var hecho := false
	match str(e["que"]):
		"falta":
			hecho = _partido.forzar_falta(int(e["tarjeta"]), bool(e.get("lesion", false)))
		"fin_tiempo":
			hecho = _partido.forzar_fin_de_tiempo()
		_:
			var equipo := int(e["equipo"])
			var ataca := 1.0 if equipo == 0 else -1.0
			var pos := Vector2(ataca * (ProyeccionPartido.MEDIO_LARGO - TIRO_LIBRE_M), 3.0 * float(e.get("lado", 1.0)))
			hecho = _partido.forzar_parada(str(e["que"]), equipo, pos)
	# Si no se pudo (hay una parada en curso), se prueba de nuevo en el paso que sigue.
	if hecho:
		_escena += 1
		_libre_seg = 0.0
		if _forzada_en < 0:
			_forzada_en = _pasos


## La vista tiene un Jugador3D por cada uno: si alguien entra o se va, se arma
## de nuevo con los que hay.
func _rearmar_vista() -> void:
	_visto.actualizar()
	var ids := _visto.ids()
	if ids == _composicion and _vista != null:
		return
	_composicion = ids
	var vieja := _vista
	_vista = VistaV2.new()
	_vista.equipos = _visto.equipos()
	_vista.arqueros = _visto.arqueros()
	_vista.ids = ids
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vista)
	# Atrás de todo: la vieja y el texto quedan arriba.
	move_child(_vista, 0)
	if vieja != null:
		# La vista nueva sigue donde estaba la vieja. Armada de cero, la
		# cámara saltaba al medio de la cancha y el árbitro volvía a su lugar
		# del saque justo cuando el expulsado dejaba de ser uno de los que juegan.
		_vista.seguir_de(vieja)
		_soltar(vieja)


## La vista vieja tapa a la nueva hasta que la nueva dibujó su primer cuadro.
## Sacada enseguida, la pantalla quedaba gris un cuadro.
func _soltar(vieja: VistaV2) -> void:
	if _etiqueta != null:
		await get_tree().process_frame
		await get_tree().process_frame
	vieja.queue_free()


func _process(delta: float) -> void:
	if _etiqueta == null:
		return
	_acumulado += delta * VELOCIDADES[_velocidad]
	var pasos := 0
	while _acumulado >= PASO_SEG and pasos < 4 * VELOCIDADES[_velocidad]:
		_paso()
		_acumulado -= PASO_SEG
		pasos += 1
	_acumulado = minf(_acumulado, PASO_SEG)
	_rearmar_vista()
	_vista.foco = _foco()
	_vista.acercamiento = ACERCAMIENTO_TARJETA if _con_tarjeta() else 1.0
	_vista.dibujar_canchita(_visto, _acumulado / PASO_SEG, delta)
	_etiqueta.text = _texto()
	_mostrar_tarjeta()
	_capturar()


## Con `capturas`: una imagen cada CAPTURA_CADA_SEG de partido desde la primera
## escena forzada; a los CAPTURA_DURA_SEG sale.
func _capturar() -> void:
	if _capturas == "" or _forzada_en < 0:
		return
	var desde := float(_pasos - _forzada_en) * PASO_SEG
	if desde >= float(_capturadas) * CAPTURA_CADA_SEG:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/captura_%02d.png" % [_capturas, _capturadas])
		_capturadas += 1
	if desde > CAPTURA_DURA_SEG:
		get_tree().quit()


## Segundos desde el último evento de uno de `tipos`, y el evento; [INF, {}] si no hubo.
func _ultimo_evento(tipos: Array) -> Array:
	var eventos: Array = _partido.eventos()
	for k in range(eventos.size() - 1, -1, -1):
		if eventos[k]["tipo"] in tipos:
			return [float(_pasos - int(eventos[k]["paso"])) * PASO_SEG, eventos[k]]
	return [INF, {}]


## Adónde mira la cámara: al que sale de la cancha y después al que entra por
## él; null (la pelota) si no sale nadie.
func _foco() -> Variant:
	var ids := _visto.ids()
	var pos := _visto.get_pos()
	# Primero la tarjeta: la cámara se queda en la jugada (donde fue la falta)
	# mientras el árbitro llega y la muestra. Yendo al árbitro saltaba y no
	# se veía la falta.
	if _con_tarjeta():
		return _visto.get_tarjeta()["pos"]
	var cambio := _ultimo_evento(["cambio"])
	if float(cambio[0]) > MIRA_AL_QUE_SALE_SEG and float(cambio[0]) < MIRA_AL_QUE_SALE_SEG + MIRA_AL_QUE_ENTRA_SEG:
		var entra := ids.find(int(cambio[1]["otro"]))
		if entra >= 0:
			return pos[entra]
	# El expulsado: hasta el corte al saque. El cambiado: MIRA_AL_QUE_SALE_SEG.
	var sale := _ultimo_evento(["roja", "cambio"])
	var expulsado: bool = sale[1].get("tipo", "") == "roja" and int(_partido.get_estado()["corte"]) < int(sale[1]["paso"])
	if expulsado or (sale[1].get("tipo", "") == "cambio" and float(sale[0]) <= MIRA_AL_QUE_SALE_SEG):
		var i := ids.rfind(int(sale[1]["jugador"]))
		if i >= _partido.cantidad():
			return pos[i]
	return null


## El árbitro está yendo a mostrar una tarjeta o mostrándola.
func _con_tarjeta() -> bool:
	var tarjeta := _visto.get_tarjeta()
	return not tarjeta.is_empty() and float(_pasos - int(tarjeta["paso"])) * PASO_SEG < _tarjeta_seg


func _mostrar_tarjeta() -> void:
	var ultima := _ultimo_evento(["amarilla", "roja"])
	_tarjeta.visible = float(ultima[0]) < TARJETA_SEG
	if _tarjeta.visible:
		_tarjeta.color = Color(0.9, 0.1, 0.1) if ultima[1]["tipo"] == "roja" else Color(1.0, 0.85, 0.1)
		_tarjeta.position = Vector2(size.x * 0.5 - 35.0, 24.0)


func _texto() -> String:
	var e: Dictionary = _partido.get_estado()
	var k: Dictionary = _partido.contadores()
	var goles: PackedInt32Array = _partido.get_goles()
	var reloj := float(e["reloj"]) + (45.0 * 60.0 if e["periodo"] != "primer_tiempo" else 0.0)
	var t := "Semilla %d · %s %d:%02d (+%d) · x%d (R: otro, flechas: velocidad)\n" % [_semilla, e["periodo"],
		int(reloj) / 60, int(reloj) % 60, int(float(e["adicion"]) / 60.0), VELOCIDADES[_velocidad]]
	if guion:
		if _escena < 0:
			t += "Guion: saque del medio (N: escena siguiente)\n"
		else:
			t += "Guion %d/%d: %s%s\n" % [_escena + 1, _escenas.size(), _escenas[_escena]["nombre"],
				" · fin del guion (R: de nuevo)" if _escena == _escenas.size() - 1 else " (N: siguiente)"]
		if _escena < _escenas.size() - 1 and _escenas[_escena + 1]["que"] == "falta" and e["parada"] == "nada" \
				and _libre_seg >= JUEGO_ENTRE_ESCENAS_SEG:
			t += "Sigue: %s · esperando un cruce\n" % _escenas[_escena + 1]["nombre"]
	t += "Local %d - %d Visitante" % [goles[0], goles[1]]
	if e["periodo"] == "tanda" or Vector2i(e["pateados_tanda"]) != Vector2i.ZERO:
		t += " · penales %d-%d" % [Vector2i(e["goles_tanda"]).x, Vector2i(e["goles_tanda"]).y]
	var parada: String = NOMBRE_PARADA.get(str(e["parada"]), "")
	t += (" · " + parada) if parada != "" else ""
	t += "\nfaltas %d-%d · amarillas %d-%d · rojas %d-%d · offside %d-%d · cambios %d-%d\n" % [k["faltas_0"], k["faltas_1"],
		k["amarillas_0"], k["amarillas_1"], k["rojas_0"], k["rojas_1"], k["offsides_cobrados_0"],
		k["offsides_cobrados_1"], k["cambios_0"], k["cambios_1"]]
	var eventos: Array = _partido.eventos().filter(func(v): return v["tipo"] != "saque")
	for v in eventos.slice(maxi(0, eventos.size() - 5)):
		var minuto := int(float(v["paso"]) * PASO_SEG / 60.0)
		t += "%d' %s (%s)\n" % [minuto, NOMBRE_EVENTO.get(str(v["tipo"]), v["tipo"]),
			"local" if int(v["equipo"]) == 0 else "visitante"]
	return t


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed:
		if evento.keycode == KEY_RIGHT:
			_velocidad = mini(_velocidad + 1, VELOCIDADES.size() - 1)
			return
		if evento.keycode == KEY_LEFT:
			_velocidad = maxi(_velocidad - 1, 0)
			return
		if evento.keycode == KEY_N and guion:
			_forzar_siguiente()
			return
		if evento.keycode != KEY_R:
			return
	elif not (evento.is_pressed() and (evento is InputEventMouseButton or evento is InputEventScreenTouch)):
		return
	_semilla += 1
	_armar()


## Sin pantalla: la vista se dibuja igual (sin mostrarse) para ver que no se
## rompe con los que entran y salen y medir el costo.
func _medir(segundos: float) -> void:
	var reloj := Time.get_ticks_usec()
	var armadas := 0
	var n := int(segundos / PASO_SEG)
	for k in n:
		_paso()
		var antes := _composicion
		_rearmar_vista()
		if _composicion != antes:
			armadas += 1
		_vista.foco = _foco()
		_vista.dibujar_canchita(_visto, 1.0, PASO_SEG)
	var ms := float(Time.get_ticks_usec() - reloj) / 1000.0 / float(n)
	var k: Dictionary = _partido.contadores()
	var e: Dictionary = _partido.get_estado()
	print("%s %.0f s (%.2f ms por paso con la vista): %s reloj %.0f s, goles %d-%d, laterales %d, faltas %d, cambios %d, vista armada %d veces, correcciones %d" % [
		PREFIJO, segundos, ms, e["periodo"], e["reloj"], k["goles_0"], k["goles_1"], k["saques_lateral"],
		int(k["faltas_0"]) + int(k["faltas_1"]), int(k["cambios_0"]) + int(k["cambios_1"]), armadas,
		k["correcciones"]])
	if guion:
		var tipos := {}
		for v in _partido.eventos():
			var clave := str(v["tipo"])
			if clave == "saque":
				clave += "_" + str(v["detalle"])
			tipos[clave] = int(tipos.get(clave, 0)) + 1
		print("%s guion: escena %d de %d, penales %d, peor salto de un cuerpo %.2f m, eventos %s" % [PREFIJO, _escena + 1,
			_escenas.size(), k["penales"], k["peor_salto_cuerpo_m"], tipos])
