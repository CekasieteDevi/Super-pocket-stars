extends SceneTree

## Etapa 2 del Motor V2 (docs/motor_v2.md): la vista (VistaV2) elige los
## clips de una vez con lo que busca el cuerpo (CuerposV2Nativos).
## Un jugador parado mira atrás, sale picando 25 m y llega frenando:
## - lo que busca el cuerpo (giro que falta, metros para parar, rapidez) se lee
##   bien desde GDScript;
## - la vista hace Giro_180, Arranque, Correr y Frenada, en ese orden;
## - el pie apoyado casi no patina en ninguno (como DetectorPatinaV2: a menos
##   de 1,5 cm del punto más bajo del pie en ese clip).
## Otro pica y, a su punta, le piden volver: da Media_Vuelta y sigue con
## Correr, sin pasar por Correr_Espaldas ni de costado.
## Uno conduce a 5 m/s tocando la pelota cada 0,75 s (Control_Corriendo,
## hecho en el lugar) y el arquero se corre de costado a 1 m/s: el pie
## apoyado no patina lo que avanza el cuerpo (las piernas van con la
## carrera, Jugador3D.piernas_de, y el arquero no se desliza en guardia).
## Con el gesto entero el toque daba 28% y el arquero en guardia, 200%.
## El arquero que se tira y sigue jugando se levanta con Arquero_Levanta.
## Uno anda de costado mirando lejos y después corre hacia donde iba, y otro
## camina: el pie apoyado queda clavado (Jugador3D.clavar_pies) y el modelo
## gira los 90° junto con el fundido. Sin eso, de costado deslizaba el 5% y
## 0,89 m en cada cambio a correr, y caminando el 27% (ahora 3%).
## En el fundido de un paso de costado a uno hacia adelante los pies no quedan
## más abajo que en los dos clips (Jugador3D._fundir): con eso el cambio pasa
## de 0,19 m a 0,02.
## Uno camina, frena y mira al costado: entra al Giro_90 todavía andando y los
## pies no saltan (el giro entra con fundido). Otro pica y frena: la Frenada
## no entra en medio del fundido de Correr a Trotar.
## Uno conduce girando 115° por segundo: el pie de apoyo del toque queda
## clavado y la pierna que tocó vuelve a la carrera por el aire.
## Las variantes que elige la vista (Cabecear_Corriendo, Volea_Costado) duran
## y tocan como el clip del motor, y Control_Muslo es el clip del muslo.

const SEED := 20260930
const PASO := 1.0 / 60.0
const JUGADOR := 3
const PIQUE := 6
const CONDUCE := 8
const ARQUERO := 11
const DE_COSTADO := [14, 17, 20]
const CAMINA := 16
const GIRA := 2
const FRENA := 5
const CONDUCE_GIRANDO := 9
const VARIANTE := 1
const FUNDE := 19
const APOYO_M := DetectorPatinaV2.APOYO_M

var fallos := 0


func _init() -> void:
	if not ClassDB.class_exists("CuerposV2Nativos"):
		_ok(false, "la extensión motor_v2 está armada para esta plataforma (motor_v2/bin)")
		print("FALLOS=%d" % fallos)
		quit(1)
		return
	var vista := VistaV2.new()
	vista.size = Vector2(640, 360)
	# Los que se miden andan lejos de donde mira la cámara.
	vista.clavar_fuera_de_camara = true
	root.add_child(vista)
	process_frame.connect(_probar.bind(vista), CONNECT_ONE_SHOT)


