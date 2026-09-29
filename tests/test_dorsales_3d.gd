extends SceneTree
## Dorsales del 3D (tools/generar_numeros.py, Jugador3D.poner_numero):
##
## 1. El atlas trae las 10 cifras, cada una en su celda y sin tocar el borde.
## 2. jugador.glb y golero.glb: la espalda de la camiseta lleva el UV2 del
##    rectángulo del número (marcada en el alfa del color) y el frente no.
## 3. poner_numero reparte las cifras y el color sale de la camiseta, el
##    mismo del número del 2D.
## 4. En un partido real cada jugador 3D muestra el dorsal de su fotograma.

const SEED := 22
const DIVISION := 0

var fallos := 0
var _rep: VistaPartido
var _vista: VistaCancha3D
var _cuadros := 0


func _initialize() -> void:
	_probar_atlas()
	for ruta in ["res://assets/3d/jugador.glb", "res://assets/3d/golero.glb"]:
		_probar_glb(ruta)
	_probar_cifras()
	process_frame.connect(_cuadro)


func _terminar() -> void:
	print("FALLOS=", fallos)
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("OK: ", texto)
	else:
		fallos += 1
		print("FALLA: ", texto)


func _probar_atlas() -> void:
	var img := Jugador3D.ATLAS_NUMEROS.get_image()
	if img.is_compressed():
		img.decompress()
	_ok(img.get_width() == img.get_height() * 5, "atlas: 10 celdas de 1:2 (%dx%d)" % [img.get_width(), img.get_height()])
	var ancho := img.get_width() / 10
	for n in 10:
		var tinta := 0
		var borde := 0
		for y in range(0, img.get_height(), 2):
			for x in range(n * ancho, (n + 1) * ancho, 2):
				if img.get_pixel(x, y).a > 0.5:
					tinta += 1
					if x - n * ancho < 2 or (n + 1) * ancho - x <= 2 or y < 2 or img.get_height() - y <= 2:
						borde += 1
		_ok(tinta > 200, "atlas: la cifra %d tiene tinta (%d)" % [n, tinta])
		_ok(borde == 0, "atlas: la cifra %d no toca el borde de su celda" % n)


func _probar_glb(ruta: String) -> void:
	var nombre := ruta.get_file()
	var j := Jugador3D.new(load(ruta) as PackedScene)
	var mi: MeshInstance3D = j.find_children("*", "MeshInstance3D", true, false)[0]
	var datos := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV2]
	var colores: PackedColorArray = datos[Mesh.ARRAY_COLOR]
	var normales: PackedVector3Array = datos[Mesh.ARRAY_NORMAL]
	var en_espalda := 0
	var adentro := 0
	var al_frente := 0
	for i in pos.size():
		if roundi(uv[i].x) != Jugador3D.TIPO_CAMISETA or colores[i].a < 0.5:
			continue
		if normales[i].z > 0.0:
			al_frente += 1
		else:
			en_espalda += 1
			if uv2[i].x >= 0.0 and uv2[i].x <= 1.0 and uv2[i].y >= 0.0 and uv2[i].y <= 1.0:
				adentro += 1
	_ok(al_frente == 0, "%s: el frente de la camiseta no lleva número" % nombre)
	_ok(en_espalda > 50, "%s: la espalda lleva el UV2 del número (%d vértices)" % [nombre, en_espalda])
	_ok(adentro >= 4, "%s: hay espalda adentro del rectángulo del número (%d)" % [nombre, adentro])
	j.free()


func _probar_cifras() -> void:
	var j := Jugador3D.new(load("res://assets/3d/jugador.glb") as PackedScene)
	var m: ShaderMaterial = (j.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override
	var casos := {0: [0, 0, 0], 7: [1, 7, 7], 10: [2, 1, 0], 99: [2, 9, 9], 23: [2, 2, 3]}
	for n in casos:
		j.poner_numero(n)
		var hay := [m.get_shader_parameter("cifras"), m.get_shader_parameter("cifra_1"), m.get_shader_parameter("cifra_2")]
		var espera: Array = casos[n]
		_ok(hay[0] == espera[0] and (espera[0] == 0 or (hay[1] == espera[1] and hay[2] == espera[2])),
			"dorsal %d: cifras %s" % [n, str(hay)])
	j.colorear(Color("111111"), Color.TRANSPARENT, Color.BLACK)
	_ok((m.get_shader_parameter("color_numero") as Color).get_luminance() > 0.8, "camiseta oscura: número claro")
	j.colorear(Color("f4f4f0"), Color.TRANSPARENT, Color.BLACK)
	_ok((m.get_shader_parameter("color_numero") as Color).get_luminance() < 0.2, "camiseta clara: número oscuro")
	j.espejado = true
	_ok(float(m.get_shader_parameter("espejo")) == 1.0, "espejado: el número se da vuelta")
	j.free()


# ------------------------------------------------- 4. partido reproducido

func _armar_partido() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var potencial := NivelDivision.potencial(DIVISION)
	var realizacion := NivelDivision.realizacion(DIVISION)
	var local := Team.generar("Atlético Prueba", rng, 0, potencial, "Uruguay", realizacion)
	var visita := Team.generar("Deportivo Banco", rng, 1000, potencial, "Uruguay", realizacion)
	var r := MotorEspacial.simular(local, visita, rng, true)
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
	_rep.posicion = 40.0


func _cuadro() -> void:
	_cuadros += 1
	if _cuadros == 1:
		_armar_partido()
	if _cuadros < 6:
		return
	var numeros := {}
	for j in _vista._jugadores_cuadro:
		numeros[int(j["id"])] = [int(j.get("numero", 0)), bool(j["equipo_local"])]
	var bien := 0
	var mal := []
	var oficiales_sin := 0
	var por_equipo := {true: [], false: []}
	for p in _vista._personas.values():
		var j := p as Jugador3D
		if not j.visible:
			continue
		if j.clave_motor < 0:
			if j.numero == 0:
				oficiales_sin += 1
			else:
				mal.append("oficial con %d" % j.numero)
			continue
		var espera: Array = numeros.get(j.clave_motor, [-1, true])
		if j.numero == int(espera[0]) and j.numero >= 1 and j.numero <= Team.DORSAL_MAXIMO:
			bien += 1
			(por_equipo[espera[1]] as Array).append(j.numero)
		else:
			mal.append("clave %d: %d (fotograma %d)" % [j.clave_motor, j.numero, int(espera[0])])
	_ok(bien >= 20 and mal.is_empty(), "partido: cada jugador lleva el dorsal de su fotograma (%d bien, %s)" % [bien, str(mal)])
	_ok(oficiales_sin >= 1, "partido: los oficiales sin número (%d)" % oficiales_sin)
	for local in [true, false]:
		var lista: Array = por_equipo[local]
		var distintos := {}
		for n in lista:
			distintos[n] = true
		_ok(distintos.size() == lista.size(), "partido: dorsales sin repetir en el %s %s" % ["local" if local else "visitante", str(lista)])
	_terminar()
