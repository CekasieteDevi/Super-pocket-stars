class_name Jugador3D
extends Node3D

## Un personaje del partido 3D: el GLB, sus colores y la animación que
## muestra en cada cuadro.
##
## La animación no corre sola. VistaV2 le dice qué animación y en qué
## segundo, calculado desde el fotograma del motor: así pausa, velocidad x2 y
## saltos de índice se ven igual que en el 2D.

## El chibi mide 2.26 m con el pelo y el travesaño del motor 2.44 m. A 0.75
## queda en ~1.7 m: el arquero llega al 70% del arco, casi lo mismo que en
## el estadio de Blender con el arco agrandado (74%).
const ESCALA_CHIBI := 0.75

## El GLB trae el personaje en una sola malla con un solo material (una
## llamada de dibujo por jugador): cada cara dice su color y cómo se pinta
## (ver personaje.gdshader). Cada jugador tiene su copia para sus colores.
const SHADER_PERSONAJE := preload("res://match/3d/personaje.gdshader")

## El short sin color elegido es blanco, igual que el pantalón por defecto
## de los sprites (ver AtlasJugadores).
const SHORT_POR_DEFECTO := Color("f5f4f0")

var animador: AnimationPlayer
var espejado := false:
	set(valor):
		espejado = valor
		scale = Vector3(-ESCALA_CHIBI if valor else ESCALA_CHIBI, ESCALA_CHIBI, ESCALA_CHIBI)
		_material.set_shader_parameter("espejo", 1.0 if valor else 0.0)

## Al cambiar de animación, la pose vieja se funde con la nueva en este tiempo
## (segundos de partido). Sin esto, del último cuadro del regate al pique se
## veía el salto de pose.
const MEZCLA_SEG := 0.15
## Los huesos que toma piernas_de: la cadera lleva a las dos piernas.
const HUESOS_PIERNAS := ["Cadera", "Muslo.L", "Pierna.L", "Pie.L", "Muslo.R", "Pierna.R", "Pie.R"]

## Las caras: una fila por cara y una columna por gesto (tools/generar_caras.py).
const ATLAS_CARAS := preload("res://assets/3d/caras.png")
const CANTIDAD_CARAS := 20
enum Gesto { NORMAL, FELIZ, DOLOR, TRISTE, PARPADEO }
## Rectángulo de la cara en la malla, visto de frente (x, y en metros; el
## mismo que X0..Y1 de generar_caras.py). Va del mentón (1.18) a las puntas
## del flequillo, y de cachete a cachete.
const RECT_CARA := Rect2(-0.4, 1.15, 0.8, 0.6)
## Debajo de esto es el cuello: la cara es solo de la cabeza.
const CARA_DESDE_Y := 1.15
## Tipos del shader (ver personaje.gdshader).
const TIPO_CAMISETA := 1
const TIPO_PIEL := 4
const TIPO_PLANO := 5
const TIPO_CACHETES := 6
## Parpadeo del gesto normal: cada cuánto (segundos de partido, más una parte
## propia de cada cara para que no parpadeen todos juntos) y cuánto dura.
const PARPADEO_CADA_SEG := 3.2
const PARPADEO_DURA_SEG := 0.14

## El dorsal: cifras del atlas de tools/generar_numeros.py, una celda por
## cifra. Va en la espalda de la camiseta, en este rectángulo visto de atrás
## (x, y en metros de la malla; medido con scratch/_diag_espalda_malla.gd:
## la espalda va de 0.6 a 1.1 m y mide ±0.25 m a la altura del número). Cada
## cifra ocupa la mitad del ancho, con la proporción de la celda (1:2).
const ATLAS_NUMEROS := preload("res://assets/3d/numeros.png")
const RECT_NUMERO := Rect2(-0.19, 0.64, 0.38, 0.38)
## Hasta dónde es espalda (z de la normal): los costados no llevan número.
const ESPALDA_NORMAL_Z := -0.2

## Peinados (juego3d/peinados.py): el GLB los trae todos y cada jugador
## muestra uno. El vértice de pelo dice de cuál es en la V del UV: glTF la
## da vuelta y queda UV.y = -1 - peinado; lo demás tiene UV.y entre 0 y 1.
## 0 puntas, 1 pelado (sin malla), 2 rapado, 3 mohicano, 4 afro, 5 jopo,
## 6 raya, 7 rulos, 8 hongo, 9 alto.
const CANTIDAD_PEINADOS := 10
const PEINADO_OFICIAL := 2

## Malla del GLB -> lo que se arma una sola vez con ella (ver _preparar).
static var _preparadas := {}
## Malla del GLB -> {peinado: la malla de ese peinado}.
static var _mallas_con_peinado := {}
## Microsegundos que llevó armar mallas desde que arrancó el juego: el primer
## partido arma la de cada peinado que aparece. Lo lee el banco del teléfono
## (motor_v2/banco_etapa8.gd) y tests/_diag_mallas_3d.gd.
static var usec_mallas := 0

