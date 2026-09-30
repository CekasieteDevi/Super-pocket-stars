class_name DetectorPatinaV2
extends RefCounted

## Detector PATINA del Motor V2 (docs/motor_v2.md, "Herramientas"): cuánto
## desliza en el mundo el pie que está apoyado. Mide sobre la vista (los
## Jugador3D ya puestos), no sobre el motor, porque el patinaje es la
## diferencia entre lo que avanza el cuerpo y lo que la animación deja atrás
## el pie. Funciona sin pantalla.
##
## Un pie cuenta como apoyado si está a menos de APOYO_M del punto más bajo
## que tocó un pie en lo que va de la medición. Con los clips actuales el
## pie casi no se levanta (Caminar entre 5,6 y 7,1 cm), así que el umbral es
## chico.

const APOYO_M := 0.015
const PIES := ["Pie_L", "Pie_R"]

## jugador -> {pie: Vector3 del cuadro anterior}
var _previos := {}
## clip -> [metros deslizados apoyado, segundos apoyado]
var por_clip := {}
var _suelo := INF


## Un cuadro: `delta` segundos desde el anterior.
func medir(jugadores: Array, delta: float) -> void:
	if delta <= 0.0:
		return
	for p3: Jugador3D in jugadores:
		var anim := p3._anim_actual
		var previos: Dictionary = _previos.get(p3, {})
		var ahora := {}
		for pie in PIES:
			var punto := ancla_de(p3, pie)
			ahora[pie] = punto
			_suelo = minf(_suelo, punto.y - p3.global_position.y)
			if not previos.has(pie):
				continue
			var antes: Vector3 = previos[pie]
			var alto := minf(punto.y, antes.y) - p3.global_position.y
			if alto > _suelo + APOYO_M:
				continue
			var dato: Array = por_clip.get(anim, [0.0, 0.0])
			dato[0] += Vector2(punto.x - antes.x, punto.z - antes.z).length()
			dato[1] += delta
			por_clip[anim] = dato
		_previos[p3] = ahora


## m/s que desliza el pie apoyado, promedio de un clip (o de todos con "").
func patina(clip := "") -> float:
	var metros := 0.0
	var segundos := 0.0
	for n in por_clip:
		if clip == "" or n == clip:
			metros += float(por_clip[n][0])
			segundos += float(por_clip[n][1])
	return metros / segundos if segundos > 0.0 else 0.0


## Dónde está en el mundo un punto del modelo (Pie_L, Frente, Mano_R...).
## Jugador3D.ancla() lee el BoneAttachment3D, que sin cuadros dibujados no se
## actualiza: acá se arma desde el hueso, con la pose de este momento.
static func ancla_de(p: Jugador3D, nombre: String) -> Vector3:
	for nodo in p.find_children(nombre, "Node3D", true, false):
		var union := nodo.get_parent() as BoneAttachment3D
		if union == null:
			continue
		var sk := union.get_parent() as Skeleton3D
		var b := sk.find_bone(union.bone_name)
		return sk.global_transform * sk.get_bone_global_pose(b) * (nodo as Node3D).transform.origin
	return p.global_position
