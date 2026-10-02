class_name FisicaV2
extends RefCounted

## Parámetros de la física del Motor V2 (docs/motor_v2.md): lee
## data/fisica_v2.json y les aplica el césped y el clima del partido (etapa
## 1), y arma los del cuerpo y sus clips (etapa 2). El resultado se le pasa al
## motor en C++ (PelotaV2Nativa, CuerposV2Nativos, MundoV2Nativo): así se
## calibra sin recompilar.

const RUTA := "res://data/fisica_v2.json"
const RUTA_ACCIONES := "res://data/acciones_v2.json"

static var _datos: Dictionary = {}
static var _acciones: Dictionary = {}


static func datos() -> Dictionary:
	if _datos.is_empty():
		var texto := FileAccess.get_file_as_string(RUTA)
		var leido: Variant = JSON.parse_string(texto)
		assert(leido is Dictionary, "No se pudo leer %s" % RUTA)
		_datos = leido
	return _datos


## `calidad_cancha`: la de EstadoCancha del local (-8 a +3, 0 = neutra).
## `clima`: el de Clima ("" o "Normal" = sin cambios). `direccion_viento`:
## hacia dónde sopla, en el plano de la cancha (x a lo largo, y a lo ancho).
static func parametros(calidad_cancha := 0.0, clima := "", direccion_viento := Vector2.RIGHT) -> Dictionary:
	var d := datos()
	var p: Dictionary = (d["pelota"] as Dictionary).duplicate()
	var cesped: Dictionary = d["cesped"]
	p["frenado_rodando"] = float(p["frenado_rodando"]) * (1.0 + float(cesped["frenado_por_punto"]) * calidad_cancha)
	p["restitucion_piso"] = float(p["restitucion_piso"]) + float(cesped["restitucion_por_punto"]) * calidad_cancha
	var por_clima: Dictionary = (d["clima"] as Dictionary).get(clima, {})
	for clave in por_clima:
		if clave == "viento_ms":
			var v := direccion_viento.normalized() * float(por_clima[clave])
			p["viento_x"] = v.x
			p["viento_z"] = v.y
		else:
			p[clave] = float(p[clave]) * float(por_clima[clave])
	return p


## Los de la locomoción y los gestos (CuerposV2Nativos.configurar,
## MundoV2Nativo.configurar_cuerpos). La locomoción usa los números del motor
## actual (MotorEspacial.pesos(): fisica, control y esfuerzo), así los dos
## motores corren igual; de data/fisica_v2.json sale solo lo nuevo.
static func parametros_cuerpo() -> Dictionary:
	var fisica: Dictionary = MotorEspacial.pesos()["fisica"]
	var p := {
		"frenada": float(fisica["frenada"]),
		"giro_acel": float(fisica["giro_acel"]),
		"arranque_extra": float(fisica["arranque_extra"]),
		"rapidez_para_girar": float(MotorEspacial.pesos_control()["rapidez_para_girar"]),
	}
	var esfuerzo := MotorEspacial.pesos_esfuerzo()
	for clave in ["peso_aceleracion", "umbral_sprint", "consumo_sprint", "recuperacion_reserva",
			"reserva_para_frenar", "piso_sprint"]:
		p[clave] = float(esfuerzo[clave])
	p.merge(datos()["cuerpo"])
	return p


## Los clips de data/acciones_v2.json (lo genera tools/generar_acciones_v2.py).
static func clips() -> Dictionary:
	if _acciones.is_empty():
		var leido: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_ACCIONES))
		assert(leido is Dictionary, "No se pudo leer %s" % RUTA_ACCIONES)
		_acciones = leido
	return _acciones["clips"]


## El físico de un jugador para el cuerpo, con las mismas cuentas que el motor
## actual: `atributos` como los de Player (velocidad, aceleracion, agilidad).
## `energia` (0..1, la del partido) baja punta y aceleración con
## Cansancio.factor_stats. El motor actual no la aplica al andar (solo a los
## duelos); el V2 sí, porque la carrera es parte del físico.
static func fisico_de(atributos: Dictionary, energia := 1.0) -> Dictionary:
	var j := {"atributos": atributos}
	return {
		"vel_max": MotorEspacial._vel_max(j),
		"aceleracion": MotorEspacial._aceleracion(j),
		"giro": MotorEspacial._giro_de(j),
		"cansancio": Cansancio.factor_stats(energia),
	}


