class_name Copa
extends RefCounted

## Motor genérico de eliminación directa a partido único — Fase 7 (GDD §10:
## "copa interna de división + copa nacional entre todas las divisiones,
## partido único"). Sirve para cualquier cantidad de equipos: si no es
## potencia de 2, la cantidad sobrante juega una ronda previa y el resto
## pasa con bye, para que de ahí en adelante el cuadro quede parejo.
##
## Empates: el motor de alargue/penales (§8.7) todavía no existe, así que
## en caso de empate gana el local — simplificación temporal, documentada,
## no la regla final (que sería alargue + penales).

var nombre: String
var equipos_con_bye: Array = []  # Team, esperando a la ronda donde ya no hace falta bye
var partidos_pendientes: Array = []  # [[Team, Team], ...] listos para jugar_siguiente_ronda()
var historial: Array = []  # por ronda jugada: Array de {local, visitante, gl, gv, ganador}
var campeon: Team = null


static func iniciar(nombre: String, equipos: Array, rng: RandomNumberGenerator) -> Copa:
	var c := Copa.new()
	c.nombre = nombre
	var n := equipos.size()
	var mezclados := _mezclar(equipos, rng)

	if n <= 1:
		c.campeon = mezclados[0] if n == 1 else null
		return c

	var potencia := 1
	while potencia * 2 <= n:
		potencia *= 2

	if potencia == n:
		c.partidos_pendientes = _armar_pares(mezclados)
	else:
		var con_bye: int = 2 * potencia - n
		c.equipos_con_bye = mezclados.slice(0, con_bye)
		c.partidos_pendientes = _armar_pares(mezclados.slice(con_bye, n))

	return c


func jugar_siguiente_ronda(rng: RandomNumberGenerator) -> Array:
	if campeon != null or partidos_pendientes.is_empty():
		return []

	var resultados := []
	var ganadores := []
	for partido in partidos_pendientes:
		var home: Team = partido[0]
		var away: Team = partido[1]
		var r := MatchEngine.simular(home, away, rng, false)
		var ganador: Team = home if r["goles_local"] >= r["goles_visitante"] else away
		resultados.append({
			"local": home.nombre, "visitante": away.nombre,
			"gl": r["goles_local"], "gv": r["goles_visitante"], "ganador": ganador.nombre,
		})
		ganadores.append(ganador)
	historial.append(resultados)

	var siguiente_pool: Array = ganadores + equipos_con_bye
	equipos_con_bye = []

	if siguiente_pool.size() == 1:
		campeon = siguiente_pool[0]
		partidos_pendientes = []
	else:
		partidos_pendientes = _armar_pares(_mezclar(siguiente_pool, rng))

	return resultados


static func _armar_pares(equipos: Array) -> Array:
	var pares := []
	for i in range(0, equipos.size(), 2):
		pares.append([equipos[i], equipos[i + 1]])
	return pares


static func _mezclar(equipos: Array, rng: RandomNumberGenerator) -> Array:
	var copia := equipos.duplicate()
	for i in range(copia.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = copia[i]
		copia[i] = copia[j]
		copia[j] = tmp
	return copia