func _probar(vista: VistaV2) -> void:
	var c: Object = ClassDB.instantiate("CuerposV2Nativos")
	c.configurar(FisicaV2.parametros_cuerpo(), FisicaV2.clips())
	var fisico := FisicaV2.fisico_de({"velocidad": 80.0, "aceleracion": 80.0, "agilidad": 70.0})
	for i in MundoV2.JUGADORES:
		c.agregar(Vector2(-40.0 + 3.0 * i, 0.0), 0.0, fisico)
	var inicio: Vector2 = c.get_pos()[JUGADOR]
	var p3: Jugador3D = vista._jugadores[JUGADOR]
	var medida := {"previo": {}, "suelo": {}, "patina": {}, "metros": {}, "orden": []}
	_pasos(c, vista, 30, medida, JUGADOR)
	c.mirar_a(JUGADOR, inicio + Vector2(0.0, -10.0))
	_ok(absf(absf(c.get_giro_pendiente(JUGADOR)) - PI) < 0.01,
		"mirando atrás le falta media vuelta (%.1f°)" % rad_to_deg(c.get_giro_pendiente(JUGADOR)))
	_pasos(c, vista, 90, medida, JUGADOR)
	var destino := inicio + Vector2(0.0, -25.0)
	c.ir_a(JUGADOR, destino, 1.0, true)
	# Mira más allá del destino: despacio el cuerpo gira hacia donde mira.
	c.mirar_a(JUGADOR, inicio + Vector2(0.0, -40.0))
	_ok(absf(c.get_metros_para_parar(JUGADOR) - 25.0) < 0.01,
		"yendo a parar a 25 m le faltan %.2f m para parar" % c.get_metros_para_parar(JUGADOR))
	_ok(absf(c.get_rapidez_buscada(JUGADOR) - float(fisico["vel_max"])) < 0.01,
		"busca su punta (%.2f m/s)" % c.get_rapidez_buscada(JUGADOR))
	_pasos(c, vista, 480, medida, JUGADOR)
	_ok(c.get_rapidez()[JUGADOR] == 0.0 and c.get_pos()[JUGADOR].distance_to(destino) < 0.01, "llegó parado")
	var orden: Array = medida["orden"]
	var giro := orden.find("Giro_180_Izq") if orden.has("Giro_180_Izq") else orden.find("Giro_180_Der")
	var esperado := [giro, orden.find("Arranque"), orden.find("Correr"), orden.find("Frenada")]
	var en_orden := not esperado.has(-1)
	for k in range(1, esperado.size()):
		en_orden = en_orden and esperado[k] > esperado[k - 1]
	_ok(en_orden, "hace media vuelta, arranca, corre y frena, en ese orden (%s)" % [orden])
	_ok(p3._anim_actual == Cancha3D.ANIM_QUIETO, "termina quieto (%s)" % p3._anim_actual)
	var patina: Dictionary = medida["patina"]
	var metros: Dictionary = medida["metros"]
	for clip in patina:
		if clip.begins_with("Giro_"):
			# En el lugar: se compara con lo que barre un pie que gira con el
			# cuerpo sin clip (radio ~0,11 m, media vuelta: 0,35 m por pie).
			_ok(float(patina[clip]) < 0.3, "%s: el pie apoyado desliza %.2f m en toda la vuelta" % [clip, patina[clip]])
		elif clip in ["Arranque", "Correr", "Frenada"]:
			var r := float(patina[clip]) / maxf(float(metros.get(clip, 0.0)), 0.01)
			_ok(r < 0.15, "%s: el pie apoyado desliza el %.0f%% de lo que avanza el cuerpo (%.2f de %.2f m)"
				% [clip, 100.0 * r, patina[clip], metros.get(clip, 0.0)])
	_media_vuelta(c, vista)
	_de_costado_a_adelante(c, vista)
	_caminando(c, vista)
	_giro_andando(c, vista)
	_frenada_despues_del_fundido(c, vista)
	_pies_en_el_fundido(vista)
	_gestos_corriendo(vista)
	_gesto_girando(vista)
	_variantes(vista)
	_arquero_se_levanta(vista)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


## A su punta hacia +z, le piden volver a -z (sin frenar en el punto, como
## en los piques del laboratorio).
func _media_vuelta(c: Object, vista: VistaV2) -> void:
	var x: float = c.get_pos()[PIQUE].x
	c.ir_a(PIQUE, Vector2(x, 80.0), 1.0, false)
	var medida := {"previo": {}, "suelo": {}, "patina": {}, "metros": {}, "orden": []}
	_pasos(c, vista, 240, medida, PIQUE)
	c.ir_a(PIQUE, Vector2(x, -80.0), 1.0, false)
	medida["orden"] = []
	_pasos(c, vista, 240, medida, PIQUE)
	var orden: Array = medida["orden"]
	var vuelta := orden.find("Media_Vuelta_Izq") if orden.has("Media_Vuelta_Izq") else orden.find("Media_Vuelta_Der")
	_ok(vuelta >= 0 and orden.find("Correr", vuelta) > vuelta, "a su punta da la media vuelta y sigue corriendo (%s)" % [orden])
	var de_lado := orden.filter(func(a: String) -> bool: return a.begins_with("Correr_Costado") or a == "Correr_Espaldas")
	_ok(de_lado.is_empty(), "no corre de espaldas ni de costado para darse vuelta (%s)" % [de_lado])
	_ok(c.get_vel(PIQUE).y < -0.9 * c.get_rapidez_buscada(PIQUE), "termina corriendo al revés (%.1f m/s)" % c.get_vel(PIQUE).y)
	var p3: Jugador3D = vista._jugadores[PIQUE]
	_ok(absf(wrapf(p3.rotation.y - PI, -PI, PI)) < 0.2, "y el modelo mira hacia donde corre (%.0f°)" % rad_to_deg(p3.rotation.y))
	for clip in medida["patina"]:
		if clip.begins_with("Media_Vuelta"):
			var r := float(medida["patina"][clip]) / maxf(float(medida["metros"].get(clip, 0.0)), 0.01)
			_ok(r < 0.15, "%s: el pie apoyado desliza el %.0f%% de lo que recorre el cuerpo (%.2f de %.2f m)"
				% [clip, 100.0 * r, medida["patina"][clip], medida["metros"][clip]])