var _material: ShaderMaterial
var _mallas: Array[MeshInstance3D] = []
var _mallas_base: Array[Mesh] = []
var peinado := -1
var _anclas := {}
var _anim_actual := ""
var _colores_actuales := []
var _esqueleto: Skeleton3D
## Cuánto va de la mezcla (1 = terminada). Mientras funde, el clip viejo
## sigue andando a su ritmo (segundos de clip por segundo de partido) en vez
## de quedar congelado: con la pose congelada el pie apoyado del clip viejo
## viajaba con el cuerpo y el pie patinaba en cada cambio de clip (en un
## partido, el 15% del tiempo de cada jugador; medido con
## tests/_diag_patina_partido_v2.gd).
var _mezcla := 1.0
var _anim_vieja := ""
var _t_vieja := 0.0
var _ritmo_viejo := 0.0
## El segundo del clip actual en el cuadro anterior y su ritmo.
var _t_actual := 0.0
var _ritmo := 0.0
## Si cambia de clip en medio de otra mezcla, funde desde la pose de ese
## momento ([posición, rotación, escala] por hueso), congelada: el clip
## viejo ya no es uno solo.
var _pose_vieja: Array = []
## Animation -> [[pista, tipo, hueso]] de las pistas de huesos.
static var _pistas := {}
static var _bucles := {}
## Piernas de la carrera debajo de un gesto (ver piernas_de): cuánto de la
## carrera lleva cada hueso en este cuadro y en el clip viejo de la mezcla.
## Al volver de un gesto así a la carrera, esas piernas ya son las de la
## carrera: fundirlas con las del gesto devolvía el pie que patina.
var _peso_piernas := PackedFloat32Array()
var _peso_piernas_vieja := PackedFloat32Array()
## Pie clavado (ver clavar_pies). Para el detector PATINA un pie está apoyado
## a menos de esto del punto más bajo de un pie en su clip (metros de la
## cancha).
const APOYO_M := 0.015
## Qué cuadros de un clip tienen cada pie apoyado (ver _apoyo_de): el pie se
## mueve contra el piso de la cinta menos que esto por cuadro, o que esta
## parte de lo que avanza el piso. Medido en los clips en cinta: apoyado
## desliza 0 a 4 mm por cuadro (Correr, hasta 16) y en el aire, 28 o más.
## Por la altura sola no se puede: en Caminar el pie en el aire sube 2 a 3 cm,
## menos que el pie apoyado de Trotar cuando despega (2,4 cm).
const APOYO_DESLIZA_M := 0.005
const APOYO_DESLIZA_PARTE := 0.25
## Los clips vienen de Blender a 24 cuadros por segundo.
const CUADROS_POR_SEG := 24.0
## Con el pie clavado a más de esto de donde lo pone el clip, da un paso corto
## hasta ahí. 10 cm es un cuarto de la pierna del chibi (0,38 m): más lejos la
## rodilla queda estirada del todo. Con el otro pie en el aire aguanta hasta
## CLAVADO_MAX_M, o hasta que la pierna no llega: el paso lo deja un momento
## sin apoyo, como en la carrera. Arrastrando el pie por el piso hasta donde
## da la pierna, los fundidos patinaban 644 m por partido; con el paso, 242.
const CLAVADO_PASO_DESDE_M := 0.1
const CLAVADO_MAX_M := 0.25
## Para llegar al pie clavado la cadera baja hasta esto, a esta rapidez (m/s).
## Parado, la pierna del chibi está casi estirada: sin bajar la cadera el pie
## clavado no aguanta ni 3 cm hacia atrás.
const CADERA_BAJA_MAX_M := 0.05
const CADERA_BAJA_MS := 0.5
## El paso corto: cuánto dura, cuánto levanta el pie y desde qué parte del
## paso baja (hasta la misma parte desde el principio, sube).
const PASO_CORTO_SEG := 0.12
const PASO_CORTO_ALTO_M := 0.04
const PASO_CORTO_BAJA_DESDE := 0.8
## El pie que se levanta vuelve a donde lo pone el clip a esta rapidez (m/s).
const SOLTAR_PIE_MS := 2.0
## Corrido menos que esto (0,1 mm, al cuadrado) el pie queda donde lo pone el
## clip, sin doblar la pierna.
const CORRIDO_MIN_M2 := 1e-8
const LADOS_PIE := ["L", "R"]
## Por pie (L, R): [muslo, pierna, pie] y el punto de apoyo (el nodo Pie_L o
## Pie_R del GLB) en el espacio del hueso del pie.
var _huesos_pierna: Array = []
var _apoyo_pie: Array[Vector3] = []
## Por pie: si está clavado, dónde (en la cancha), cuánto está corrido de
## donde lo pone el clip, el paso corto que está dando ({} = ninguno: `t` de
## 0 a 1, `desde`, dónde estaba el pie, y `llega`, dónde baja) y si la pierna
## no llegó.
var _pie_clavado := [false, false]
var _pie_punto: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _pie_corrido: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _pie_paso: Array[Dictionary] = [{}, {}]
var _pie_tirante := [false, false]
## Por pie: si en el cuadro anterior estaba a menos de APOYO_M del suelo.
var _pie_pegado := [false, false]
## Cuánto bajó la cadera para llegar al pie clavado (espacio del esqueleto).
var _cadera_baja := 0.0
## Animation -> {suelo: el punto más bajo de un pie en el clip (espacio del
## esqueleto), pisa: un byte por cuadro con un bit por pie apoyado (1 el
## izquierdo, 2 el derecho)}. Lo comparten todos los del mismo modelo;
## _apoyo_por_clip es el mismo dato por nombre de clip, para no buscar la
## animación en cada cuadro.
static var _apoyos := {}
var _apoyo_por_clip := {}
## Dónde pone el clip cada pie y adónde va (espacio del esqueleto), de este
## cuadro: quedan acá para no armar dos listas por jugador y por cuadro.
var _pie_en_clip: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _pie_destino: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var cara := -1
var gesto := Gesto.NORMAL
var numero := -1
## Clave del motor del jugador que muestra en este cuadro (-1 los oficiales).
## La lista de personas va por orden de entidad: con un cambio, el mismo
## nodo pasa a mostrar a otro. Sirve para medir qué gesto tiene cada uno.
var clave_motor := -1


func _init(escena: PackedScene) -> void:
	var modelo := escena.instantiate()
	add_child(modelo)
	scale = Vector3.ONE * ESCALA_CHIBI
	_material = ShaderMaterial.new()
	_material.shader = SHADER_PERSONAJE
	_material.set_shader_parameter("color_contorno", Materiales3D.COLOR_CONTORNO)
	_material.set_shader_parameter("caras", ATLAS_CARAS)
	_material.set_shader_parameter("numeros", ATLAS_NUMEROS)
	_material.set_shader_parameter("tam_celda_cara",
		Vector2(1.0 / float(Gesto.size()), 1.0 / float(CANTIDAD_CARAS)))
	for nodo in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		var desde := Time.get_ticks_usec()
		_material.set_shader_parameter("piel", _preparar(mi.mesh)["piel"])
		usec_mallas += Time.get_ticks_usec() - desde
		_mallas.append(mi)
		_mallas_base.append(mi.mesh)
		mi.material_override = _material
	poner_peinado(0)
	poner_cara(0, Gesto.NORMAL)
	var encontrados := modelo.find_children("*", "AnimationPlayer", true, false)
	if not encontrados.is_empty():
		animador = encontrados[0]
		# El tiempo lo pone VistaV2 con seek(): sin esto el reproductor
		# avanzaría por su cuenta entre dos cuadros. En manual tampoco vuelve
		# a aplicar la pose solo, y la mezcla de poner() no se pisa.
		animador.speed_scale = 0.0
		animador.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		_esqueleto = esqueletos[0]
		for lado in LADOS_PIE:
			var huesos := [_esqueleto.find_bone("Muslo." + lado), _esqueleto.find_bone("Pierna." + lado),
				_esqueleto.find_bone("Pie." + lado)]
			var apoyo := Vector3.ZERO
			for nodo in modelo.find_children("Pie_" + lado, "Node3D", true, false):
				if nodo.get_parent() is BoneAttachment3D:
					apoyo = (nodo as Node3D).transform.origin
			_huesos_pierna.append(huesos)
			_apoyo_pie.append(apoyo)


func colorear(camiseta: Color, short: Color, pelo: Color) -> void:
	var colores := [camiseta, short, pelo]
	if colores == _colores_actuales:
		return
	_colores_actuales = colores
	_material.set_shader_parameter("camiseta", camiseta)
	_material.set_shader_parameter("color_short", SHORT_POR_DEFECTO if short.a < 0.01 else short)
	_material.set_shader_parameter("pelo", pelo)
	_material.set_shader_parameter("color_numero", AtlasJugadores.color_numero(camiseta))


