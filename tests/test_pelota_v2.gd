extends SceneTree

## Etapa 1 del Motor V2 (docs/motor_v2.md): la pelota en C++ (PelotaV2Nativa)
## cumple el "pasa si" de la etapa con los disparos del laboratorio
## (DisparosPelotaV2), sin mirarla:
## - el saque de arco pica 2 o 3 veces y rueda;
## - un tiro con efecto se curva de forma visible;
## - un tiro al palo o al travesaño rebota, sin casos especiales;
## - SALTO_PELOTA = 0: nunca avanza en un paso más de lo que da su velocidad.
## Además: misma patada = misma huella, los valores de pelota.h son los del
## JSON, y el césped y el clima cambian la pelota.

const SEED := 20260930
## Una curva "visible" desde la cámara del partido: más que el ancho de un
## cuerpo y medio a lo ancho de la recta de la patada.
const DESVIO_VISIBLE_M := 1.0

var fallos := 0
var _pelota: Object


func _init() -> void:
	if not ClassDB.class_exists("PelotaV2Nativa"):
		_ok(false, "la extensión motor_v2 está armada para esta plataforma (motor_v2/bin)")
		print("FALLOS=%d" % fallos)
		quit(1)
		return
	_pelota = ClassDB.instantiate("PelotaV2Nativa")
	var p := FisicaV2.parametros()
	var m := {}
	for d in DisparosPelotaV2.lista():
		m[d["nombre"]] = DisparosPelotaV2.medir(_pelota, p, d)
		_ok(int(m[d["nombre"]]["saltos"]) == 0, "%s: SALTO_PELOTA = 0 (peor exceso %s m)" % [
			d["nombre"], m[d["nombre"]]["peor_exceso_m"]])

	var saque: Dictionary = m["Saque de arco"]
	_ok(saque["piques"] >= 2 and saque["piques"] <= 3, "el saque de arco pica 2 o 3 veces (%d)" % saque["piques"])
	_ok(saque["rodo_m"] > 3.0 and saque["quieta"], "después rueda y se para (%.1f m rodando)" % saque["rodo_m"])
	_ok(saque["primer_pique_x"] > 0.0, "el saque de arco pasa la mitad de la cancha (pica en x = %.1f)"
		% saque["primer_pique_x"])

	var efecto: Dictionary = m["Tiro con efecto"]
	var recto := DisparosPelotaV2.buscar("Tiro con efecto").duplicate()
	recto["giro"] = Vector3.ZERO
	var sin_giro := DisparosPelotaV2.medir(_pelota, p, recto)
	_ok(efecto["desvio_m"] > DESVIO_VISIBLE_M, "el tiro con efecto se curva %.2f m" % efecto["desvio_m"])
	_ok(sin_giro["desvio_m"] < 0.05, "la misma patada sin giro va derecha (%.2f m)" % sin_giro["desvio_m"])
	_ok(_es_gol(efecto["fin"], p) and not _es_gol(sin_giro["fin"], p),
		"con efecto entra y sin efecto se va afuera")

	var palo: Dictionary = m["Tiro al palo"]
	_ok(palo["palos"] == 1 and palo["volvio"] == false and not _es_gol(palo["fin"], p),
		"el tiro al palo pega una vez y sale afuera (fin %s)" % palo["fin"])
	var travesano: Dictionary = m["Tiro al travesaño"]
	_ok(travesano["travesanos"] == 1 and travesano["volvio"], "el tiro al travesaño pega y vuelve a la cancha")
	var red: Dictionary = m["Remate a la red"]
	_ok(red["redes"] >= 1 and _es_gol(red["fin"], p) and red["quieta"],
		"el remate a la red queda muerto adentro del arco (fin %s)" % red["fin"])
	var globo: Dictionary = m["Globo"]
	_ok(globo["altura_max"] > 8.0 and _es_gol(globo["fin"], p), "el globo sube %.1f m y cae adentro" % globo["altura_max"])

	# Misma patada, mismo resultado, bit a bit.
	for d in DisparosPelotaV2.lista():
		var otra := DisparosPelotaV2.medir(_pelota, p, d)
		if otra["huella"] != m[d["nombre"]]["huella"]:
			_ok(false, "%s: la misma patada da otra huella" % d["nombre"])
	_ok(true, "cada disparo repetido da la misma huella")

	# Una sola fuente de verdad: los valores por defecto de pelota.h son los
	# del JSON. Si alguien cambia uno solo, este test lo avisa.
	var todos_iguales := true
	for d in DisparosPelotaV2.lista():
		var sin_configurar := DisparosPelotaV2.medir(_pelota, {}, d)
		todos_iguales = todos_iguales and sin_configurar["huella"] == m[d["nombre"]]["huella"]
	_ok(todos_iguales, "pelota.h y data/fisica_v2.json tienen los mismos valores")

	# Césped y clima. Una pelota que rueda sola: pase rasante a 12 m/s.
	var pase := {"pos": Vector3(0.0, 0.11, 0.0), "vel": Vector3(12.0, 0.0, 0.0), "giro": Vector3.ZERO,
		"segundos": 20.0}
	var normal := _hasta(pase, p)
	var mala := _hasta(pase, FisicaV2.parametros(EstadoCancha.MINIMO))
	var buena := _hasta(pase, FisicaV2.parametros(EstadoCancha.MAXIMO))
	var lluvia := _hasta(pase, FisicaV2.parametros(0.0, "Lluvia"))
	_ok(mala < normal and normal < buena, "la peor cancha frena más la rodada (%.1f / %.1f / %.1f m)"
		% [mala, normal, buena])
	_ok(lluvia > normal, "con lluvia la pelota corre más (%.1f contra %.1f m)" % [lluvia, normal])
	var saque_mala := DisparosPelotaV2.medir(_pelota, FisicaV2.parametros(EstadoCancha.MINIMO),
		DisparosPelotaV2.buscar("Saque de arco"))
	_ok(saque_mala["piques"] <= saque["piques"], "en la peor cancha el saque no pica más (%d)" % saque_mala["piques"])
	var globo_d := DisparosPelotaV2.buscar("Globo")
	var a_favor := DisparosPelotaV2.medir(_pelota, FisicaV2.parametros(0.0, "Viento", Vector2.RIGHT), globo_d)
	var en_contra := DisparosPelotaV2.medir(_pelota, FisicaV2.parametros(0.0, "Viento", Vector2.LEFT), globo_d)
	_ok(a_favor["primer_pique_x"] > globo["primer_pique_x"] and globo["primer_pique_x"] > en_contra["primer_pique_x"],
		"el viento estira o acorta el globo (pica en %.1f / %.1f / %.1f)"
		% [en_contra["primer_pique_x"], globo["primer_pique_x"], a_favor["primer_pique_x"]])

	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _es_gol(fin: Vector3, p: Dictionary) -> bool:
	return absf(fin.x) > float(p["medio_largo"]) + float(p["radio"]) and absf(fin.z) < float(p["arco_medio_ancho"])


## Hasta dónde llega una pelota que rueda.
func _hasta(d: Dictionary, p: Dictionary) -> float:
	var r := DisparosPelotaV2.medir(_pelota, p, d)
	return (r["fin"] as Vector3).x


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
