extends SceneTree

## Mide los clips de los GLB para data/acciones_v2.json (Motor V2, etapa 2).
## Lo corre tools/generar_acciones_v2.py, que le pasa las definiciones de
## Blender ya leídas: `-- definiciones=<json> salida=res://data/acciones_v2.json`.
##
## Por clip: duración real, fracción del contacto, punto que toca la pelota
## y dónde está ese punto en el cuadro de contacto (metros, relativo al pie
## del jugador: +z adelante, +x a su izquierda, +y arriba), si es un loop y
## si el cuerpo sigue corriendo mientras dura.

const PREFIJO := "[acciones_v2]"
const MODELOS := {"jugador": VistaCancha3D.ESCENA_JUGADOR, "golero": VistaCancha3D.ESCENA_GOLERO}
## Hueso de Blender -> punto del modelo que toca la pelota (nodos del GLB).
const ANCLA_DE_HUESO := {"Pie.R": "Pie_R", "Pie.L": "Pie_L", "Cabeza": "Frente", "Torso": "Pecho",
	"Antebrazo.L": "Mano_L", "Antebrazo.R": "Mano_R"}
## Clips en los que el cuerpo sigue avanzando con su locomoción mientras dura
## la acción: se patea, se controla o se gambetea corriendo. En el resto el
## cuerpo frena (con su frenada, sin clavarse) hasta que termina.
const SE_MUEVE_SUFIJOS := ["_Corriendo"]
const SE_MUEVE_PREFIJOS := ["Correr", "Trotar", "Caminar", "Forcejear", "Regate_", "Amague", "Efecto_Acomoda",
	"Remate_Efecto"]

## Los clips de andar: la vista los repite y los avanza con los metros
## recorridos (no con el reloj). Correr y Golero_Guardia no traen el loop
## marcado en el GLB.
const LOCOMOCION := ["Respirar", "Caminar", "Trotar", "Correr", "Correr_Gambeta", "Golero_Guardia",
	"Forcejear", "Forcejear_Izq"]

var _definiciones := {}
var _salida := "res://data/acciones_v2.json"
var _modelos := {}


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("definiciones="):
			_definiciones = JSON.parse_string(FileAccess.get_file_as_string(arg.get_slice("=", 1)))
		elif arg.begins_with("salida="):
			_salida = arg.get_slice("=", 1)
	for m in MODELOS:
		var p := Jugador3D.new(load(MODELOS[m]))
		root.add_child(p)
		_modelos[m] = p
	# Las anclas solo tienen posición con el modelo adentro del árbol.
	process_frame.connect(_medir, CONNECT_ONE_SHOT)


