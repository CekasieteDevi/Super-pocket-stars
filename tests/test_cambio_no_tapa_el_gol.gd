extends SceneTree

## Un cambio no le puede robar la pantalla al gol.
##
## El fotograma trae `foco`: mientras alguien entra o sale, la camara lo
## sigue A EL y suelta la pelota. Si la sustitucion arranca en el mismo
## tick del gol, la camara se va al suplente justo en el fotograma que la
## vista congela para el festejo, y el usuario ve la sustitucion antes que
## el gol. La guarda esta en MotorEspacial._sincronizar_cambios.

const SEED := 20260908
const PARTIDOS := 30

var fallos := 0


func _init() -> void:
	var goles := 0
	var cambios := 0
	var goles_con_foco := 0
	var saques_con_foco := 0
	for n in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var local := Team.generar("Atletico Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var r := MotorEspacial.simular(local, visita, rng, true)
		cambios += local.cambios_realizados + visita.cambios_realizados
		var fs: Array = r["fotogramas"]
		for i in range(fs.size()):
			var con_foco: bool = fs[i].get("foco", null) != null
			for ev in fs[i].get("eventos", []):
				var tipo := str(ev.get("tipo", ""))
				if str(ev.get("resultado", "")) == "gol" and tipo in ["tiro_puerta", "penal"]:
					goles += 1
					if con_foco:
						goles_con_foco += 1
				# El cambio del entretiempo se aplica sin caminata: los
				# equipos vuelven a la cancha ya cambiados. Si quedara
				# alguien trotando, el saque del medio arrancaria con la
				# camara puesta en el lateral.
				if tipo == "saque_inicial" and con_foco:
					saques_con_foco += 1

	_probar_la_guarda()

	_afirmar(goles > 0, "hay goles para mirar (%d)" % goles)
	_afirmar(cambios > 0, "se siguen haciendo cambios (%d)" % cambios)
	_afirmar(goles_con_foco == 0,
		"ningun gol cae con la camara puesta en un cambio (%d de %d)" % [goles_con_foco, goles])
	_afirmar(saques_con_foco == 0,
		"ningun saque del medio arranca con alguien entrando (%d)" % saques_con_foco)

	print("FALLOS=%d" % fallos)
	quit()


## El contrato de la guarda, probado directo sobre el estado: un cambio
## solo arranca con el juego cortado de antes y la pelota quieta. Se
## prueba aca y no contando fotogramas porque el caso malo aparece pocas
## veces por partido y un conteo no distingue "no pasa" de "no salio".
func _probar_la_guarda() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var local := Team.generar("Atletico Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	local.reset_partido()
	visita.reset_partido()
	local.local = true
	visita.local = false
	var estado := MotorEspacial.crear_estado(local, visita, rng)

	# Un cambio de verdad: sale un titular de campo, entra el primero del
	# banco que no sea arquero.
	var sale := -1
	for j in local.jugadores_en_cancha():
		if str(j["posicion"]) != "ARQ":
			sale = int(j["id"])
			break
	var entra := -1
	for j in local.todos_los_jugadores():
		if not local.en_cancha.has(int(j["id"])) and str(j["posicion"]) != "ARQ":
			entra = int(j["id"])
			break
	_afirmar(sale != -1 and entra != -1, "hay un titular y un suplente para el cambio")
	local.sustituir(sale, entra)

	# 1. Juego vivo: el cambio espera.
	estado["detenido"] = 0
	estado["detenido_previo"] = 0
	MotorEspacial._sincronizar_cambios(estado)
	_afirmar(estado["saliendo"].is_empty() and estado["entrando"].is_empty(),
		"con el juego vivo el cambio no arranca")

	# 2. Juego recien cortado (el tick del gol): tampoco, o la camara se
	# iria al suplente en el fotograma del festejo.
	estado["detenido"] = 10
	estado["detenido_previo"] = 0
	MotorEspacial._sincronizar_cambios(estado)
	_afirmar(estado["saliendo"].is_empty() and estado["entrando"].is_empty(),
		"en el tick del corte el cambio no arranca")

	# 3. Juego cortado pero la pelota viajando —el remate que va a la red,
	# el rebote que sale al corner—: tampoco.
	estado["detenido_previo"] = 10
	estado["pelota"]["en_vuelo"] = true
	MotorEspacial._sincronizar_cambios(estado)
	_afirmar(estado["saliendo"].is_empty() and estado["entrando"].is_empty(),
		"con la pelota en el aire el cambio no arranca")

	# 4. Cortado de antes y pelota quieta: recien ahora entra.
	estado["pelota"]["en_vuelo"] = false
	MotorEspacial._sincronizar_cambios(estado)
	_afirmar(not estado["saliendo"].is_empty() and not estado["entrando"].is_empty(),
		"con la pelota parada el cambio arranca")


func _afirmar(condicion: bool, que: String) -> void:
	if condicion:
		print("OK: %s" % que)
	else:
		fallos += 1
		print("FALLA: %s" % que)
