class_name Copa
extends RefCounted

## Motor genérico de eliminación directa a partido único — Fase 7 (GDD §10:
## "copa interna de división + copa nacional entre todas las divisiones,
## partido único"). Sirve para cualquier cantidad de equipos: si no es
## potencia de 2, la cantidad sobrante juega una ronda previa y el resto
## pasa con bye, para que de ahí en adelante el cuadro quede parejo.
##
## Empates: si 90' terminan igualados se juega el alargue (2x15',
## MatchEngine.simular_alargue) y si sigue empatado se define por penales
## (Penales.definir) — partido único a eliminación directa real (§8.7).

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
		var gl: int = r["goles_local"]
		var gv: int = r["goles_visitante"]
		var definicion := "90 minutos"
		var ganador: Team
		var penales_texto := ""

		if gl != gv:
			ganador = home if gl > gv else away
		else:
			var r_alargue := MatchEngine.simular_alargue(home, away, rng, false)
			gl = r_alargue["goles_local"]
			gv = r_alargue["goles_visitante"]
			definicion = "alargue"
			if gl != gv:
				ganador = home if gl > gv else away
			else:
				var pen := Penales.definir(home, away, rng)
				definicion = "penales"
				ganador = pen["ganador"]
				penales_texto = " (%d-%d penales)" % [pen["goles_local"], pen["goles_visitante"]]

		resultados.append({
			"local": home.nombre, "visitante": away.nombre,
			"gl": gl, "gv": gv, "ganador": ganador.nombre,
			"definicion": definicion, "penales_texto": penales_texto,
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


## §10.5/§15 (Objetivos de directiva, ver core/objetivos.gd): cuántas
## rondas ganó este equipo en total en esta copa — 0 si perdió su primer
## partido, historial.size() si salió campeón. Un bye (ronda en la que no
## aparece en ningún partido porque le tocó pasar directo) no suma ni
## resta, simplemente no cuenta esa ronda.
func rondas_ganadas(equipo: Team) -> int:
	var rondas := 0
	for ronda in historial:
		for partido in ronda:
			if partido["local"] == equipo.nombre or partido["visitante"] == equipo.nombre:
				if partido["ganador"] == equipo.nombre:
					rondas += 1
				break
	return rondas


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


## Guardado. `historial` ya usa NOMBRES (se arma así en
## jugar_siguiente_ronda), así que lo único que hay que traducir son las
## tres cosas que sí guardan referencias a Team: el bye, los partidos
## pendientes y el campeón. Los equipos se relocalizan al cargar buscando
## por nombre en la pirámide, igual que hace Confederacion.
func guardar() -> Dictionary:
	var pares := []
	for p in partidos_pendientes:
		pares.append([p[0].nombre, p[1].nombre])
	var bye := []
	for e in equipos_con_bye:
		bye.append(e.nombre)
	return {
		"nombre": nombre,
		"equipos_con_bye": bye,
		"partidos_pendientes": pares,
		"historial": historial,
		"campeon": campeon.nombre if campeon != null else "",
	}


static func cargar(datos: Dictionary, piramide) -> Copa:
	var indice := {}
	for liga in piramide.divisiones:
		for e in liga.equipos:
			indice[e.nombre] = e

	var c := Copa.new()
	c.nombre = str(datos.get("nombre", "Copa"))
	c.historial = datos.get("historial", [])
	for n in datos.get("equipos_con_bye", []):
		if indice.has(str(n)):
			c.equipos_con_bye.append(indice[str(n)])
	for p in datos.get("partidos_pendientes", []):
		# Si un equipo del cuadro ya no existe (no debería pasar dentro de
		# una temporada), se descarta el cruce entero en vez de dejar un
		# partido a medias que reventaría al jugarlo.
		if indice.has(str(p[0])) and indice.has(str(p[1])):
			c.partidos_pendientes.append([indice[str(p[0])], indice[str(p[1])]])
	var campeon_nombre := str(datos.get("campeon", ""))
	if campeon_nombre != "" and indice.has(campeon_nombre):
		c.campeon = indice[campeon_nombre]
	return c