## Tres jugadores: cada uno anda de costado a 1,6 m/s mirando lejos (por
## debajo de rapidez_para_girar el cuerpo no gira hacia donde va) y sale al
## trote hacia donde iba. Mide con el detector PATINA, como el partido.
func _de_costado_a_adelante(c: Object, vista: VistaV2) -> void:
	var de_costado := DetectorPatinaV2.new()
	var cambio := DetectorPatinaV2.new()
	var metros_costado := 0.0
	var cambios := 0
	var miran := 0
	for j in DE_COSTADO:
		var p3: Jugador3D = vista._jugadores[j]
		var inicio: Vector2 = c.get_pos()[j]
		c.mirar_a(j, inicio + Vector2(0.0, 60.0))
		c.ir_a(j, inicio + Vector2(40.0, 0.0), 0.2, false)
		for k in 150:
			c.avanzar()
			vista.dibujar_cuerpos(c, 1.0, PASO, Vector2.ZERO)
			if k >= 60:
				de_costado.medir([p3], PASO)
				if p3._anim_actual == "Correr_Costado_Izq" and p3._mezcla >= 1.0:
					metros_costado += float(c.get_rapidez()[j]) * PASO
		c.ir_a(j, c.get_pos()[j] + Vector2(40.0, 0.0), 0.45, false)
		# El cambio: medio segundo desde que deja el clip de costado.
		var desde := -1
		for k in 120:
			c.avanzar()
			vista.dibujar_cuerpos(c, 1.0, PASO, Vector2.ZERO)
			if desde < 0 and p3._anim_actual != "Correr_Costado_Izq":
				desde = k
				cambios += 1
			if desde >= 0 and k - desde < 30:
				cambio.medir([p3], PASO)
		if absf(wrapf(p3.rotation.y - PI * 0.5, -PI, PI)) < 0.2:
			miran += 1
	var patina: float = (de_costado.por_clip.get("Correr_Costado_Izq", [0.0, 0.0]) as Array)[0]
	_ok(cambios == DE_COSTADO.size() and metros_costado > 5.0 and patina < 0.1 * metros_costado,
		"de costado el pie apoyado desliza el %.0f%% de lo que avanza el cuerpo (%.2f de %.2f m)"
		% [100.0 * patina / maxf(metros_costado, 0.01), patina, metros_costado])
	var total := 0.0
	for clip in cambio.por_clip:
		total += float(cambio.por_clip[clip][0])
	_ok(total / DE_COSTADO.size() < 0.1,
		"al girar de costado a adelante el pie apoyado desliza %.2f m por cambio" % (total / DE_COSTADO.size()))
	_ok(miran == DE_COSTADO.size(), "y el modelo queda mirando adonde fue (%d de %d)" % [miran, DE_COSTADO.size()])


## Sin motor ni pie clavado: uno anda de costado a 3,5 m/s y pasa a Trotar.
## La mezcla gira cada hueso a mitad de camino: con dos pasos cruzados el
## muslo queda más vertical que en los dos clips y el pie bajaba 3 a 5 cm. El
## pie del aire tocaba el piso en medio del giro de 90°: 13,7 cm patinados por
## cambio en un partido (tests/_diag_patina_partido_v2.gd).
func _pies_en_el_fundido(vista: VistaV2) -> void:
	var p3: Jugador3D = vista._jugadores[FUNDE]
	var escala := p3._esqueleto.global_transform.basis.y.length()
	var rapidez := 3.5
	var ciclos := 0.0
	# Unos cuadros de costado: el clip viejo sigue a su ritmo en el fundido.
	p3.poner("Correr_Costado_Izq", 0.0, -1.0)
	for k in 6:
		ciclos += rapidez * PASO / float(vista._metros_ciclo["Correr_Costado_Izq"])
		p3.poner("Correr_Costado_Izq", fposmod(ciclos, 1.0) * p3.duracion("Correr_Costado_Izq"), PASO)
	var peor := 0.0
	var cuadros := 0
	for k in 12:
		ciclos += rapidez * PASO / float(vista._metros_ciclo["Trotar"])
		p3.poner("Trotar", fposmod(ciclos, 1.0) * p3.duracion("Trotar"), PASO)
		if p3._mezcla >= 1.0:
			break
		cuadros += 1
		var vieja := p3._pose_de(p3._anim_vieja, p3._t_vieja)
		var nueva := p3._pose_de("Trotar", p3._t_actual)
		for pie in DetectorPatinaV2.PIES.size():
			var en_clips := minf(p3._pie_en_pose(vieja, pie).y, p3._pie_en_pose(nueva, pie).y)
			peor = maxf(peor, (en_clips - p3._pie_en_pose([], pie).y) * escala)
	_ok(cuadros >= 5 and peor < 0.005,
		"en el fundido de costado a adelante el pie no queda más abajo que en los dos clips (%.1f cm en %d cuadros)"
		% [peor * 100.0, cuadros])