func _medir() -> void:
	var contacto_vista := _contactos_de_la_vista()
	var clips := {}
	for m in MODELOS:
		var p: Jugador3D = _modelos[m]
		for nombre in p.animador.get_animation_list():
			var anim := p.animador.get_animation(nombre)
			if clips.has(nombre):
				var c: Dictionary = clips[nombre]
				(c["modelos"] as Array).append(m)
				if absf(float(c["duracion"]) - anim.length) > 0.001:
					c["duracion_" + m] = snappedf(anim.length, 0.0001)
				continue
			var d: Dictionary = _definiciones.get(nombre, {})
			var c := {
				"duracion": snappedf(anim.length, 0.0001),
				"bucle": anim.loop_mode != Animation.LOOP_NONE or bool(d.get("bucle", false)) or nombre in LOCOMOCION,
				"locomocion": nombre in LOCOMOCION,
				"aerea": bool(d.get("aerea", false)),
				"mueve": _se_mueve(nombre),
				"modelos": [m],
				"contacto": null,
				"ancla": "",
			}
			if contacto_vista.has(nombre):
				c["contacto"] = snappedf(float(contacto_vista[nombre][1]), 0.0001)
				c["ancla"] = contacto_vista[nombre][0]
				c["fuente_contacto"] = "match/3d/vista_cancha_3d.gd CONTACTO_3D"
			elif d.get("contacto") != null and ANCLA_DE_HUESO.has(d.get("hueso", "")):
				c["contacto"] = snappedf(float(d["contacto"]), 0.0001)
				c["ancla"] = ANCLA_DE_HUESO[d["hueso"]]
				c["fuente_contacto"] = "tools/blender/animaciones_jugador.py"
			if c["contacto"] != null:
				var punto := _punto(p, nombre, float(c["contacto"]) * anim.length, str(c["ancla"]))
				c["punto_contacto"] = [snappedf(punto.x, 0.001), snappedf(punto.y, 0.001), snappedf(punto.z, 0.001)]
				c["alcance_m"] = snappedf(Vector2(punto.x, punto.z).length(), 0.001)
				c["altura_m"] = snappedf(punto.y, 0.001)
			clips[nombre] = c
	var nombres := clips.keys()
	nombres.sort()
	var ordenados := {}
	for n in nombres:
		ordenados[n] = clips[n]
	var datos := {
		"_notas": {
			"origen": "Lo genera tools/generar_acciones_v2.py; no editar a mano. Duración y punto de contacto medidos en assets/3d/jugador.glb y golero.glb; contacto y hueso de tools/blender/animaciones_jugador.py o, si la vista 3D lo verificó, de CONTACTO_3D (match/3d/vista_cancha_3d.gd).",
			"contacto": "Fracción de la duración en la que el punto `ancla` toca la pelota. null: el clip no toca la pelota (o todavía no se sabe dónde).",
			"punto_contacto": "Dónde está el ancla en ese cuadro, en metros desde el pie del jugador parado en el origen y mirando a +z: [x a su izquierda, y arriba, z adelante]. alcance_m es su distancia en el piso.",
			"locomocion": "Clip de andar (quieto, caminar, trotar, correr): no es una acción, lo elige la vista por la velocidad.",
			"mueve": "true: el cuerpo sigue con su locomoción durante el clip (se hace corriendo). false: frena hasta que termina.",
		},
		"clips": ordenados,
	}
	var archivo := FileAccess.open(_salida, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(datos, "\t", false) + "\n")
	archivo.close()
	var con_contacto := 0
	for n in ordenados:
		if ordenados[n]["contacto"] != null:
			con_contacto += 1
	print("%s ESCRITO %s: %d clips, %d con contacto" % [PREFIJO, _salida, ordenados.size(), con_contacto])
	quit()


## Animación -> [ancla, fracción] desde la vista 3D (CONTACTO_3D por acción,
## ANIM_DE_ACCION para saber qué clip es cada acción).
func _contactos_de_la_vista() -> Dictionary:
	var r := {}
	for accion in VistaCancha3D.CONTACTO_3D:
		if VistaCancha3D.ANIM_DE_ACCION.has(accion):
			r[VistaCancha3D.ANIM_DE_ACCION[accion]] = VistaCancha3D.CONTACTO_3D[accion]
	return r


static func _se_mueve(nombre: String) -> bool:
	for s in SE_MUEVE_SUFIJOS:
		if nombre.ends_with(s):
			return true
	for s in SE_MUEVE_PREFIJOS:
		if nombre.begins_with(s):
			return true
	return false


## El ancla en el segundo `tiempo` de `anim`, relativa al jugador (ver
## DetectorPatinaV2.ancla_de: sin cuadros dibujados, Jugador3D.ancla() no
## sirve).
func _punto(p: Jugador3D, anim: String, tiempo: float, ancla: String) -> Vector3:
	p.poner(anim, tiempo)
	if ancla == "manos":
		return (DetectorPatinaV2.ancla_de(p, "Mano_L") + DetectorPatinaV2.ancla_de(p, "Mano_R")) * 0.5 - p.global_position
	return DetectorPatinaV2.ancla_de(p, ancla) - p.global_position

