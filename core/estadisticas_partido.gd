class_name EstadisticasPartido
extends RefCounted

## Resumen de estadísticas post-partido (posesión, tiros, pases) calculado
## a partir de "eventos" (el mismo Array que ya devuelve MatchEngine.simular()
## y que alimenta PartidoVisual) — sin tocar el motor de partido en sí.
##
## Sirve para que efectos como el choque de estilos (§8.6.3) o el rasgo del
## DT (§8.6.4) se puedan VER: hoy cambian el % de éxito de cada duelo, pero
## eso queda invisible si lo único que se muestra es el marcador. "Posesión"
## se aproxima como la proporción de acciones de ataque (pase/gambeta/tiro)
## que intentó cada equipo — no hay tracking real de quién tiene la pelota
## en cada tick, es la mejor aproximación con los datos que ya existen.
const TIPOS_ACCION_OFENSIVA := ["pase", "gambeta", "tiro", "tiro_puerta", "rebote"]
const TIPOS_TIRO := ["tiro", "tiro_puerta", "rebote"]


static func _fila_vacia() -> Dictionary:
	return {
		"acciones": 0, "posesion_pct": 0.0,
		"pases_intentados": 0, "pases_completados": 0,
		"tiros": 0, "tiros_al_arco": 0,
	}


## Devuelve {equipo_local: {...}, equipo_visitante: {...}} con las claves
## de _fila_vacia(). Eventos con "equipo" fuera de {local, visitante}
## (no debería pasar) se ignoran en vez de romper.
static func calcular(eventos: Array, equipo_local: String, equipo_visitante: String) -> Dictionary:
	var stats := {equipo_local: _fila_vacia(), equipo_visitante: _fila_vacia()}

	for evento in eventos:
		var nombre: String = evento.get("equipo", "")
		if not stats.has(nombre):
			continue
		var tipo: String = evento["tipo"]

		if TIPOS_ACCION_OFENSIVA.has(tipo):
			stats[nombre]["acciones"] += 1
		if tipo == "pase":
			stats[nombre]["pases_intentados"] += 1
			if evento["resultado"] == "avanza":
				stats[nombre]["pases_completados"] += 1
		if TIPOS_TIRO.has(tipo):
			stats[nombre]["tiros"] += 1
			if tipo != "tiro":  # "tiro" = se fue afuera/al palo sin llegar al arquero
				stats[nombre]["tiros_al_arco"] += 1

	var total_acciones: int = stats[equipo_local]["acciones"] + stats[equipo_visitante]["acciones"]
	if total_acciones > 0:
		stats[equipo_local]["posesion_pct"] = 100.0 * stats[equipo_local]["acciones"] / total_acciones
		stats[equipo_visitante]["posesion_pct"] = 100.0 * stats[equipo_visitante]["acciones"] / total_acciones
	else:
		stats[equipo_local]["posesion_pct"] = 50.0
		stats[equipo_visitante]["posesion_pct"] = 50.0

	return stats