## Camina 5 s a 1,6 m/s hacia donde mira, cambiando de rumbo 40° cada segundo
## (como el que acompaña la jugada).
func _caminando(c: Object, vista: VistaV2) -> void:
	var p3: Jugador3D = vista._jugadores[CAMINA]
	var detector := DetectorPatinaV2.new()
	var metros := 0.0
	for tramo in 6:
		var en: Vector2 = c.get_pos()[CAMINA]
		var hacia := Vector2(0.0, 40.0).rotated(deg_to_rad(40.0 if tramo % 2 == 0 else -40.0))
		c.mirar_a(CAMINA, en + hacia)
		c.ir_a(CAMINA, en + hacia, 0.2, false)
		for k in 60:
			c.avanzar()
			vista.dibujar_cuerpos(c, 1.0, PASO, Vector2.ZERO)
			if tramo == 0:
				continue
			detector.medir([p3], PASO)
			if p3._anim_actual == "Caminar" and p3._mezcla >= 1.0:
				metros += float(c.get_rapidez()[CAMINA]) * PASO
	var patina: float = (detector.por_clip.get("Caminar", [0.0, 0.0]) as Array)[0]
	_ok(metros > 5.0 and patina < 0.15 * metros, "caminando el pie apoyado desliza el %.0f%% de lo que avanza el cuerpo (%.2f de %.2f m)"
		% [100.0 * patina / maxf(metros, 0.01), patina, metros])


## Camina 4 m, llega frenando y mira a su izquierda: por debajo de
## VELOCIDAD_PARA_PIERNAS, todavía andando, entra al Giro_90. Sin fundido en
## la entrada, los pies saltaban 12 a 17 cm en ese cuadro, del paso del clip
## de andar a la pose parada del giro (29 de los 35 m que patinaba Giro_90 por
## partido, tests/_diag_patina_partido_v2.gd).
func _giro_andando(c: Object, vista: VistaV2) -> void:
	var p3: Jugador3D = vista._jugadores[GIRA]
	var inicio: Vector2 = c.get_pos()[GIRA]
	var detector := DetectorPatinaV2.new()
	c.mirar_a(GIRA, inicio + Vector2(0.0, 40.0))
	c.ir_a(GIRA, inicio + Vector2(0.0, 4.0), 0.2, true)
	var entro_andando := false
	var peor := 0.0
	var antes := {}
	var camino := false
	var miro := false
	for k in 300:
		# Mira al costado recién cuando deja de mover las piernas: girando antes, llega
		# parado y ya girado.
		var v: float = c.get_rapidez()[GIRA]
		camino = camino or v > 1.0
		if camino and not miro and v < Cancha3D.VELOCIDAD_PARA_PIERNAS + 0.05:
			miro = true
			c.mirar_a(GIRA, c.get_pos()[GIRA] + Vector2(40.0, 0.0))
		c.avanzar()
		var clip_antes := p3._anim_actual
		vista.dibujar_cuerpos(c, 1.0, PASO, Vector2.ZERO)
		var gira := p3._anim_actual.begins_with("Giro_90")
		if gira and not clip_antes.begins_with("Giro_90"):
			entro_andando = entro_andando or float(c.get_rapidez()[GIRA]) > 0.05
			# El cuadro en que entra: cuánto se mueve cada pie que está en el piso.
			for pie in DetectorPatinaV2.PIES:
				var q := DetectorPatinaV2.ancla_de(p3, pie)
				if antes.has(pie) and q.y <= p3.suelo_de(p3._anim_actual) + APOYO_M * 2.0:
					peor = maxf(peor, Vector2(q.x - antes[pie].x, q.z - antes[pie].z).length())
		for pie in DetectorPatinaV2.PIES:
			antes[pie] = DetectorPatinaV2.ancla_de(p3, pie)
		detector.medir([p3], PASO)
	var patina := 0.0
	for clip in detector.por_clip:
		if str(clip).begins_with("Giro_90"):
			patina += float(detector.por_clip[clip][0])
	_ok(entro_andando and peor < 0.05 and patina < 0.1,
		"el que frena y gira entra al Giro_90 andando sin que salten los pies (%.2f m en ese cuadro, %.2f m en el giro)"
		% [peor, patina])


