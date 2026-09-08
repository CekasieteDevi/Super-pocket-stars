extends SceneTree

## Cuando a un jugador se le vence el contrato, el puesto que deja vacante
## lo tapa la CANTERA del club y no un fichaje generado a precio de
## mercado. Correr con:
## godot --headless --script tests/test_reemplazo_desde_cantera.gd

const SEED := 4242

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_sube_un_canterano(rng)
	_test_prefiere_el_mismo_puesto(rng)
	_test_sin_cantera_no_inventa_jugadores(rng)
	_test_sin_banco_el_once_se_achica_por_el_final(rng)
	_test_la_ia_no_usa_cantera(rng)
	_test_cuesta_menos_que_generar(rng)
	_test_el_aviso_queda_anotado(rng)

	print("FALLOS=%d" % fallos)
	quit()


func _falla(texto: String) -> void:
	fallos += 1
	print("FALLA: %s" % texto)


func _test_sube_un_canterano(rng: RandomNumberGenerator) -> void:
	var equipo := Team.generar("ClubA", rng, 0)
	# La cantera de un club recien generado esta vacia: los juveniles
	# aparecen con generar_camada, una camada por temporada.
	equipo.generar_camada(rng, 5)
	var pool := []
	var saliente: Dictionary = equipo.jugadores[3]
	var ids_cantera := []
	for j in equipo.cantera:
		ids_cantera.append(int(j["id"]))
	var cantera_antes: int = equipo.cantera.size()

	var salida := AgentesLibres.liberar(equipo, saliente, pool, rng, true)

	if not bool(salida.get("de_cantera", false)):
		_falla("con cantera disponible no subio un juvenil.")
		return
	var entra: int = int(salida["jugador"]["id"])
	if not ids_cantera.has(entra):
		_falla("el que entro no salio de la cantera.")
		return
	if equipo.cantera.size() != cantera_antes - 1:
		_falla("la cantera no perdio al que subio.")
		return
	if int(equipo.jugadores[3]["id"]) != entra:
		_falla("el juvenil no ocupo el puesto vacante.")
		return
	if int(equipo.contratos.get(entra, 0)) != AgentesLibres.ANIOS_CANTERANO:
		_falla("el canterano no firmo por %d años." % AgentesLibres.ANIOS_CANTERANO)
		return
	print("OK: al vencerse un contrato sube un juvenil de la cantera al puesto.")


func _test_prefiere_el_mismo_puesto(rng: RandomNumberGenerator) -> void:
	var equipo := Team.generar("ClubB", rng, 100)
	equipo.generar_camada(rng, 5)
	var pool := []
	var saliente: Dictionary = equipo.jugadores[5]
	var posicion: String = saliente["posicion"]

	# Se arma el caso dificil a mano: el UNICO juvenil del puesto es el
	# PEOR de la camada. Si sube ese, el puesto pesa mas que la media.
	for j in equipo.cantera:
		j["posicion"] = "ARQ" if posicion != "ARQ" else "DC"
		j["media"] = 60
	var unico: Dictionary = equipo.cantera[2]
	unico["posicion"] = posicion
	unico["media"] = 20

	var salida := AgentesLibres.liberar(equipo, saliente, pool, rng, true)
	var entra: Dictionary = salida["jugador"]

	if int(entra["id"]) != int(unico["id"]):
		_falla("habia un juvenil del puesto y subio otro.")
		return
	print("OK: con un juvenil del mismo puesto disponible, sube ese aunque no sea el de mejor media.")


## Sin cantera NO se inventa un jugador. El puesto del once lo tapa el
## banco y el plantel queda mas corto: la decision de con quien llenarlo es
## del jugador, no del juego.
func _test_sin_cantera_no_inventa_jugadores(rng: RandomNumberGenerator) -> void:
	var equipo := Team.generar("ClubC", rng, 200)
	equipo.cantera.clear()
	var pool := []
	var saliente: Dictionary = equipo.jugadores[2]
	var titulares_antes: int = equipo.jugadores.size()
	var banco_antes: int = equipo.banco.size()
	var ids_antes := {}
	for j in equipo.todos_los_jugadores():
		ids_antes[int(j["id"])] = true

	var salida := AgentesLibres.liberar(equipo, saliente, pool, rng, true)

	if not bool(salida.get("hueco", false)):
		_falla("sin cantera no dijo que quedaba un hueco.")
		return
	if not salida.get("jugador", {}).is_empty():
		_falla("sin cantera entro un jugador igual: %s" % [salida["jugador"]])
		return
	for j in equipo.todos_los_jugadores():
		if not ids_antes.has(int(j["id"])):
			_falla("aparecio un jugador que no estaba en el plantel.")
			return
	if equipo.jugadores.size() != titulares_antes:
		_falla("el once quedo con %d: el hueco tenia que bajar al banco." % equipo.jugadores.size())
		return
	if equipo.banco.size() != banco_antes - 1:
		_falla("el banco no se achico: %d contra %d." % [equipo.banco.size(), banco_antes])
		return
	print("OK: sin cantera no se inventa nadie — sube uno del banco y el plantel queda mas corto.")


