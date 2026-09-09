extends SceneTree

## Medicion (no es test): como rota el pool de agentes libres ahora que
## los clubes de la IA lo miran todos los dias y sueltan suplentes
## amargados (AgentesLibres.ronda_diaria).
##
## Corre sobre la piramide de la partida guardada del usuario, que es el
## caso que motivo el cambio: 440 libres parados, 8 de ellos con media 90
## o mas. SOLO LEE el archivo, nunca escribe.
##
## Mide el ciclo ANUAL completo: los dias del año con la rueda diaria
## andando, y despues el cierre de temporada, que es cuando entra el
## volcado grande de vencimientos. Sin el cierre, la medicion solo ve el
## drenaje y parece que el pool se vacia.
##
## Correr con: godot --headless --script tests/_diag_rotacion_libres.gd

const SEED := 909
const TEMPORADAS := 3
const DIAS_POR_TEMPORADA := 300
## Con cuanta media un libre ya te sirve de refuerzo en media tabla.
const MEDIA_DE_GANGA := 70.0
const PARTIDA := "C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/Super Pocket Stars/partida.json"


func _init() -> void:
	var archivo := FileAccess.open(PARTIDA, FileAccess.READ)
	if archivo == null:
		print("No pude leer la partida: %s" % PARTIDA)
		quit()
		return
	var datos: Dictionary = JSON.parse_string(archivo.get_as_text())
	archivo.close()

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.cargar(datos["piramide"])
	var pool: Array = piramide.agentes_libres

	print("Pool al cargar: %d" % pool.size())
	print("\ntemp  dia  pool  media  edad  m>=70  m>=85  mejor  fichan/dia")
	for t in range(TEMPORADAS):
		var fichados := 0
		var dias_con_ganga := 0
		for dia in range(DIAS_POR_TEMPORADA):
			fichados += AgentesLibres.ronda_diaria(piramide, rng, 1, null).size()
			if _mejor(pool) >= MEDIA_DE_GANGA:
				dias_con_ganga += 1
			if dia % 60 == 59:
				_linea(t + 1, dia + 1, pool, float(fichados) / float(dia + 1))
		print("  -> temporada %d: %d fichajes, %d de %d dias con alguien de media %d o mas" % [
			t + 1, fichados, dias_con_ganga, DIAS_POR_TEMPORADA, int(MEDIA_DE_GANGA)])
		piramide.jugar_temporada(rng)
		for liga in piramide.divisiones:
			liga.noticias.clear()
		piramide.fin_de_temporada(rng, null, t)
		_linea(t + 1, -1, pool, 0.0)

	print("\n--- Los 10 mejores que quedan ---")
	var copia := pool.duplicate()
	copia.sort_custom(func(a, b): return float(a["media"]) > float(b["media"]))
	for i in range(mini(10, copia.size())):
		var a: Dictionary = copia[i]
		print("  media %5.1f  %3s  %2d años  potencial %3d" % [
			float(a["media"]), str(a["posicion"]), int(a["edad"]), int(a["potencial"])])
	quit()


func _mejor(pool: Array) -> float:
	var mejor := 0.0
	for a in pool:
		mejor = maxf(mejor, float(a["media"]))
	return mejor


## dia -1 = foto justo despues del cierre de temporada.
func _linea(temporada: int, dia: int, pool: Array, por_dia: float) -> void:
	var media := 0.0
	var edad := 0.0
	var c70 := 0
	var c85 := 0
	for a in pool:
		var m := float(a["media"])
		media += m
		edad += float(a["edad"])
		if m >= 70.0:
			c70 += 1
		if m >= 85.0:
			c85 += 1
	var n: float = maxf(float(pool.size()), 1.0)
	print("%4d %4s  %4d  %5.1f  %4.1f  %5d  %5d  %5.1f  %10.1f" % [
		temporada, "CIER" if dia < 0 else str(dia), pool.size(),
		media / n, edad / n, c70, c85, _mejor(pool), por_dia])