## Etapa 7: por cuánto se multiplican la punta y la aceleración de un jugador
## según cuántos puntos de media le saca al nivel del partido
## (MatchEngine.nivel_partido). data/fisica_v2.json, "nivel".
## `nivel`: el del partido; cada punto pesa según peso_del_nivel.
static func ventaja_de_nivel(puntos: float, nivel := -1.0) -> float:
	var n: Dictionary = datos()["nivel"]
	var peso := peso_del_nivel(nivel)
	var tope := float(n["rapidez_tope"]) * peso
	return 1.0 + clampf(float(n["rapidez_por_punto"]) * puntos * peso, -tope, tope)


## Etapa 7: cuánto pesa un punto de media según el nivel del partido:
## (nivel / nivel.referencia) ^ nivel.exponente. Un punto pesa más arriba que
## abajo. Con el mismo peso en todas las divisiones, primera le sacaba 0,4
## goles a segunda (el motor espacial: 1,0) y novena le sacaba 1,6 a décima
## (1,0): la física del V2 usa los atributos absolutos y el motor espacial los
## relativos al nivel del partido. Sin `nivel` (o con exponente 0), 1.
static func peso_del_nivel(nivel: float) -> float:
	var n: Dictionary = datos()["nivel"]
	var exponente := float(n.get("exponente", 0.0))
	if nivel <= 0.0 or exponente == 0.0:
		return 1.0
	return pow(nivel / float(n["referencia"]), exponente)


## Etapa 7: puntos que se suman (o restan) a pases y control según cuántos
## puntos de media le saca el equipo al nivel del partido. data/fisica_v2.json,
## "nivel".
static func tecnica_de_nivel(puntos: float, nivel := -1.0) -> float:
	return float(datos()["nivel"].get("tecnica_por_punto", 0.0)) * puntos * peso_del_nivel(nivel)


## Los del toque (etapa 3; CanchitaV2Nativa.configurar): data/fisica_v2.json,
## "toque". Los clips van por nombre y el motor los busca en clips().
static func parametros_toque() -> Dictionary:
	return (datos()["toque"] as Dictionary).duplicate(true)


## Lo nuevo del cerebro (etapa 4; CanchitaV2Nativa.configurar_cerebro):
## data/fisica_v2.json, "cerebro". El resto de sus pesos es MotorEspacial.pesos().
static func parametros_cerebro() -> Dictionary:
	return (datos()["cerebro"] as Dictionary).duplicate(true)


## El físico de fisico_de más lo que usa el toque (etapa 3): pases y control,
## como los de Player (0..100).
static func jugador_de(atributos: Dictionary, energia := 1.0) -> Dictionary:
	var f := fisico_de(atributos, energia)
	f["pases"] = float(atributos.get("pases", 50.0))
	f["control"] = float(atributos.get("control", 50.0))
	return f


## Etapa 5 (CanchitaV2Nativa.configurar_remate): data/fisica_v2.json, "remate".
static func parametros_remate() -> Dictionary:
	return (datos()["remate"] as Dictionary).duplicate(true)


## Etapa 5: data/fisica_v2.json, "arquero", más el achique del motor espacial
## (data/utility_pesos.json, "arquero"): una sola fuente para los dos motores.
static func parametros_arquero() -> Dictionary:
	var p: Dictionary = (datos()["arquero"] as Dictionary).duplicate(true)
	var espacial := MotorEspacial.pesos_arquero()
	for clave in ["achique_min", "achique_max", "achique_dist_rival", "achique_margen_pelota", "achique_carril",
			"ventaja_base", "ventaja_por_metro"]:
		p[clave] = float(espacial[clave])
	# Parado o estirada: la misma regla que la vista 3D actual.
	p["parada_max_m"] = VistaCancha3D.PARADA_TRAVESIA_M
	return p