## El caso extremo: sin cantera Y sin banco, el once se achica. Se recorta
## por el final para que nadie mas cambie de slot (el slot i lo ocupa
## jugadores[i], ver MotorEspacial).
func _test_sin_banco_el_once_se_achica_por_el_final(rng: RandomNumberGenerator) -> void:
	var equipo := Team.generar("ClubF", rng, 700)
	equipo.cantera.clear()
	equipo.banco.clear()
	var idx := 3
	var saliente: Dictionary = equipo.jugadores[idx]
	var ultimo_antes: int = int(equipo.jugadores[equipo.jugadores.size() - 1]["id"])
	var intactos := []
	for i in range(equipo.jugadores.size() - 1):
		if i != idx:
			intactos.append([i, int(equipo.jugadores[i]["id"])])
	var titulares_antes: int = equipo.jugadores.size()

	AgentesLibres.liberar(equipo, saliente, [], rng, true)

	if equipo.jugadores.size() != titulares_antes - 1:
		_falla("el once no se achico: %d titulares." % equipo.jugadores.size())
		return
	if int(equipo.jugadores[idx]["id"]) != ultimo_antes:
		_falla("el slot vacante no lo tapo el ultimo titular.")
		return
	for par in intactos:
		if int(equipo.jugadores[int(par[0])]["id"]) != int(par[1]):
			_falla("se le corrio el slot a un titular que no tenia que moverse.")
			return
	print("OK: sin banco el once sale con diez y nadie mas cambia de slot.")


func _test_la_ia_no_usa_cantera(rng: RandomNumberGenerator) -> void:
	var equipo := Team.generar("ClubD", rng, 300)
	equipo.generar_camada(rng, 5)
	var pool := []
	var cantera_antes: int = equipo.cantera.size()

	var salida := AgentesLibres.liberar(equipo, equipo.jugadores[1], pool, rng)

	if bool(salida.get("de_cantera", true)):
		_falla("un club de la IA tiro de su cantera.")
		return
	if equipo.cantera.size() != cantera_antes:
		_falla("un club de la IA perdio un juvenil.")
		return
	print("OK: los clubes de la IA siguen generando el reemplazo, no tocan su cantera.")


## El numero que importa: cuanto le cuesta al presupuesto de Contratos que
## se te venza un contrato. El fichaje generado cobra sueldo de mercado; el
## canterano cobra lo que vale un pibe.
func _test_cuesta_menos_que_generar(rng: RandomNumberGenerator) -> void:
	var costo_cantera := 0.0
	var costo_generado := 0.0
	var casos := 0

	for semilla in range(20):
		var rng_a := RandomNumberGenerator.new()
		rng_a.seed = SEED + semilla
		var con_cantera := Team.generar("ClubE", rng_a, 400 + semilla * 100)
		con_cantera.generar_camada(rng_a, 5)
		con_cantera.caja["contratos"] = 100000.0
		var antes_a: float = con_cantera.caja["contratos"]
		var salida := AgentesLibres.liberar(
			con_cantera, con_cantera.jugadores[4], [], rng_a, true)
		if not bool(salida.get("de_cantera", false)):
			continue

		var rng_b := RandomNumberGenerator.new()
		rng_b.seed = SEED + semilla
		var sin_cantera := Team.generar("ClubE", rng_b, 400 + semilla * 100)
		sin_cantera.generar_camada(rng_b, 5)
		sin_cantera.caja["contratos"] = 100000.0
		sin_cantera.cantera.clear()
		var antes_b: float = sin_cantera.caja["contratos"]
		# desde_cantera = false: es lo que sigue haciendo la IA, y es el
		# numero contra el que se compara subir un juvenil.
		AgentesLibres.liberar(sin_cantera, sin_cantera.jugadores[4], [], rng_b, false)

		costo_cantera += antes_a - con_cantera.caja["contratos"]
		costo_generado += antes_b - sin_cantera.caja["contratos"]
		casos += 1

	if casos == 0:
		_falla("ningun caso subio un canterano: no se pudo medir.")
		return

	print("MEDIDO (%d casos): tapar el puesto con la cantera cuesta $%.0f de Contratos; generando el reemplazo, $%.0f." % [
		casos, costo_cantera / casos, costo_generado / casos])

	if costo_cantera >= costo_generado:
		_falla("subir un canterano no salio mas barato que generar el reemplazo.")
		return
	print("OK: tapar el puesto con la cantera le cuesta menos al presupuesto de Contratos.")


## El plantel del jugador cambio sin que el decidiera nada, asi que el
## cierre tiene que dejar anotado quien se fue y quien lo tapa. La UI lo
## lee al empezar la temporada y lo borra recien cuando el jugador acepta,
## asi que el aviso tiene que sobrevivir a guardar y cargar.
func _test_el_aviso_queda_anotado(rng: RandomNumberGenerator) -> void:
	var liga := Liga.new()
	liga.inicializar(["Protegido", "Rival"], rng, 0)
	var protegido: Team = liga.equipos[0]
	protegido.generar_camada(rng, 5)
	for id in protegido.contratos.keys():
		protegido.contratos[id] = 1

	liga._avanzar_contratos(protegido, rng, true)

	if protegido.vencimientos_del_cierre.is_empty():
		_falla("el cierre no anoto ningun vencimiento.")
		return

	var primero: Dictionary = protegido.vencimientos_del_cierre[0]
	for clave in ["sale", "sale_puesto", "sale_sueldo", "entra", "entra_puesto",
			"entra_sueldo", "entra_anios", "de_cantera"]:
		if not primero.has(clave):
			_falla("al aviso le falta el dato '%s'." % clave)
			return
	if str(primero["sale"]).is_empty() or str(primero["entra"]).is_empty():
		_falla("el aviso no dice quien se fue o quien entro.")
		return
	if float(primero["sale_sueldo"]) <= 0.0:
		_falla("el aviso perdio el sueldo del que se fue: se leyo despues de darlo de baja.")
		return

	var copia := Team.cargar(protegido.guardar())
	if copia.vencimientos_del_cierre.size() != protegido.vencimientos_del_cierre.size():
		_falla("el aviso no sobrevive a guardar y cargar la partida.")
		return

	print("OK: el cierre anota quien se fue y quien lo tapa, y el aviso sobrevive al guardado (%d lineas)." % protegido.vencimientos_del_cierre.size())