## Pica 14 m y llega frenando: pasa de Correr a Trotar a 4 m/s y la Frenada
## entra a 3,6. Entrando en medio de ese fundido, fundía desde una pose
## congelada (302 de 396 veces por partido: 15,6 m patinados).
func _frenada_despues_del_fundido(c: Object, vista: VistaV2) -> void:
	var p3: Jugador3D = vista._jugadores[FRENA]
	var inicio: Vector2 = c.get_pos()[FRENA]
	c.mirar_a(FRENA, inicio + Vector2(0.0, 40.0))
	c.ir_a(FRENA, inicio + Vector2(0.0, 14.0), 1.0, true)
	var entradas := 0
	var congeladas := 0
	for k in 360:
		c.avanzar()
		var clip_antes := p3._anim_actual
		vista.dibujar_cuerpos(c, 1.0, PASO, Vector2.ZERO)
		if p3._anim_actual == "Frenada" and clip_antes != "Frenada":
			entradas += 1
			if p3._anim_vieja == "":
				congeladas += 1
	_ok(entradas >= 1 and congeladas == 0,
		"la Frenada entra con el clip de andar entero, no en medio de otro fundido (%d entradas, %d desde una pose congelada)"
		% [entradas, congeladas])


## Sin motor: uno conduce a 5 m/s girando 2 rad/s (el que encara doblando)
## y toca cada 0,75 s. Mide el pie de la pierna que es de la carrera, contra
## el suelo de su clip de andar. Sin clavarlo debajo del gesto deslizaba 0,22 m
## en este recorrido (el 3% de lo que avanza el cuerpo); en un partido, con el
## modelo girando hacia la pelota, el 43%.
func _gesto_girando(vista: VistaV2) -> void:
	var n := vista._cantidad()
	var pos := PackedVector2Array()
	var rumbo := PackedFloat32Array()
	var rapidez := PackedFloat32Array()
	for i in n:
		var p := vista._jugadores[i].position
		pos.append(Vector2(p.x, p.z))
		rumbo.append(0.0)
		rapidez.append(0.0)
	pos[CONDUCE_GIRANDO] = Vector2(0.0, 20.0)
	rapidez[CONDUCE_GIRANDO] = 5.0
	var p3: Jugador3D = vista._jugadores[CONDUCE_GIRANDO]
	var dur := p3.duracion("Control_Corriendo")
	var metros := 0.0
	var patina := 0.0
	var clavado := 0
	var antes := {}
	for k in 360:
		var previa := pos.duplicate()
		rumbo[CONDUCE_GIRANDO] = wrapf(float(rumbo[CONDUCE_GIRANDO]) + 2.0 * PASO, -PI, PI)
		pos[CONDUCE_GIRANDO] += Vector2(sin(rumbo[CONDUCE_GIRANDO]), cos(rumbo[CONDUCE_GIRANDO])) * 5.0 * PASO
		var acciones := []
		for i in n:
			acciones.append(["", 0.0])
		var t := fmod(k * PASO, 0.75)
		if t < dur:
			acciones[CONDUCE_GIRANDO] = ["Control_Corriendo", t]
		vista._dibujar_jugadores(previa, pos, rumbo, rapidez, acciones, 1.0, PASO)
		var en_gesto := k >= 60 and p3._anim_actual == "Control_Corriendo" and p3._mezcla >= 1.0
		if en_gesto:
			metros += 5.0 * PASO
		for j in DetectorPatinaV2.PIES.size():
			var q := DetectorPatinaV2.ancla_de(p3, DetectorPatinaV2.PIES[j])
			if en_gesto and antes.has(j) and p3.peso_carrera(j) >= 0.99 \
					and minf(q.y, antes[j].y) <= p3.suelo_del_pie(j) + APOYO_M:
				patina += Vector2(q.x - antes[j].x, q.z - antes[j].z).length()
				if p3._pie_clavado[j]:
					clavado += 1
			antes[j] = q
	_ok(metros > 5.0 and clavado > 10 and patina < 0.015 * metros,
		"conduciendo a 5 m/s y girando, en el toque el pie de apoyo queda clavado y desliza el %.1f%% de lo que avanza el cuerpo (%.2f de %.2f m)"
		% [100.0 * patina / maxf(metros, 0.01), patina, metros])
	# El ajuste de pie con medio peso lleva el pie a mitad de camino. Antes lo
	# llevaba entero con cualquier peso y, al terminar el ajuste, el pie
	# volvía de golpe (30 a 55 cm en un cuadro).
	p3.poner("Control_Corriendo", 0.125, -1.0)
	var pie := p3.ancla_de_pose("Pie_R")
	var meta := pie + p3.global_transform.basis * Vector3(0.0, 0.05, 0.2)
	p3.llevar_pie("Pie_R", meta, 0.5)
	var medio := p3.ancla_de_pose("Pie_R")
	p3.poner("Control_Corriendo", 0.125, -1.0)
	p3.llevar_pie("Pie_R", meta, 1.0)
	var entero := p3.ancla_de_pose("Pie_R")
	_ok(medio.distance_to(pie.lerp(meta, 0.5)) < 0.03 and entero.distance_to(meta) < 0.05,
		"el ajuste de pie con medio peso lleva el pie a mitad de camino (queda a %.2f m de la mitad; con el peso entero, a %.2f m de la pelota)"
		% [medio.distance_to(pie.lerp(meta, 0.5)), entero.distance_to(meta)])