## Etapa 6 (CanchitaV2Nativa.configurar_reglas): data/fisica_v2.json, "reglas",
## más lo que ya existía en otro lado, para que los dos motores lean lo mismo:
## el tiro libre (data/utility_pesos.json, "fisica"), las medidas y el
## ejecutor del motor espacial, el entretiempo ("esfuerzo"), las franjas de
## Cansancio y los cambios de Team. `tanda`: si el partido empatado se define
## por penales.
static func parametros_reglas(tanda := false) -> Dictionary:
	var p: Dictionary = (datos()["reglas"] as Dictionary).duplicate(true)
	var fisica: Dictionary = MotorEspacial.pesos()["fisica"]
	for clave in ["rango_libre_malo", "rango_libre_bueno", "angulo_minimo_tiro_libre", "dist_libre_al_area",
			"dist_para_colgar_lejos"]:
		p[clave] = float(fisica[clave])
	var esfuerzo := MotorEspacial.pesos_esfuerzo()
	p["recuperacion_entretiempo"] = float(esfuerzo["recuperacion_entretiempo"])
	p["tope_entretiempo"] = float(esfuerzo["tope_entretiempo"])
	# El partido dura de verdad lo mismo que en el motor espacial (2 minutos por
	# tiempo) y el reloj muestra 0-90: decisión del usuario en la etapa 7.
	p["segundos_tiempo"] = MotorEspacial.SEGUNDOS_POR_MITAD
	p["minutos_tiempo"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD
	p["cierre_max_seg"] = float(MotorEspacial.TICKS_DE_DESCUENTO) * MotorEspacial.TICK_SEG
	p["distancia_penal_m"] = MotorEspacial.DIST_PENAL
	p["radio_circulo_m"] = MotorEspacial.RADIO_CIRCULO
	p["ejecutor_max_m"] = MotorEspacial.DIST_MAX_AL_EJECUTOR
	var pisos := []
	for pct in Cansancio.FRANJA_PISO_PCT:
		pisos.append(float(pct) / 100.0)
	p["franja_piso"] = pisos
	p["factor_franja"] = Cansancio.FACTOR_FRANJA.duplicate()
	p["riesgo_franja"] = Cansancio.RIESGO_LESION_POR_FRANJA.duplicate()
	p["energia_minima"] = Cansancio.ENERGIA_MINIMA
	p["cambios_max"] = Team.MAX_CAMBIOS
	p["tanda"] = tanda
	return p


## Lo de cada club que leen las reglas (CanchitaV2Nativa.configurar_reglas_equipo).
static func reglas_del_club(equipo: Team) -> Dictionary:
	return {
		"umbral_cambio": Cansancio.umbral_cambio(equipo.config_cambios),
		"suben_corner": Estilos.suben_al_corner(equipo.estilo),
		"cuelga_lejos": Estilos.cuelga_de_lejos(equipo.estilo),
	}


## Lo de un jugador que leen las reglas (etapa 6): su id, lo que multiplica
## las tarjetas (MatchEngine._chequear_tarjeta), el riesgo de lesión
## descansado (MatchEngine._chequear_lesion), el desgaste por minuto
## (Team.desgastar_minutos), la energía con que arranca y los atributos que
## usan las pelotas paradas. El C++ solo sortea.
static func reglas_de(jugador: Dictionary, equipo: Team, rival: Team) -> Dictionary:
	var a: Dictionary = jugador["atributos"]
	var arbitro := Arbitro.factor_tarjetas(equipo.arbitro_partido)
	var clasico := Rivalidad.factor_tarjetas(Rivalidad.es_clasico(equipo, rival))
	var amenaza := float(a.get("cabezazo", 50.0)) + float(a.get("salto", 50.0))
	if MotorEspacial.ROLES_QUE_ATACAN.has(str(jugador["posicion"])):
		amenaza += 40.0
	return {
		"id": int(jugador["id"]),
		"factor_amarilla": arbitro * clasico * Personalidad.factor_amarilla(jugador),
		"factor_roja": arbitro * clasico * Personalidad.factor_roja(jugador),
		"riesgo_lesion": Lesiones.evaluar_riesgo(jugador, 1.0, Instalaciones.factor_riesgo_lesion(equipo),
			CargaEntrenamiento.factor_lesion(equipo.carga_entrenamiento)),
		"desgaste_minuto": Cansancio.desgaste_por_minuto(str(jugador["posicion"]))
			* Cansancio.factor_atributo_energia(float(a.get("energia", 50.0)))
			* Clima.factor_energia(equipo.clima_partido) * Entrenamiento.factor_desgaste(equipo),
		"energia": equipo.resistencia_pct(int(jugador["id"])),
		"quite": float(a.get("quite", 50.0)),
		"barrida": float(a.get("barrida", 50.0)),
		"tiros_libres": float(a.get("tiros_libres", 50.0)),
		"centros": float(a.get("centros", 50.0)),
		"fuerza": float(a.get("fuerza", 50.0)),
		"salto": float(a.get("salto", 50.0)),
		"amenaza": amenaza,
		"media": float(jugador.get("media", 50.0)),
	}
