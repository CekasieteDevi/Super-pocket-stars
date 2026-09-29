class_name Materiales3D
extends RefCounted

## Reemplaza los materiales que trae cada GLB por los del estilo toon.
##
## Los GLB traen materiales PBR simples: solo sirven para saber el nombre y
## el color base de cada parte. El nombre decide el tratamiento (contorno,
## plano, semitransparente o toon). Los personajes no pasan por acá: traen
## un solo material (ver personaje.gdshader).

const SHADER_TOON := preload("res://match/3d/sombreado_toon.gdshader")
const SHADER_CONTORNO := preload("res://match/3d/contorno.gdshader")

## El casco invertido del contorno: el mismo marrón casi negro de Blender.
const COLOR_CONTORNO := Color("2a1712")

## Partes que en Blender eran emisión pura: no reciben sombra.
const PLANOS := ["Ojos", "Boca", "Lengua"]

static var _toon_compartidos := {}
static var _planos := {}
static var _contorno: ShaderMaterial


static func toon(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_TOON
	m.set_shader_parameter("color_base", color)
	return m


## Toon compartido por nombre: piel, suela o guantes son iguales para todos,
## así 22 jugadores no crean 22 copias del mismo material.
static func toon_compartido(nombre: String, color: Color) -> ShaderMaterial:
	var clave := "%s_%s" % [nombre, color.to_html()]
	if not _toon_compartidos.has(clave):
		_toon_compartidos[clave] = toon(color)
	return _toon_compartidos[clave]


## Una sola cara: el casco tiene las normales al revés y solo se ve por
## detrás del cuerpo, que es lo que dibuja la línea.
static func contorno() -> ShaderMaterial:
	if _contorno == null:
		_contorno = ShaderMaterial.new()
		_contorno.shader = SHADER_CONTORNO
		_contorno.set_shader_parameter("color_contorno", COLOR_CONTORNO)
	return _contorno


## Deja sin dibujar todo lo de `raiz` que está más allá de `corte_z` (el lado
## de la cámara), salvo los materiales de `excepto`. El contorno se copia:
## el compartido también lo usan los jugadores, que no se cortan.
static func cortar_lado_camara(raiz: Node, corte_z: float, excepto: Array) -> void:
	var contorno_cortado := contorno().duplicate() as ShaderMaterial
	contorno_cortado.set_shader_parameter("corte_z", corte_z)
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var original := mi.mesh.surface_get_material(i)
			var nombre := original.resource_name if original != null else ""
			if nombre in excepto:
				continue
			var actual := mi.get_surface_override_material(i)
			if actual == _contorno:
				mi.set_surface_override_material(i, contorno_cortado)
			elif actual is ShaderMaterial:
				(actual as ShaderMaterial).set_shader_parameter("corte_z", corte_z)


static func plano(color: Color) -> StandardMaterial3D:
	var clave := color.to_html()
	if not _planos.has(clave):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		_planos[clave] = m
	return _planos[clave]


static func color_de(m: Material) -> Color:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).albedo_color
	return Color.WHITE


## Recorre todas las mallas de `raiz` y cambia sus materiales.
## `propios`: nombre de material -> ShaderMaterial exclusivo de este nodo
## (lo que se tiñe por jugador). Lo que no está ahí usa el compartido.
## `respetar`: nombres cuyo material original se deja (la red del arco
## trae su textura con alfa).
static func aplicar(raiz: Node, propios: Dictionary = {}, respetar: Array = []) -> void:
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var original := mi.mesh.surface_get_material(i)
			var nombre := original.resource_name if original != null else ""
			if nombre in respetar:
				continue
			var nuevo: Material
			if nombre == "Contorno":
				nuevo = contorno()
			elif nombre in PLANOS:
				nuevo = plano(color_de(original))
			elif propios.has(nombre):
				nuevo = propios[nombre]
			else:
				nuevo = toon_compartido(nombre, color_de(original))
			mi.set_surface_override_material(i, nuevo)