## Las variantes de la vista y el clip del muslo: los datos coinciden con
## los del clip del motor y la vista elige la variante cuando corresponde.
func _variantes(vista: VistaV2) -> void:
	var clips := FisicaV2.clips()
	var p3: Jugador3D = vista._jugadores[VARIANTE]
	var bien := true
	for nombre in VistaV2.VARIANTES:
		var v: String = VistaV2.VARIANTES[nombre]
		bien = bien and vista._variantes.get(nombre, "") == v and p3.tiene(v) and clips.has(v) \
			and str(clips[v]["ancla"]) == str(clips[nombre]["ancla"])
	_ok(bien, "las variantes de la vista están en el GLB y duran y tocan como el clip del motor (%s)" % [vista._variantes])
	# Cerca del arco de x positivo y mirándolo (el rumbo PI/2 mira a +x).
	var en := Vector2(40.0, 0.0)
	var al_arco := PI * 0.5
	var quieto := vista._clip_mostrado(VARIANTE, "Cabecear", al_arco, 0.5, Vector3.ZERO, en)
	vista._clip_mostrado(VARIANTE, "", 0.0, 0.0, Vector3.ZERO, en)
	var corriendo := vista._clip_mostrado(VARIANTE, "Cabecear", al_arco, 4.0, Vector3.ZERO, en)
	# Ya empezado, el gesto no cambia de clip aunque el cuerpo frene.
	var sigue := vista._clip_mostrado(VARIANTE, "Cabecear", al_arco, 0.2, Vector3.ZERO, en)
	vista._clip_mostrado(VARIANTE, "", 0.0, 0.0, Vector3.ZERO, en)
	_ok(quieto == "Cabecear" and corriendo == "Cabecear_Corriendo" and sigue == "Cabecear_Corriendo",
		"cabecea en carrera el que llega corriendo (%s parado, %s a 4 m/s, %s al frenar)" % [quieto, corriendo, sigue])
	var de_frente := vista._clip_mostrado(VARIANTE, "Volea", al_arco, 2.0, Vector3(-0.2, 0.0, 0.0), en)
	vista._clip_mostrado(VARIANTE, "", 0.0, 0.0, Vector3.ZERO, en)
	var cruzada := vista._clip_mostrado(VARIANTE, "Volea", al_arco, 2.0, Vector3(-0.05, 0.0, 0.2), en)
	vista._clip_mostrado(VARIANTE, "", 0.0, 0.0, Vector3.ZERO, en)
	# Mira a la banda: el arco le queda a 90°.
	var arco_al_costado := vista._clip_mostrado(VARIANTE, "Volea", 0.0, 2.0, Vector3(0.0, 0.0, -0.2), en)
	vista._clip_mostrado(VARIANTE, "", 0.0, 0.0, Vector3.ZERO, en)
	_ok(de_frente == "Volea" and cruzada == "Volea_Costado" and arco_al_costado == "Volea_Costado",
		"la volea es de costado con la pelota cruzada o el arco al costado (%s de frente, %s cruzada, %s con el arco a 90°)"
		% [de_frente, cruzada, arco_al_costado])
	var muslo := str((FisicaV2.parametros_toque()["clip_recepcion"] as Array)[1])
	_ok(muslo == "Control_Muslo" and p3.tiene(muslo) and str(clips[muslo]["ancla"]) == "Muslo_R"
		and float(clips[muslo]["contacto"]) > 0.0 and vista._contacto_cuerpo.has(muslo)
		and vista._gesto_corriendo.has(muslo) and str(vista._gesto_corriendo[muslo][1]) == "R"
		and DetectorPatinaV2.ancla_de(p3, "Muslo_R") != p3.global_position,
		"el control de muslo tiene su clip, toca después de empezar y con el ancla Muslo_R (%s)" % muslo)


