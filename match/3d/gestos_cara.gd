class_name GestosCara
extends RefCounted

## Qué gesto pone cada jugador en cada momento del partido 3D (ver
## Jugador3D.Gesto y tools/generar_caras.py):
##
## - Dolor: mientras cae por una falta ("cae") o se lesiona ("lesionado"), y
##   el lesionado desde que se lastima hasta que sale de la cancha.
## - Feliz / triste: después de un gol, el equipo que lo hizo y el que lo
##   recibió, hasta un rato después del saque del medio. También el que
##   festeja en la grabación.
## - Normal (con parpadeo) el resto del tiempo.
##
## Se arma una vez por grabación, mirando los eventos de los fotogramas.

## Después del saque del medio el gesto dura esto (ticks de 0.25 s): 2 s
## para que se vea al volver al juego y no quede toda la jugada siguiente.
const EMOCION_TRAS_SAQUE_TICKS := 8.0
## En la tanda no hay saque del medio: el gesto dura esto desde el penal.
const EMOCION_PENAL_TANDA_TICKS := 12.0
const ACCIONES_CON_DOLOR := ["cae", "lesionado"]

## Los oficiales tienen una cara fija, seria (la del "concentrado").
const CARA_OFICIAL := 13


## {"goles": [[desde, hasta, anota_local], ...], "lesiones": {clave: tick}}.
static func preparar(fotos: Array, nombre_local: String) -> Dictionary:
	var goles := []
	var lesiones := {}
	for k in fotos.size():
		for ev in fotos[k].get("eventos", []):
			var resultado := str(ev.get("resultado", ""))
			if resultado == "lesion" and ev.has("clave"):
				lesiones[int(ev["clave"])] = float(k)
			elif resultado == "gol":
				var local := _anota_local(fotos[k], ev, nombre_local)
				var hasta := float(_fin_de_la_pausa(fotos, k)) + EMOCION_TRAS_SAQUE_TICKS
				if str(ev.get("tipo", "")) == "penal_tanda":
					hasta = float(k) + EMOCION_PENAL_TANDA_TICKS
				goles.append([float(k), hasta, local])
	return {"goles": goles, "lesiones": lesiones}


## El gesto de `clave` (del equipo local o no) en el tick `t` de la
## reproducción, haciendo `accion`.
static func gesto(datos: Dictionary, clave: int, es_local: bool, accion: String, t: float) -> int:
	if accion in ACCIONES_CON_DOLOR:
		return Jugador3D.Gesto.DOLOR
	var lesiones: Dictionary = datos.get("lesiones", {})
	if lesiones.has(clave) and t >= float(lesiones[clave]):
		return Jugador3D.Gesto.DOLOR
	# El último gol que todavía dura manda (dos goles seguidos en la tanda).
	var goles: Array = datos.get("goles", [])
	for i in range(goles.size() - 1, -1, -1):
		var g: Array = goles[i]
		if t >= float(g[0]) and t <= float(g[1]):
			return Jugador3D.Gesto.FELIZ if bool(g[2]) == es_local else Jugador3D.Gesto.TRISTE
	if accion == MotorEspacial.ACCION_FESTEJA:
		return Jugador3D.Gesto.FELIZ
	return Jugador3D.Gesto.NORMAL


## Qué equipo hizo el gol. El evento trae el NOMBRE del equipo que suma (en
## el gol en contra también, ver MotorEspacial); si los dos se llaman igual,
## el de la clave del que convirtió.
static func _anota_local(fotograma: Dictionary, ev: Dictionary, nombre_local: String) -> bool:
	var equipo := str(ev.get("equipo", ""))
	var rival := str(ev.get("rival", ""))
	if equipo != "" and nombre_local != "" and equipo != rival:
		return equipo == nombre_local
	var clave := int(ev.get("clave", -1))
	for j in fotograma.get("jugadores", []):
		if int(j["id"]) == clave:
			return bool(j["equipo_local"])
	return equipo == nombre_local


## El mismo corte que VistaPartido._fin_de_la_pausa: el festejo termina en
## el primer fotograma con corte o sin pausa (el saque del medio).
static func _fin_de_la_pausa(fotos: Array, k: int) -> int:
	for i in range(k + 1, fotos.size()):
		var f: Dictionary = fotos[i]
		if not f.has("detenido"):
			return k
		if bool(f.get("corte", false)) or int(f["detenido"]) == 0:
			return i
	return k
