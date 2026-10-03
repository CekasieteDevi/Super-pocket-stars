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

## Color de piel de cada malla, leído una vez de sus vértices.
static var _pieles := {}
## Malla original -> la misma sin la cara modelada y con el UV2 de la cara.
static var _mallas_con_cara := {}
## Malla con cara -> {peinado: la misma con solo ese peinado}.
static var _mallas_con_peinado := {}

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
		_material.set_shader_parameter("piel", _piel_de(mi.mesh))
		_mallas.append(mi)
		_mallas_base.append(_con_cara(mi.mesh))
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


## La malla del GLB trae la cara modelada (ojos, boca, lengua y cachetes)
## y es una sola para todos. Se saca esa geometría y a la piel de la cara se
## le da el UV2 del rectángulo RECT_CARA y, en el alfa del color, si mira al
## frente. La espalda de la camiseta, igual con RECT_NUMERO (el dorsal). Se
## hace una vez por malla: los 22 jugadores comparten el resultado.
static func _con_cara(malla: Mesh) -> Mesh:
	if _mallas_con_cara.has(malla):
		return _mallas_con_cara[malla]
	var datos := malla.surface_get_arrays(0)
	var pos: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = datos[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
	var colores: PackedColorArray = datos[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
	var uv2 := PackedVector2Array()
	uv2.resize(pos.size())
	var de_la_cara := PackedByteArray()
	de_la_cara.resize(pos.size())
	for i in pos.size():
		var tipo := roundi(uv[i].x)
		var en_cabeza := pos[i].y > CARA_DESDE_Y
		# El plano también pinta las líneas del escudo, pero ese va en el pecho.
		de_la_cara[i] = 1 if en_cabeza and (tipo == TIPO_PLANO or tipo == TIPO_CACHETES) else 0
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
	var sin_cara := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if de_la_cara[indices[t]] == 0 and de_la_cara[indices[t + 1]] == 0 and de_la_cara[indices[t + 2]] == 0:
			sin_cara.append_array([indices[t], indices[t + 1], indices[t + 2]])
	datos[Mesh.ARRAY_COLOR] = colores
	datos[Mesh.ARRAY_TEX_UV2] = uv2
	datos[Mesh.ARRAY_INDEX] = sin_cara
	var nueva := ArrayMesh.new()
	nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	_mallas_con_cara[malla] = nueva
	return nueva


## La malla sin el pelo de los otros peinados. Se hace una vez por malla y
## peinado: los que tienen el mismo peinado comparten el resultado.
static func _con_peinado(malla: Mesh, n: int) -> Mesh:
	if not _mallas_con_peinado.has(malla):
		_mallas_con_peinado[malla] = {}
	var hechas: Dictionary = _mallas_con_peinado[malla]
	if hechas.has(n):
		return hechas[n]
	var datos := malla.surface_get_arrays(0)
	var uv: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
	var quedan := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var v := uv[indices[t]].y
		if v > -0.5 or -roundi(v) - 1 == n:
			quedan.append_array([indices[t], indices[t + 1], indices[t + 2]])
	datos[Mesh.ARRAY_INDEX] = quedan
	var nueva := ArrayMesh.new()
	nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compactar(datos), [], {},
		malla.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	hechas[n] = nueva
	return nueva


## Los mismos triángulos, solo con los vértices que usan. La malla del GLB
## trae los diez peinados y la cara modelada: 33.155 vértices, y cada jugador
## usa de 4.900 a 10.000. La placa mueve con el esqueleto TODOS los vértices
## de la malla en cada cuadro, se dibujen o no: con 23 personajes eran 760 mil
## por cuadro. En el teléfono (Mali-G57) no terminaba los cuadros con todos
## amontonados en el área y la pantalla se trababa 35 a 80 ms (medido con
## motor_v2/banco_etapa8.gd y simpleperf: el hilo esperaba un buffer libre).
static func _compactar(datos: Array) -> Array:
	var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
	var total: int = (datos[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var nuevo_de := PackedInt32Array()
	nuevo_de.resize(total)
	nuevo_de.fill(-1)
	var viejos := PackedInt32Array()
	var nuevos_indices := PackedInt32Array()
	nuevos_indices.resize(indices.size())
	for k in indices.size():
		var v := indices[k]
		if nuevo_de[v] < 0:
			nuevo_de[v] = viejos.size()
			viejos.append(v)
		nuevos_indices[k] = nuevo_de[v]
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
				push_error("Jugador3D._compactar: arreglo %d de tipo %d sin compactar" % [a, typeof(datos[a])])
	salida[Mesh.ARRAY_INDEX] = nuevos_indices
	return salida


## El color de la piel es el de cualquier vértice de tipo piel (U = 4). Hace
## falta aparte porque los cachetes se mezclan sobre ella.
static func _piel_de(malla: Mesh) -> Color:
	if not _pieles.has(malla):
		var piel := Color.WHITE
		var datos := malla.surface_get_arrays(0)
		var uv: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
		var colores: PackedColorArray = datos[Mesh.ARRAY_COLOR]
		for i in mini(uv.size(), colores.size()):
			if roundi(uv[i].x) == 4:
				piel = colores[i]
				break
		_pieles[malla] = piel
	return _pieles[malla]


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
		var gm := _esqueleto.get_bone_global_pose(muslo)
		var gp := _esqueleto.get_bone_global_pose(pierna)
		var gf := _esqueleto.get_bone_global_pose(pie)
		var h := gm.origin
		var k := gp.origin
		var a := gf.origin
		var e := al_esqueleto * ancla_de_pose(nombre_ancla)
		var a2 := a + (t - e) * (peso if vuelta == 0 else 1.0)
		var l1 := h.distance_to(k)
		var l2 := k.distance_to(a)
		var hacia := a2 - h
		if l1 < 1e-5 or l2 < 1e-5 or hacia.length_squared() < 1e-10:
			return
		var d := clampf(hacia.length(), absf(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
		var dir := hacia.normalized()
		var normal := (k - h).cross(a - h)
		if normal.length_squared() < 1e-12:
			normal = gm.basis.x
		var arriba := normal.normalized().cross(dir).normalized()
		if arriba.dot(k - h) < 0.0:
			arriba = -arriba
		var cos_h := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
		var k2 := h + dir * (l1 * cos_h) + arriba * (l1 * sqrt(1.0 - cos_h * cos_h))
		var a3 := h + dir * d
		var q1 := Quaternion((k - h).normalized(), (k2 - h).normalized())
		var muslo_nuevo := Basis(q1) * gm.basis
		var q2 := Quaternion((Basis(q1) * (a - k)).normalized(), (a3 - k2).normalized())
		var pierna_nueva := Basis(q2) * Basis(q1) * gp.basis
		var padre := _esqueleto.get_bone_parent(muslo)
		var base := _esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
		_esqueleto.set_bone_pose_rotation(muslo, (base.inverse() * muslo_nuevo).get_rotation_quaternion())
		_esqueleto.set_bone_pose_rotation(pierna, (muslo_nuevo.inverse() * pierna_nueva).get_rotation_quaternion())


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
