extends SceneTree

## Medicion, no test: cuantos titulares de la IA ocupan un slot de la
## formacion que no es su puesto, temporada a temporada.
##
## En una partida de temporada 14, 199 de los 200 clubes de la piramide
## tenian el once desordenado y en 145 atajaba un jugador de campo.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_once_fuera_de_puesto.gd

const SEED := 7310
const TEMPORADAS := 2


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	_medir(piramide, 0)
	var fichajes := 0
	for t in range(1, TEMPORADAS + 1):
		# Como GameState: una fecha por semana y el mercado de libres
		# todos los dias.
		var fechas := 0
		for liga in piramide.divisiones:
			fechas = maxi(fechas, liga.fixture.size())
		for idx in range(fechas):
			for liga in piramide.divisiones:
				if idx < liga.fixture.size():
					liga.jugar_fecha(idx, rng)
			fichajes += AgentesLibres.ronda_diaria(piramide, rng, 7).size()
		_medir(piramide, -t)
		piramide.fin_de_temporada(rng, null, t)
		_medir(piramide, t)
		print("  fichajes de libres acumulados: %d, pool: %d" % [fichajes, piramide.agentes_libres.size()])
	quit()


static func _medir(piramide: Piramide, temporada: int) -> void:
	var clubes := 0
	var desordenados := 0
	var fuera := 0
	var sin_arquero := 0
	var evitables := 0
	var faltan := 0
	var lesionados := 0
	for liga in piramide.divisiones:
		for e in liga.equipos:
			clubes += 1
			var roles: Array = Formaciones.roles_compartidos(e.formacion)
			var mal := 0
			for i in range(mini(roles.size(), e.jugadores.size())):
				if str(e.jugadores[i]["posicion"]) != str(roles[i]):
					mal += 1
			fuera += mal
			if mal > 0:
				desordenados += 1
			if e.jugadores.is_empty() or str(e.jugadores[0]["posicion"]) != "ARQ":
				sin_arquero += 1
			evitables += _evitables(e, roles)
			faltan += _faltan(e, roles)
			for j in e.jugadores:
				if not e.puede_jugar(int(j["id"])):
					lesionados += 1
	print("temporada %d: clubes %d, desordenados %d, titulares fuera de puesto %d (evitables %d), faltan en el plantel %d, titulares que no pueden jugar %d, arco sin arquero %d" % [
		temporada, clubes, desordenados, fuera, evitables, faltan, lesionados, sin_arquero])


## Los slots que el plantel entero (once, banco y reservas) no puede
## cubrir con alguien del puesto, aunque esten todos sanos.
static func _faltan(e: Team, roles: Array) -> int:
	var pedidos := {}
	for r in roles:
		pedidos[str(r)] = int(pedidos.get(str(r), 0)) + 1
	var hay := {}
	for j in e.jugadores + e.banco + e.reservas:
		hay[str(j["posicion"])] = int(hay.get(str(j["posicion"]), 0)) + 1
	var n := 0
	for r in pedidos:
		n += maxi(0, int(pedidos[r]) - int(hay.get(r, 0)))
	return n


## Los slots mal cubiertos teniendo un jugador sano de ese puesto entre
## titulares y banco. El resto es falta de gente: lesionados o un plantel
## sin ese puesto.
static func _evitables(e: Team, roles: Array) -> int:
	var pedidos := {}
	var bien := {}
	var sanos := {}
	for i in range(roles.size()):
		var r := str(roles[i])
		pedidos[r] = int(pedidos.get(r, 0)) + 1
		if i < e.jugadores.size() and str(e.jugadores[i]["posicion"]) == r 				and e.puede_jugar(int(e.jugadores[i]["id"])):
			bien[r] = int(bien.get(r, 0)) + 1
	for j in e.jugadores + e.banco:
		if e.puede_jugar(int(j["id"])):
			var p := str(j["posicion"])
			sanos[p] = int(sanos.get(p, 0)) + 1
	var n := 0
	for r in pedidos:
		n += maxi(0, mini(int(pedidos[r]), int(sanos.get(r, 0))) - int(bien.get(r, 0)))
	return n