## Sin motor: la vista recibe las posiciones de dos que andan derecho. El
## que conduce hace Control_Corriendo cada 0,75 s; el arquero anda de costado.
func _gestos_corriendo(vista: VistaV2) -> void:
	var n := vista._cantidad()
	var pos := PackedVector2Array()
	var rumbo := PackedFloat32Array()
	var rapidez := PackedFloat32Array()
	for i in n:
		var p := vista._jugadores[i].position
		pos.append(Vector2(p.x, p.z))
		rumbo.append(0.0)
		rapidez.append(0.0)
	pos[CONDUCE] = Vector2(-20.0, -20.0)
	pos[ARQUERO] = Vector2(-45.0, 0.0)
	rapidez[CONDUCE] = 5.0
	rapidez[ARQUERO] = 1.0
	var dur := vista._jugadores[CONDUCE].duracion("Control_Corriendo")
	var medidas := {CONDUCE: {"previo": {}, "suelo": {}, "patina": {}, "metros": {}}, ARQUERO: {"previo": {}, "suelo": {},
		"patina": {}, "metros": {}}}
	for k in 300:
		var previa := pos.duplicate()
		pos[CONDUCE] += Vector2(0.0, 5.0 * PASO)
		pos[ARQUERO] += Vector2(1.0 * PASO, 0.0)
		var acciones := []
		for i in n:
			acciones.append(["", 0.0])
		var t := fmod(k * PASO, 0.75)
		if t < dur:
			acciones[CONDUCE] = ["Control_Corriendo", t]
		vista._dibujar_jugadores(previa, pos, rumbo, rapidez, acciones, 1.0, PASO)
		if k < 60:
			continue
		for j in medidas:
			_medir_pie(vista._jugadores[j], medidas[j], float(rapidez[j]) * PASO)
	var m: Dictionary = medidas[CONDUCE]
	var r := float(m["patina"].get("Control_Corriendo", 0.0)) / maxf(float(m["metros"].get("Control_Corriendo", 0.0)), 0.01)
	_ok(m["metros"].has("Control_Corriendo") and r < 0.2,
		"conduciendo a 5 m/s, en el toque el pie apoyado desliza el %.0f%% de lo que avanza el cuerpo" % (100.0 * r))
	var a: Dictionary = medidas[ARQUERO]
	var en_guardia := float(a["metros"].get("Golero_Guardia", 0.0))
	var total := 0.0
	var patina := 0.0
	for clip in a["metros"]:
		total += float(a["metros"][clip])
		patina += float(a["patina"].get(clip, 0.0))
	_ok(en_guardia < 0.1 * total and patina < 0.3 * total,
		"el arquero a 1 m/s de costado no anda en guardia (%.1f de %.1f m) y el pie desliza el %.0f%%"
		% [en_guardia, total, 100.0 * patina / maxf(total, 0.01)])


