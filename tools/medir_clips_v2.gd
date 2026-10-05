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
const MODELOS := {"jugador": Cancha3D.ESCENA_JUGADOR, "golero": Cancha3D.ESCENA_GOLERO}
## Hueso de Blender -> punto del modelo que toca la pelota (nodos del GLB).
const ANCLA_DE_HUESO := {"Pie.R": "Pie_R", "Pie.L": "Pie_L", "Cabeza": "Frente", "Torso": "Pecho", "Muslo.R": "Muslo_R",
	"Antebrazo.L": "Mano_L", "Antebrazo.R": "Mano_R"}
## Clips en los que el cuerpo sigue avanzando con su locomoción mientras dura
## la acción: se patea, se controla o se gambetea corriendo. En el resto el
## cuerpo frena (con su frenada, sin clavarse) hasta que termina.
const SE_MUEVE_SUFIJOS := ["_Corriendo"]
const SE_MUEVE_PREFIJOS := ["Correr", "Trotar", "Caminar", "Forcejear", "Regate_", "Amague", "Efecto_Acomoda",
	"Remate_Efecto"]

## Los clips de andar que se repiten: la vista los elige por la velocidad y
## los avanza con los metros recorridos (no con el reloj). Correr y
## Golero_Guardia no traen el loop marcado en el GLB. También son de andar
## los clips en cinta de Blender (Arranque, Frenada, giros, de costado y de
## espaldas): traen "cinta" en las definiciones.
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
				"locomocion": nombre in LOCOMOCION or d.has("cinta"),
				"aerea": bool(d.get("aerea", false)),
				"mueve": _se_mueve(nombre),
				"modelos": [m],
				"contacto": null,
				"ancla": "",
			}
			if d.has("cinta"):
				for k in d["cinta"]:
					c[k] = d["cinta"][k]
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
			"metros": "Clips en cinta (el pie apoyado retrocede a la velocidad del cuerpo): metros del juego que avanza el cuerpo en todo el clip; en un loop, por ciclo. La vista avanza el clip con los metros reales y el pie apoyado queda quieto en la cancha.",
			"avance_m": "Metros avanzados en cada cuadro del clip (24 por segundo, desde el primero), hacia `direccion` = [x a su izquierda, z adelante]. Arranque y Frenada no avanzan parejo: la vista busca en esta lista el segundo que corresponde a lo recorrido.",
			"giro": "Grados que gira la cadera durante el clip (+ = hacia su izquierda). La vista deja el modelo con el rumbo del principio mientras dura.",
			"giro_por_cuadro": "Grados girados en cada cuadro del clip: la vista busca el segundo que corresponde a lo que ya giró el cuerpo.",
			"fase_inicial": "Frenada: la fase de Correr con la que empieza (el derecho apoyando).",
			"fase_final": "Arranque: la fase de Correr en la que termina; la vista sigue con Correr desde ahí.",
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


## Animación -> [ancla, fracción del clip en que toca la pelota]. Salió de
## la vista 3D del motor espacial (CONTACTO_3D por acción) antes de borrarla.
## Las estiradas a la izquierda y la alta usan los cuadros de Atajar_Volando
## (estirado en 10/24); las paradas tienen las manos en la pelota en 6/24
## (animaciones_jugador.py, "ATAJADAS POR ZONA").
const CONTACTO_DE_CLIP := {
	"Agarrar": ["manos", 0.0],
	"Arquero_Lanza": ["Mano_R", 14.0 / 24.0],
	"Arquero_Voleo": ["Pie_R", 0.5],
	"Atajar_Volando": ["manos", 10.0 / 24.0],
	"Atajar_Volando_Izq": ["manos", 10.0 / 24.0],
	"Atajar_Volando_Alto": ["manos", 10.0 / 24.0],
	"Atajar_Volando_Alto_Izq": ["manos", 10.0 / 24.0],
	"Atajar_Arriba": ["manos", 0.25],
	"Atajar_Abajo": ["manos", 0.25],
	"Barrida": ["Pie_L", 8.0 / 24.0],
	"Bloquear": ["Pie_R", 5.0 / 18.0],
	"Cabecear": ["Frente", 14.0 / 24.0],
	"Chilena": ["Pie_R", 11.0 / 30.0],
	"Control_Corriendo": ["Pie_R", 8.0 / 24.0],
	"Lateral": ["manos", 0.25],
	"Palomita": ["Frente", 0.375],
	"Patear_Corriendo": ["Pie_R", 4.0 / 11.0],
	"Pecho": ["Pecho", 0.0],
	# Los regates: el cuadro en que el pie derecho cruza la pelota hacia la
	# izquierda (tools/blender/animaciones_jugador.py). Croqueta: la pelota
	# va del derecho al izquierdo desde la fase 0,30. Elástica: el exterior la
	# saca hasta el cuadro 8 de 19 y el interior la cruza desde ahí.
	"Regate_Croqueta": ["Pie_R", 0.3],
	"Regate_Elastica": ["Pie_R", 8.0 / 18.0],
	"Saque_Arco": ["Pie_R", 0.5],
	"Taco": ["Talon_R", 0.5],
	"Volea": ["Pie_R", 7.0 / 18.0],
}


func _contactos_de_la_vista() -> Dictionary:
	return CONTACTO_DE_CLIP.duplicate(true)


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