## El dorsal de la espalda (1..99; 0 sin número, como los oficiales). El
## color sale de la camiseta en colorear(), el mismo que el del 2D.
func poner_numero(n: int) -> void:
	if n == numero:
		return
	numero = n
	var cifras := 0 if n <= 0 else (1 if n < 10 else 2)
	_material.set_shader_parameter("cifras", cifras)
	_material.set_shader_parameter("cifra_1", n / 10 if cifras == 2 else n % 10)
	_material.set_shader_parameter("cifra_2", n % 10)


## La cara de cada jugador sale de su jugador_id, como el peinado y el tono
## de pelo del 2D (AtlasJugadores.tono_pelo_de): es la misma en todos los
## partidos. Los planteles tienen ids seguidos: con este paso (17 caras por
## id, CARA_PASO * 20) 20 ids seguidos pasan por las 20 caras, así nadie
## repite cara en el equipo hasta el jugador 21. Un hash al azar daba 5
## caras distintas en un once. Lo que sobra de 0.85 corre el orden una cara
## cada 1000 ids: los planteles de prueba (ids 0.. y 1000..) salían con las
## mismas caras en el mismo orden.
const CARA_PASO := 0.84995


static func cara_de(jugador_id: int) -> int:
	return int(fposmod(float(jugador_id) * CARA_PASO, 1.0) * CANTIDAD_CARAS) % CANTIDAD_CARAS


## El peinado también sale del jugador_id, con otro paso que la cara (3
## peinados por id): 10 ids seguidos pasan por los 10 peinados (salvo 1 de
## cada 20 planteles, que repite uno) y la cara no anda pegada al peinado. Lo
## que sobra de 0.3 corre el orden 5 peinados cada 1000 ids (los planteles de
## prueba). No es el del 2D (AtlasJugadores.estilo_de), que tiene otros.
const PEINADO_PASO := 0.3005


static func peinado_de(jugador_id: int) -> int:
	return int(fposmod(float(jugador_id) * PEINADO_PASO, 1.0) * CANTIDAD_PEINADOS) % CANTIDAD_PEINADOS


func poner_peinado(n: int) -> void:
	if n == peinado:
		return
	peinado = n
	for i in _mallas.size():
		_mallas[i].mesh = _con_peinado(_mallas_base[i], n)


## Pone la cara `n` con el gesto `g`. En el gesto normal parpadea solo:
## `segundos` es el tiempo de partido (el parpadeo se congela en la pausa).
func poner_cara(n: int, g: int, segundos: float = -1.0) -> void:
	if g == Gesto.NORMAL and segundos >= 0.0:
		var ciclo := fposmod(segundos + float(n) * 0.37 * PARPADEO_CADA_SEG, PARPADEO_CADA_SEG + float(n % 3) * 0.6)
		if ciclo < PARPADEO_DURA_SEG:
			g = Gesto.PARPADEO
	if n == cara and g == gesto:
		return
	cara = n
	gesto = g
	_material.set_shader_parameter("celda_cara",
		Vector2(float(g) / float(Gesto.size()), float(n) / float(CANTIDAD_CARAS)))


## La malla de `malla` (la del GLB) para el peinado `n`: sin la cara
## modelada, sin el pelo de los otros peinados y solo con los vértices que
## usa. Se hace una vez por malla y peinado: los que tienen el mismo peinado
## comparten el resultado.
static func _con_peinado(malla: Mesh, n: int) -> Mesh:
	if not _mallas_con_peinado.has(malla):
		_mallas_con_peinado[malla] = {}
	var hechas: Dictionary = _mallas_con_peinado[malla]
	if hechas.has(n):
		return hechas[n]
	var desde := Time.get_ticks_usec()
	var base := _preparar(malla)
	var datos: Array = base["datos"]
	var total: int = base["total"]
	# El cuerpo ya está juntado: acá se suman los vértices del pelo.
	var nuevo_de: PackedInt32Array = (base["nuevo_de"] as PackedInt32Array).duplicate()
	var cuantos: int = base["cuantos"]
	var pelo: PackedInt32Array = base["pelo"][n] if n < (base["pelo"] as Array).size() else PackedInt32Array()
	var viejos := PackedInt32Array()
	var indices_pelo := PackedInt32Array()
	indices_pelo.resize(pelo.size())
	for k in pelo.size():
		var v := pelo[k]
		if nuevo_de[v] < 0:
			nuevo_de[v] = cuantos + viejos.size()
			viejos.append(v)
		indices_pelo[k] = nuevo_de[v]
	var del_pelo := _juntar(datos, viejos, total)
	_marcar_cara_y_dorsal(del_pelo, false)
	var salida: Array = base["cuerpo"]
	salida = salida.duplicate()
	for a in salida.size():
		if a != Mesh.ARRAY_INDEX and salida[a] != null:
			salida[a] = salida[a].duplicate()
			salida[a].append_array(del_pelo[a])
	var indices: PackedInt32Array = (base["indices"] as PackedInt32Array).duplicate()
	indices.append_array(indices_pelo)
	salida[Mesh.ARRAY_INDEX] = indices
	var nueva := ArrayMesh.new()
	nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, salida, [], {},
		malla.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	hechas[n] = nueva
	usec_mallas += Time.get_ticks_usec() - desde
	return nueva


## Lo que se arma una sola vez con la malla del GLB, que es una para todos y
## trae la cara modelada (ojos, boca, lengua y cachetes) y el pelo de los diez
## peinados: 33.155 vértices, y cada jugador usa de 4.900 a 10.000.
## - `cuerpo` e `indices`: lo que dibujan todos (sin la cara modelada y sin
##   pelo), solo con los vértices que usa. La placa mueve con el esqueleto
##   TODOS los vértices de la malla en cada cuadro, se dibujen o no: con 23
##   personajes y la malla entera eran 760 mil por cuadro. En el teléfono
##   (Mali-G57) no terminaba los cuadros con todos amontonados en el área y
##   la pantalla se trababa 35 a 80 ms (medido con motor_v2/banco_etapa8.gd y
##   simpleperf: el hilo esperaba un buffer libre).
## - `pelo`: los triángulos de cada peinado, para sumarlos en _con_peinado.
## - `piel`: el color de cualquier vértice de tipo piel. Hace falta aparte
##   porque los cachetes se mezclan sobre ella.
## Antes cada peinado recorría la malla entera (los 61 mil triángulos y los 33
## mil vértices): armar la cara y los once peinados de un partido llevaba
## 166 ms en la PC; así, 56 (tests/_diag_mallas_3d.gd).
static func _preparar(malla: Mesh) -> Dictionary:
	if _preparadas.has(malla):
		return _preparadas[malla]
	var datos := malla.surface_get_arrays(0)
	var uv: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
	var total := uv.size()
	var uv2 := PackedVector2Array()
	uv2.resize(total)
	datos[Mesh.ARRAY_TEX_UV2] = uv2
	# Por vértice: 0 lo dibujan todos, 1 es de la cara modelada (no se dibuja),
	# 2 + n es pelo del peinado n. El pelo se marca recién al sumarlo.
	var de := _marcar_cara_y_dorsal(datos, true)
	var piel := Color.WHITE
	var colores: PackedColorArray = datos[Mesh.ARRAY_COLOR]
	for i in total:
		if de[i] != 0:
			continue
		if roundi(uv[i].x) == TIPO_PIEL:
			piel = Color(colores[i], 1.0)
			break
	var pelo := []
	for n in CANTIDAD_PEINADOS:
		pelo.append(PackedInt32Array())
	var nuevo_de := PackedInt32Array()
	nuevo_de.resize(total)
	nuevo_de.fill(-1)
	var viejos := PackedInt32Array()
	var del_cuerpo := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		if de[a] == 1 or de[b] == 1 or de[c] == 1:
			continue
		if de[a] >= 2:
			if de[a] - 2 < CANTIDAD_PEINADOS:
				var del_peinado: PackedInt32Array = pelo[de[a] - 2]
				del_peinado.append(a)
				del_peinado.append(b)
				del_peinado.append(c)
			continue
		# Vértice por vértice y sin armar una lista por triángulo: son 61 mil.
		if nuevo_de[a] < 0:
			nuevo_de[a] = viejos.size()
			viejos.append(a)
		if nuevo_de[b] < 0:
			nuevo_de[b] = viejos.size()
			viejos.append(b)
		if nuevo_de[c] < 0:
			nuevo_de[c] = viejos.size()
			viejos.append(c)
		del_cuerpo.append(nuevo_de[a])
		del_cuerpo.append(nuevo_de[b])
		del_cuerpo.append(nuevo_de[c])
	var preparada := {"datos": datos, "total": total, "cuerpo": _juntar(datos, viejos, total), "indices": del_cuerpo,
		"nuevo_de": nuevo_de, "cuantos": viejos.size(), "pelo": pelo, "piel": piel}
	_preparadas[malla] = preparada
	return preparada