## Sin motor: el arquero se tira (Atajar_Volando) y, al terminar, el motor
## lo deja sin gesto y sale a buscar el rebote (Canchita::_levantarse con la
## pelota en juego). La vista lo levanta con Arquero_Levanta en medio
## segundo; antes pasaba de tirado a parado en el fundido (0,15 s).
func _arquero_se_levanta(vista: VistaV2) -> void:
	var n := vista._cantidad()
	var pos := PackedVector2Array()
	var rumbo := PackedFloat32Array()
	var rapidez := PackedFloat32Array()
	for i in n:
		var p := vista._jugadores[i].position
		pos.append(Vector2(p.x, p.z))
		rumbo.append(0.0)
		rapidez.append(0.0)
	var p3: Jugador3D = vista._jugadores[ARQUERO]
	var parado := 0.0
	var dur := p3.duracion("Atajar_Volando")
	var clips := []
	var alto_a_los := {}
	var peor_salto := 0.0
	var antes := Vector3.ZERO
	for k in 150:
		var previa := pos.duplicate()
		var acciones := []
		for i in n:
			acciones.append(["", 0.0])
		var t := (k - 30) * PASO
		if k < 30:
			parado = p3.hueso("Cadera").origin.y
		elif t < dur:
			acciones[ARQUERO] = ["Atajar_Volando", t]
		else:
			# Sale hacia el rebote, acelerando.
			rapidez[ARQUERO] = minf(6.0 * (t - dur), 4.0)
			pos[ARQUERO] += Vector2(0.0, float(rapidez[ARQUERO]) * PASO)
		vista._dibujar_jugadores(previa, pos, rumbo, rapidez, acciones, 1.0, PASO)
		var cadera := p3.hueso("Cadera").origin
		if t >= dur:
			if clips.is_empty() or clips[-1] != p3._anim_actual:
				clips.append(p3._anim_actual)
			peor_salto = maxf(peor_salto, Vector2(cadera.x - antes.x, cadera.z - antes.z).length())
			for seg in [0.2, 0.8]:
				if not alto_a_los.has(seg) and t - dur >= seg:
					alto_a_los[seg] = cadera.y
		antes = cadera
	_ok(clips.size() >= 2 and str(clips[0]).begins_with("Arquero_Levanta") and not clips.has("Atajar_Volando"),
		"el arquero que se tiró y sigue jugando se levanta con Arquero_Levanta (%s)" % [clips])
	_ok(float(alto_a_los[0.2]) < 0.75 * parado and float(alto_a_los[0.8]) > 0.8 * parado,
		"a los 0,2 s todavía se está levantando (la cadera a %.2f m de %.2f) y a los 0,8 s anda parado (%.2f m)"
		% [alto_a_los[0.2], parado, alto_a_los[0.8]])
	_ok(peor_salto < 0.12, "y la cadera no salta: se mueve a lo sumo %.2f m en un cuadro" % peor_salto)


## El pie apoyado de un jugador en un cuadro, por clip (como _pasos).
func _medir_pie(p3: Jugador3D, m: Dictionary, avance: float) -> void:
	var clip := p3._anim_actual
	m["metros"][clip] = float(m["metros"].get(clip, 0.0)) + avance
	for pie in DetectorPatinaV2.PIES:
		var q := DetectorPatinaV2.ancla_de(p3, pie)
		var alto := q.y - p3.global_position.y
		if p3._mezcla >= 1.0:
			m["suelo"][clip] = minf(float(m["suelo"].get(clip, INF)), alto)
		var previo: Dictionary = m["previo"]
		if previo.has(pie) and p3._mezcla >= 1.0:
			var antes: Vector3 = previo[pie]
			if minf(alto, antes.y - p3.global_position.y) <= float(m["suelo"][clip]) + APOYO_M:
				m["patina"][clip] = float(m["patina"].get(clip, 0.0)) + Vector2(q.x - antes.x, q.z - antes.z).length()
		previo[pie] = q


## Avanza el cuerpo y la vista, y mide el pie apoyado del jugador j por clip.
## Los cuadros de fundido entre clips no cuentan (DetectorPatinaV2.FUNDIDO).
func _pasos(c: Object, vista: VistaV2, n: int, m: Dictionary, j: int) -> void:
	var p3: Jugador3D = vista._jugadores[j]
	for k in n:
		c.avanzar()
		vista.dibujar_cuerpos(c, 1.0, PASO, Vector2.ZERO)
		var clip := p3._anim_actual
		if (m["orden"] as Array).is_empty() or m["orden"][-1] != clip:
			(m["orden"] as Array).append(clip)
		m["metros"][clip] = float(m["metros"].get(clip, 0.0)) + float(c.get_rapidez()[j]) * PASO
		for pie in DetectorPatinaV2.PIES:
			var q := DetectorPatinaV2.ancla_de(p3, pie)
			var alto := q.y - p3.global_position.y
			if p3._mezcla >= 1.0:
				m["suelo"][clip] = minf(float(m["suelo"].get(clip, INF)), alto)
			var previo: Dictionary = m["previo"]
			if previo.has(pie) and p3._mezcla >= 1.0:
				var antes: Vector3 = previo[pie]
				if minf(alto, antes.y - p3.global_position.y) <= float(m["suelo"][clip]) + APOYO_M:
					m["patina"][clip] = float(m["patina"].get(clip, 0.0)) + Vector2(q.x - antes.x, q.z - antes.z).length()
			previo[pie] = q


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
