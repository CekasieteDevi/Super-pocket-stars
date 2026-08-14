class_name EstadoCancha
extends RefCounted

## Estado de la cancha (§8.4 #21 + §8.6.2, simplificado) — identidad fija
## de cada club, horneada al generarlo como estilo/DT, pero acá se guarda
## directo como el número que pide §8.4 ("de −8 a +3") en vez de las
## etiquetas categóricas de §8.6.2 (buena/mala/chica/con altura): son
## flavor text sobre el mismo número, no cambian el mecanismo. Se
## correlaciona con la reputación (los clubes grandes tienen mejor
## infraestructura) más ruido, para que no sea 100% previsible por
## división.
const MINIMO := -8.0
const MAXIMO := 3.0


static func generar(reputacion: float, rng: RandomNumberGenerator) -> float:
	var base: float = lerp(MINIMO, MAXIMO, clamp(reputacion, 0.0, 100.0) / 100.0)
	return clamp(base + rng.randf_range(-2.0, 2.0), MINIMO, MAXIMO)


## Bloque C ambiental (mismo mecanismo que Clima, ver core/clima.gd): la
## cancha del LOCAL es la que rige para el partido entero, y castiga o
## favorece las acciones técnicas de CUALQUIERA de los dos equipos por
## igual — una cancha mala complica también al que juega de local ahí.
static func modificador(calidad_cancha_local: float, atributo: String) -> float:
	if atributo == "pases" or atributo == "control":
		return calidad_cancha_local
	return 0.0