## A la piel de la cara le da el UV2 del rectángulo RECT_CARA y, en el alfa
## del color, si mira al frente. A la espalda de la camiseta, igual con
## RECT_NUMERO (el dorsal). Devuelve, por vértice, 0 si se dibuja, 1 si es de
## la cara modelada y 2 + n si es pelo del peinado n. Con `saltea_pelo` deja
## el pelo sin tocar (25 mil de los 33 mil vértices de la malla).
static func _marcar_cara_y_dorsal(datos: Array, saltea_pelo: bool) -> PackedByteArray:
	var pos: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = datos[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
	var colores: PackedColorArray = datos[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV2]
	var de := PackedByteArray()
	de.resize(pos.size())
	for i in pos.size():
		if uv[i].y < -0.5:
			de[i] = 2 + (-roundi(uv[i].y) - 1)
			if saltea_pelo:
				continue
		var tipo := roundi(uv[i].x)
		var en_cabeza := pos[i].y > CARA_DESDE_Y
		# El plano también pinta las líneas del escudo, pero ese va en el pecho.
		if en_cabeza and (tipo == TIPO_PLANO or tipo == TIPO_CACHETES):
			de[i] = 1
		uv2[i] = Vector2((pos[i].x - RECT_CARA.position.x) / RECT_CARA.size.x,
			(RECT_CARA.end.y - pos[i].y) / RECT_CARA.size.y)
		var c := colores[i]
		c.a = 1.0 if tipo == TIPO_PIEL and en_cabeza and normales[i].z > 0.0 else 0.0
		if tipo == TIPO_CAMISETA and normales[i].z < ESPALDA_NORMAL_Z:
			# Visto de atrás la x va al revés: el número se lee derecho.
			uv2[i] = Vector2((RECT_NUMERO.end.x - pos[i].x) / RECT_NUMERO.size.x,
				(RECT_NUMERO.end.y - pos[i].y) / RECT_NUMERO.size.y)
			c.a = 1.0
		colores[i] = c
	datos[Mesh.ARRAY_COLOR] = colores
	datos[Mesh.ARRAY_TEX_UV2] = uv2
	return de


## Los arreglos de `datos` (los de una malla de `total` vértices) solo con
## los vértices `viejos`, en ese orden. Sin los índices.
static func _juntar(datos: Array, viejos: PackedInt32Array, total: int) -> Array:
	var salida := datos.duplicate()
	var cuantos := viejos.size()
	for a in datos.size():
		if a == Mesh.ARRAY_INDEX or datos[a] == null:
			continue
		# Cada tipo aparte: con el arreglo sin tipo cada copia pasa por Variant
		# y armar los peinados de un partido tarda más.
		match typeof(datos[a]):
			TYPE_PACKED_VECTOR3_ARRAY:
				var o3: PackedVector3Array = datos[a]
				var d3 := PackedVector3Array()
				d3.resize(cuantos)
				for k in cuantos:
					d3[k] = o3[viejos[k]]
				salida[a] = d3
			TYPE_PACKED_VECTOR2_ARRAY:
				var o2: PackedVector2Array = datos[a]
				var d2 := PackedVector2Array()
				d2.resize(cuantos)
				for k in cuantos:
					d2[k] = o2[viejos[k]]
				salida[a] = d2
			TYPE_PACKED_COLOR_ARRAY:
				var oc: PackedColorArray = datos[a]
				var dc := PackedColorArray()
				dc.resize(cuantos)
				for k in cuantos:
					dc[k] = oc[viejos[k]]
				salida[a] = dc
			TYPE_PACKED_FLOAT32_ARRAY:
				# Tangentes (4 por vértice) y pesos (4 u 8).
				var of: PackedFloat32Array = datos[a]
				var por_f := of.size() / total
				var df := PackedFloat32Array()
				df.resize(cuantos * por_f)
				for k in cuantos:
					for c in por_f:
						df[k * por_f + c] = of[viejos[k] * por_f + c]
				salida[a] = df
			TYPE_PACKED_INT32_ARRAY:
				# Huesos (4 u 8 por vértice).
				var oi: PackedInt32Array = datos[a]
				var por_i := oi.size() / total
				var di := PackedInt32Array()
				di.resize(cuantos * por_i)
				for k in cuantos:
					for c in por_i:
						di[k * por_i + c] = oi[viejos[k] * por_i + c]
				salida[a] = di
			_:
				push_error("Jugador3D._juntar: arreglo %d de tipo %d sin juntar" % [a, typeof(datos[a])])
	salida[Mesh.ARRAY_INDEX] = null
	return salida


## Posición en el mundo de un anclaje del GLB (Mano_L, Frente, Pie_R...). Son
## nodos vacíos pegados a los huesos en Blender. Si no está, el centro.
##
## Se calcula desde la pose actual del esqueleto y no con la posición del
## nodo: el BoneAttachment3D recién se mueve al final del cuadro, y la pelota
## quedaba donde estaba el pie un cuadro antes (en un salto de reproducción,
## en la chilena, 0.6 m abajo del pie).
func ancla(nombre: String) -> Vector3:
	if not _anclas.has(nombre):
		var nodo := find_child(nombre, true, false) as Node3D
		var union := nodo.get_parent() as BoneAttachment3D if nodo != null else null
		var esqueleto: Skeleton3D = null
		if union != null:
			esqueleto = union.get_parent() as Skeleton3D
		_anclas[nombre] = [nodo, union, esqueleto]
	var datos: Array = _anclas[nombre]
	var nodo: Node3D = datos[0]
	if nodo == null:
		return global_position
	var union: BoneAttachment3D = datos[1]
	var esqueleto: Skeleton3D = datos[2]
	if union == null or esqueleto == null or union.bone_idx < 0:
		return nodo.global_position
	var hueso := esqueleto.global_transform * esqueleto.get_bone_global_pose(union.bone_idx)
	return hueso * nodo.transform.origin


## Como ancla(), pero siempre con la pose de este momento. Las anclas del
## GLB (Pie_R, Cabeza...) son el BoneAttachment3D mismo, no un hijo suyo:
## ancla() cae en su global_position, que se mueve recién al final del
## cuadro. El Motor V2 pone la pose y la mide en el mismo cuadro (ajuste de
## pie, laboratorio sin pantalla), y necesita la de ahora.
func ancla_de_pose(nombre: String) -> Vector3:
	var nodo := find_child(nombre, true, false) as Node3D
	if nodo is BoneAttachment3D and _esqueleto != null and (nodo as BoneAttachment3D).bone_idx >= 0:
		return _esqueleto.global_transform * _esqueleto.get_bone_global_pose((nodo as BoneAttachment3D).bone_idx).origin
	return ancla(nombre)


## Ajuste de pie del Motor V2 (docs/motor_v2.md, etapa 3; el warping de
## FIFA 10): lleva el punto `nombre_ancla` (Pie_R o Pie_L) hacia `objetivo`
## (en el mundo) con `peso` 0..1, doblando muslo y pierna (IK de dos huesos,
## con la rodilla del lado en que ya estaba). Solo toca huesos: el jugador y
## la pelota quedan donde están. Va después de poner(), que el cuadro
## siguiente vuelve a poner la pose del clip.
func llevar_pie(nombre_ancla: String, objetivo: Vector3, peso: float) -> void:
	if _esqueleto == null or peso <= 0.0:
		return
	var lado := "R" if nombre_ancla.ends_with("R") else "L"
	var muslo := _esqueleto.find_bone("Muslo." + lado)
	var pierna := _esqueleto.find_bone("Pierna." + lado)
	var pie := _esqueleto.find_bone("Pie." + lado)
	if muslo < 0 or pierna < 0 or pie < 0:
		return
	var al_esqueleto := _esqueleto.global_transform.affine_inverse()
	var t := al_esqueleto * objetivo
	# Dos vueltas: el pie gira con la pierna y el punto de contacto no cae
	# justo donde iba el tobillo; la segunda corrige lo que queda.
	for vuelta in 2:
		var a := _esqueleto.get_bone_global_pose(pie).origin
		var e := al_esqueleto * ancla_de_pose(nombre_ancla)
		_doblar_pierna(muslo, pierna, a, a + (t - e) * (peso if vuelta == 0 else 1.0))


## Dobla muslo y pierna (IK de dos huesos) para que `punto`, que va pegado a
## la pierna, llegue a `destino` (los dos en el espacio del esqueleto). La
## rodilla queda del lado en que ya estaba. Devuelve false si no llega (la
## pierna queda estirada del todo hacia ahí).
func _doblar_pierna(muslo: int, pierna: int, punto: Vector3, destino: Vector3) -> bool:
	var gm := _esqueleto.get_bone_global_pose(muslo)
	var gp := _esqueleto.get_bone_global_pose(pierna)
	var h := gm.origin
	var k := gp.origin
	var l1 := h.distance_to(k)
	var l2 := k.distance_to(punto)
	var hacia := destino - h
	if l1 < 1e-5 or l2 < 1e-5 or hacia.length_squared() < 1e-10:
		return false
	var largo := hacia.length()
	var d := clampf(largo, absf(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
	var dir := hacia / largo
	var normal := (k - h).cross(punto - h)
	if normal.length_squared() < 1e-12:
		normal = gm.basis.x
	var arriba := normal.normalized().cross(dir).normalized()
	if arriba.dot(k - h) < 0.0:
		arriba = -arriba
	var cos_h := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var k2 := h + dir * (l1 * cos_h) + arriba * (l1 * sqrt(1.0 - cos_h * cos_h))
	var p2 := h + dir * d
	var q1 := Quaternion((k - h).normalized(), (k2 - h).normalized())
	var muslo_nuevo := Basis(q1) * gm.basis
	var q2 := Quaternion((Basis(q1) * (punto - k)).normalized(), (p2 - k2).normalized())
	var pierna_nueva := Basis(q2) * Basis(q1) * gp.basis
	var padre := _esqueleto.get_bone_parent(muslo)
	var base := _esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
	_esqueleto.set_bone_pose_rotation(muslo, (base.inverse() * muslo_nuevo).get_rotation_quaternion())
	_esqueleto.set_bone_pose_rotation(pierna, (muslo_nuevo.inverse() * pierna_nueva).get_rotation_quaternion())
	return absf(d - largo) < 1e-5


## Pie clavado (Motor V2): el pie apoyado queda en el punto de la cancha donde
## pisó y la pierna se dobla para llegar. Derecho, los clips en cinta ya lo
## dejan quieto; se movía cuando el modelo gira con el pie apoyado lejos del
## centro (de andar de costado a andar adelante gira 90°), cuando la marcha
## cambia de dirección y en los fundidos. En un partido
## (tests/_diag_patina_partido_v2.gd, semilla 20261201) el pie apoyado
## patinaba el 41 al 50% de lo que avanza el cuerpo de costado, el 44% de
## espaldas, el 33% caminando y 2035 m en los fundidos.
##
## Va después de poner(), en cada cuadro. `segundos`: los de partido desde el
## cuadro anterior; negativo (un corte) suelta los pies de golpe. `clava`
## false (un gesto): no clava, y el que estaba clavado vuelve al clip de a poco.
func clavar_pies(segundos: float, clava := true) -> void:
	if _esqueleto == null or animador == null or _huesos_pierna.is_empty() or _huesos_pierna[0].has(-1) \
			or _huesos_pierna[1].has(-1):
		return
	if segundos < 0.0:
		for k in LADOS_PIE.size():
			_pie_clavado[k] = false
			_pie_corrido[k] = Vector3.ZERO
			_pie_paso[k] = {}
			_pie_tirante[k] = false
			_pie_pegado[k] = false
		_cadera_baja = 0.0
		return
	var al_mundo := _esqueleto.global_transform
	var escala := al_mundo.basis.y.length()
	var apoyo := APOYO_M / escala
	var del_clip := _apoyo_de(_anim_actual)
	var suelo: float = del_clip["suelo"]
	# Un bit por pie: 1 el izquierdo, 2 el derecho.
	var pisa := _pisa_en(del_clip, _t_actual)
	if _mezcla < 1.0 and _anim_vieja != "":
		# En un fundido alcanza con que apoye en uno de los dos clips: el alto
		# de la pose fundida dice el resto.
		var del_viejo := _apoyo_de(_anim_vieja)
		suelo = lerpf(del_viejo["suelo"], suelo, smoothstep(0.0, 1.0, _mezcla))
		pisa |= _pisa_en(del_viejo, _t_vieja)
	# Dónde pone el clip cada pie (espacio del esqueleto).
	var en_clip := _pie_en_clip
	var quieto := _cadera_baja <= 1e-5
	for k in LADOS_PIE.size():
		en_clip[k] = _esqueleto.get_bone_global_pose(_huesos_pierna[k][2]) * _apoyo_pie[k]
		# Apoyado: a menos de APOYO_M del suelo (lo que mide el detector) o,
		# si el clip lo tiene quieto contra el piso, hasta el doble (el pie que
		# despega sube antes de irse). El que venía clavado y pegado al suelo
		# sigue clavado un cuadro más: despega derecho para arriba.
		var pegado := en_clip[k].y <= suelo + apoyo
		var despega: bool = _pie_clavado[k] and _pie_pegado[k]
		_pie_pegado[k] = pegado
		if clava and (pegado or despega or (pisa & (1 << k) != 0 and en_clip[k].y <= suelo + apoyo * 2.0)):
			_pisar(k, al_mundo * en_clip[k], segundos)
			# La pose de un fundido puede dejar el pie debajo del suelo.
			_pie_corrido[k].y += maxf(suelo - en_clip[k].y, 0.0) * escala
		else:
			_pie_clavado[k] = false
			_pie_paso[k] = {}
			# Vuelve al clip recién con el pie en el aire: volviendo desde que
			# despega, el pie todavía rozaba el piso y se lo veía barrer.
			if en_clip[k].y > suelo + apoyo:
				_pie_corrido[k] = _pie_corrido[k].move_toward(Vector3.ZERO, SOLTAR_PIE_MS * segundos)
		_pie_tirante[k] = false
		quieto = quieto and _pie_corrido[k].length_squared() < CORRIDO_MIN_M2
	# Lo de siempre andando derecho: los pies ya están donde los pone el clip.
	if quieto:
		return
	var al_esqueleto := al_mundo.affine_inverse()
	var destino := _pie_destino
	var baja_pedida := 0.0
	for k in LADOS_PIE.size():
		destino[k] = al_esqueleto * (al_mundo * en_clip[k] + _pie_corrido[k])
		if _pie_clavado[k] and _pie_corrido[k].length_squared() >= CORRIDO_MIN_M2:
			baja_pedida = maxf(baja_pedida, _baja_para_llegar(k, en_clip[k], destino[k]))
	# La cadera baja lo que le falta a la pierna para llegar al pie clavado,
	# de a poco: de golpe el cuerpo entero saltaba.
	_cadera_baja = move_toward(_cadera_baja, minf(baja_pedida, CADERA_BAJA_MAX_M / escala),
		CADERA_BAJA_MS / escala * segundos)
	var baja := Vector3(0.0, _cadera_baja, 0.0)
	var con_cadera := _cadera_baja > 1e-5
	if con_cadera:
		var cadera := _esqueleto.get_bone_parent(_huesos_pierna[0][0])
		_esqueleto.set_bone_pose_position(cadera, _esqueleto.get_bone_pose_position(cadera) - baja)
	for k in LADOS_PIE.size():
		# Con la cadera baja, el otro pie también vuelve a su lugar: si no, se
		# hundía en el piso.
		if not con_cadera and _pie_corrido[k].length_squared() < CORRIDO_MIN_M2:
			continue
		var huesos: Array = _huesos_pierna[k]
		var punto := en_clip[k] - baja
		if _pie_clavado[k]:
			# Si la pierna no llega, en este cuadro el pie se arrastra por el
			# piso hasta donde da y en el siguiente da el paso corto (_pisar).
			# Apuntando la pierna estirada al punto clavado, el pie se
			# levantaba hacia atrás.
			var h := _esqueleto.get_bone_global_pose(huesos[0]).origin
			var alcance := _largo_pierna(k, punto)
			var llega := sqrt(maxf(alcance * alcance - (h.y - destino[k].y) * (h.y - destino[k].y), 0.0))
			var hacia := Vector2(destino[k].x - h.x, destino[k].z - h.z)
			if hacia.length() > llega:
				hacia = hacia.limit_length(llega)
				destino[k] = Vector3(h.x + hacia.x, destino[k].y, h.z + hacia.y)
				_pie_tirante[k] = true
				_pie_corrido[k] = al_mundo * destino[k] - al_mundo * en_clip[k]
				if _pie_paso[k].is_empty():
					_pie_punto[k] = al_mundo * destino[k]
		_doblar_pierna(huesos[0], huesos[1], punto, destino[k])


## A qué alto sobre el piso del jugador (metros de la cancha) apoya el pie
## en `anim`: el punto más bajo de un pie en el clip. Lo usa el detector PATINA.
func suelo_de(anim: String) -> float:
	return float(_apoyo_de(anim)["suelo"]) * _esqueleto.global_transform.basis.y.length()


## Los loops de andar arrancan con el pie derecho pasando por debajo y el
## izquierdo apoyado (fase 0). Correr_Costado_Der es el espejo de _Izq y
## arranca con el otro pie: va medio ciclo corrido. Sin correrlo, al pasar de
## ese clip a Trotar se fundían dos pasos con el pie cambiado (el doble de
## pie bajo sin apoyar que desde _Izq, scratch de la medición del 2026-10-03).
func arranca_con_el_otro_pie(anim: String) -> bool:
	if not tiene(anim) or _esqueleto == null:
		return false
	return _pisa_en(_apoyo_de(anim), 0.0) == 2


## Hasta dónde llega la pierna `k` estirada, de la cadera a `punto` (que va
## pegado a la pierna). Un poco menos que el largo entero, como _doblar_pierna.
func _largo_pierna(k: int, punto: Vector3) -> float:
	var h := _esqueleto.get_bone_global_pose(_huesos_pierna[k][0]).origin
	var rodilla := _esqueleto.get_bone_global_pose(_huesos_pierna[k][1]).origin
	return (h.distance_to(rodilla) + rodilla.distance_to(punto)) * 0.998


## Qué pies apoya el clip (lo que da _apoyo_de) en su segundo `segundo`: un
## bit por pie (1 el izquierdo, 2 el derecho).
static func _pisa_en(apoyo_del_clip: Dictionary, segundo: float) -> int:
	var pisa: PackedByteArray = apoyo_del_clip["pisa"]
	return pisa[clampi(int(segundo * CUADROS_POR_SEG), 0, pisa.size() - 1)]


## El pie `k`, apoyado según el clip en `q` (en la cancha): queda clavado
## donde pisó. Si quedó lejos de donde lo pone el clip o la pierna no llega,
## da un paso corto hasta ahí.
func _pisar(k: int, q: Vector3, segundos: float) -> void:
	if not _pie_clavado[k]:
		_pie_clavado[k] = true
		_pie_punto[k] = q + _pie_corrido[k]
	var falta := _pie_punto[k] - q
	falta.y = 0.0
	var otro_firme: bool = _pie_clavado[1 - k] and _pie_paso[1 - k].is_empty()
	var lejos := falta.length()
	if _pie_paso[k].is_empty() and ((otro_firme and lejos > CLAVADO_PASO_DESDE_M) or lejos > CLAVADO_MAX_M
			or (_pie_tirante[k] and lejos > CLAVADO_PASO_DESDE_M * 0.3)):
		_pie_paso[k] = {"t": 0.0, "desde": q + falta}
	if not _pie_paso[k].is_empty():
		# Levanta el pie donde estaba, lo lleva por el aire y lo baja donde el
		# clip lo tiene en ese momento. Yendo y subiendo a la vez, el pie
		# barría el piso un cuarto del paso.
		var paso: Dictionary = _pie_paso[k]
		paso["t"] = float(paso["t"]) + segundos / PASO_CORTO_SEG
		var t := minf(float(paso["t"]), 1.0)
		if t >= PASO_CORTO_BAJA_DESDE and not paso.has("llega"):
			paso["llega"] = q
		var va: Vector3 = paso["llega"] if paso.has("llega") \
			else (paso["desde"] as Vector3).lerp(q, smoothstep(1.0 - PASO_CORTO_BAJA_DESDE, PASO_CORTO_BAJA_DESDE, t))
		falta = va - q
		falta.y = 0.0
		_pie_punto[k] = q + falta
		falta.y = PASO_CORTO_ALTO_M * sin(PI * t)
		if float(paso["t"]) >= 1.0:
			_pie_paso[k] = {}
	_pie_corrido[k] = falta


## Cuánto tiene que bajar la cadera (espacio del esqueleto) para que la
## pierna `k`, estirada, llegue con `punto` a `destino`.
func _baja_para_llegar(k: int, punto: Vector3, destino: Vector3) -> float:
	var h := _esqueleto.get_bone_global_pose(_huesos_pierna[k][0]).origin
	var largo := _largo_pierna(k, punto)
	var lejos := Vector2(destino.x - h.x, destino.z - h.z).length()
	if lejos >= largo:
		return INF
	return maxf(0.0, h.y - destino.y - sqrt(largo * largo - lejos * lejos))


## Dónde apoya `anim`: el punto más bajo de un pie (espacio del esqueleto) y
## en qué cuadros está apoyado cada pie. Sale de las pistas, cuadro por
## cuadro, sin tocar la pose: un pie está apoyado si casi no se mueve contra el
## piso de la cinta (`avance_m` de data/acciones_v2.json; sin eso, el piso
## quieto) y está cerca del suelo del clip. Cada clip tiene su suelo: una
## barrida o una caída apoyan 4 cm más abajo que Correr.
func _apoyo_de(anim: String) -> Dictionary:
	if _apoyo_por_clip.has(anim):
		return _apoyo_por_clip[anim]
	var a := animador.get_animation(anim)
	if _apoyos.has(a):
		_apoyo_por_clip[anim] = _apoyos[a]
		return _apoyos[a]
	var cuadros := maxi(roundi(a.length * CUADROS_POR_SEG), 1)
	var bajo := INF
	var pies := []
	for c in cuadros + 1:
		var pose := _pose_de(anim, a.length * float(c) / float(cuadros))
		var par: Array[Vector3] = []
		for k in LADOS_PIE.size():
			# Del pie a la cadera: cada hueso lleva el punto al espacio de su padre.
			var punto := _apoyo_pie[k]
			var b: int = _huesos_pierna[k][2]
			while b >= 0:
				var reposo := _esqueleto.get_bone_rest(b)
				var dato: Array = pose[b]
				var escala_hueso: Vector3 = dato[2] if dato[2] != null else reposo.basis.get_scale()
				var giro: Quaternion = dato[1] if dato[1] != null else reposo.basis.get_rotation_quaternion()
				punto = (dato[0] if dato[0] != null else reposo.origin) + giro * (punto * escala_hueso)
				b = _esqueleto.get_bone_parent(b)
			bajo = minf(bajo, punto.y)
			par.append(punto)
		pies.append(par)
	var escala := _esqueleto.global_transform.basis.y.length()
	var clip: Dictionary = FisicaV2.clips().get(anim, {})
	var avance: Array = clip.get("avance_m", [])
	var direccion := Vector2(clip["direccion"][0], clip["direccion"][1]) if clip.has("direccion") else Vector2.ZERO
	var pisa := PackedByteArray()
	pisa.resize(cuadros)
	for k in LADOS_PIE.size():
		for c in cuadros:
			var mueve: Vector3 = (pies[c + 1][k] - pies[c][k]) * escala
			var piso := float(avance[c + 1]) - float(avance[c]) if c + 1 < avance.size() else 0.0
			# El piso de la cinta va para atrás lo que el clip avanza.
			var desliza := (Vector2(mueve.x, mueve.z) + direccion * piso).length()
			var cerca := minf(pies[c][k].y, pies[c + 1][k].y) <= bajo + APOYO_M * 2.0 / escala
			if cerca and desliza <= maxf(APOYO_DESLIZA_M, absf(piso) * APOYO_DESLIZA_PARTE):
				pisa[c] |= 1 << k
	_apoyos[a] = {"suelo": bajo, "pisa": pisa}
	_apoyo_por_clip[anim] = _apoyos[a]
	return _apoyos[a]


## Transform en el mundo de un hueso (Antebrazo.R...), con la pose actual. El
## eje Y del hueso va de la cabeza a la cola (del codo a la mano). Sirve para
## orientar lo que se lleva en la mano (bandera, tarjeta).
func hueso(nombre: String) -> Transform3D:
	if _esqueleto == null:
		return global_transform
	var b := _esqueleto.find_bone(nombre)
	if b < 0:
		return global_transform
	return _esqueleto.global_transform * _esqueleto.get_bone_global_pose(b)


## Cuánto corre la pose actual la cadera, en el piso y en metros del mundo
## (x, z), desde su lugar de reposo.
func corrimiento_cadera() -> Vector2:
	if _esqueleto == null:
		return Vector2.ZERO
	var b := _esqueleto.find_bone("Cadera")
	if b < 0:
		return Vector2.ZERO
	var d := _esqueleto.get_bone_pose_position(b) - _esqueleto.get_bone_rest(b).origin
	var v := _esqueleto.global_transform.basis * Vector3(d.x, 0.0, d.z)
	return Vector2(v.x, v.z)


func tiene(anim: String) -> bool:
	return animador != null and animador.has_animation(anim)


func duracion(anim: String) -> float:
	return animador.get_animation(anim).length if tiene(anim) else 0.0


## Muestra `anim` en el segundo `tiempo`. Si el GLB no la tiene, queda quieto.
## `segundos` son los de partido desde el cuadro anterior: con ellos avanza la
## mezcla al cambiar de animación; negativo (salto de reproducción) no mezcla.
func poner(anim: String, tiempo: float, segundos: float = -1.0) -> void:
	if animador == null:
		return
	if not tiene(anim):
		anim = Cancha3D.ANIM_QUIETO if tiene(Cancha3D.ANIM_QUIETO) else "Quieto"
	tiempo = clampf(tiempo, 0.0, duracion(anim))
	if _esqueleto != null and _peso_piernas.size() != _esqueleto.get_bone_count():
		_peso_piernas.resize(_esqueleto.get_bone_count())
		_peso_piernas_vieja.resize(_esqueleto.get_bone_count())
	if anim != _anim_actual:
		if _anim_actual != "" and segundos >= 0.0 and _esqueleto != null:
			if _mezcla < 1.0:
				_guardar_pose()
				_anim_vieja = ""
				_peso_piernas_vieja.fill(0.0)
			else:
				_pose_vieja.clear()
				_anim_vieja = _anim_actual
				_t_vieja = _t_actual
				_ritmo_viejo = _ritmo
				_peso_piernas_vieja = _peso_piernas.duplicate()
			_mezcla = 0.0
		else:
			_mezcla = 1.0
		animador.play(anim)
		_anim_actual = anim
		_ritmo = 0.0
	elif segundos < 0.0:
		_mezcla = 1.0
	else:
		_mezcla = minf(1.0, _mezcla + segundos / MEZCLA_SEG)
		if segundos > 0.0:
			var avance := tiempo - _t_actual
			var largo := duracion(anim)
			# Un loop que dio la vuelta.
			if avance < -largo * 0.5 and _es_loop(anim):
				avance += largo
			_ritmo = clampf(avance / segundos, 0.0, 4.0)
	_t_actual = tiempo
	_peso_piernas.fill(0.0)
	animador.seek(tiempo, true)
	if _mezcla < 1.0:
		if _anim_vieja != "":
			_t_vieja += _ritmo_viejo * maxf(segundos, 0.0)
			var largo_viejo := duracion(_anim_vieja)
			_t_vieja = fposmod(_t_vieja, largo_viejo) if _es_loop(_anim_vieja) and largo_viejo > 0.0 				else minf(_t_vieja, largo_viejo)
		_fundir(smoothstep(0.0, 1.0, _mezcla))


## Los loops salen de data/acciones_v2.json: el GLB no trae marcado el loop
## de Correr ni de los otros clips de andar (tools/medir_clips_v2.gd).
func _es_loop(anim: String) -> bool:
	if _bucles.is_empty():
		var clips := FisicaV2.clips()
		for nombre in clips:
			if bool((clips[nombre] as Dictionary).get("bucle", false)):
				_bucles[nombre] = true
	return _bucles.has(anim)


func _guardar_pose() -> void:
	_pose_vieja.clear()
	for b in _esqueleto.get_bone_count():
		_pose_vieja.append([_esqueleto.get_bone_pose_position(b), _esqueleto.get_bone_pose_rotation(b),
			_esqueleto.get_bone_pose_scale(b)])


## La pose de `anim` en el segundo `tiempo`, por hueso ([posición,
## rotación, escala]; null donde el clip no tiene pista), leída de las pistas
## sin tocar el AnimationPlayer (que muestra otro clip).
func _pose_de(anim: String, tiempo: float) -> Array:
	var a := animador.get_animation(anim)
	if not _pistas.has(a):
		var lista := []
		for t in a.get_track_count():
			var tipo := a.track_get_type(t)
			if tipo not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				continue
			var hueso := _esqueleto.find_bone(a.track_get_path(t).get_concatenated_subnames())
			if hueso >= 0:
				lista.append([t, tipo, hueso])
		_pistas[a] = lista
	var pose := []
	pose.resize(_esqueleto.get_bone_count())
	for b in pose.size():
		pose[b] = [null, null, null]
	for p in _pistas[a]:
		match p[1]:
			Animation.TYPE_POSITION_3D: pose[p[2]][0] = a.position_track_interpolate(p[0], tiempo)
			Animation.TYPE_ROTATION_3D: pose[p[2]][1] = a.rotation_track_interpolate(p[0], tiempo)
			Animation.TYPE_SCALE_3D: pose[p[2]][2] = a.scale_track_interpolate(p[0], tiempo)
	return pose


## La pose que dejó seek() (la nueva) se lleva hacia la vieja: w=0 es la
## vieja, w=1 la nueva. Los huesos que en el clip viejo ya llevaban las
## piernas de la carrera no se funden con esa parte.
func _fundir(w: float) -> void:
	var vieja_pose := _pose_vieja if _anim_vieja == "" else _pose_de(_anim_vieja, _t_vieja)
	for b in mini(vieja_pose.size(), _esqueleto.get_bone_count()):
		var vieja: Array = vieja_pose[b]
		var wb := lerpf(w, 1.0, _peso_piernas_vieja[b]) if b < _peso_piernas_vieja.size() else w
		_mezclar_hueso(b, vieja, wb)


## Lleva el hueso `b` de la pose de `otra` ([posición, rotación, escala]) a
## la que tiene: w=0 es `otra`, w=1 la de ahora.
func _mezclar_hueso(b: int, otra: Array, w: float) -> void:
	if otra[0] != null:
		_esqueleto.set_bone_pose_position(b, (otra[0] as Vector3).lerp(_esqueleto.get_bone_pose_position(b), w))
	if otra[1] != null:
		_esqueleto.set_bone_pose_rotation(b, (otra[1] as Quaternion).slerp(_esqueleto.get_bone_pose_rotation(b), w))
	if otra[2] != null:
		_esqueleto.set_bone_pose_scale(b, (otra[2] as Vector3).lerp(_esqueleto.get_bone_pose_scale(b), w))


## Piernas de la carrera debajo de un gesto (Motor V2): los gestos que se
## hacen corriendo (el toque de la conducción, el remate corriendo, el pecho)
## están hechos en el lugar, y con el cuerpo a 5 m/s el pie de apoyo
## patinaba lo mismo que avanzaba el cuerpo. Acá la cadera y las piernas
## toman la pose de `anim` (un clip de andar en cinta, en su segundo
## `tiempo`) con `peso`; la pierna `lado` ("L", "R" o "" ninguna) sigue con
## el gesto en `peso_gesto`, para que patee o toque. Va después de poner().
func piernas_de(anim: String, tiempo: float, peso: float, lado := "", peso_gesto := 0.0) -> void:
	if _esqueleto == null or peso <= 0.0 or not tiene(anim):
		return
	var carrera := _pose_de(anim, tiempo)
	for nombre in HUESOS_PIERNAS:
		var b := _esqueleto.find_bone(nombre)
		if b < 0:
			continue
		var wb := peso * (1.0 - peso_gesto) if lado != "" and nombre.ends_with("." + lado) else peso
		_mezclar_hueso(b, carrera[b], 1.0 - wb)
		_peso_piernas[b] = wb
