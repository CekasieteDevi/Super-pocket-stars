extends SceneTree

## BUG-012 (docs/bugs_pendientes.md): el partido del Motor V2 tiene regates.
##
## - Cerebro: el poseedor puede encarar al rival que tiene delante
##   (DEC_REGATE, con los pesos `gambeta` de data/utility_pesos.json).
## - Canchita: el toque sale con el clip del regate y hacia el costado del
##   rival. El rival se come el amague o no (Canchita::_amagar); nadie
##   adjudica la pelota.
## - Relato: el regate que sirve deja un evento con su nombre.
##
## Correr con: godot --path . --headless --script tests/test_regate_v2.gd

const SEED := 97000
const PARTIDOS := 6
const DIVISION := 4
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
const PASOS_TOPE := 60 * 60 * 20
## Gestos de regate por partido. En 60 partidos de quinta, semilla 97000:
## 7,2. Antes del arreglo, 0.
const PISO_GESTOS := 4.0
## De los gestos, los que el rival se come: 51% en esos 60 partidos. Con
## control y quite parejos la base es 50% (toque.regate_pica_base).
const AMAGUE_MIN := 0.3
const AMAGUE_MAX := 0.75
## De los gestos, los que terminan con la pelota en su equipo: 45%.
const PISO_GANADOS := 0.25
## El partido del laboratorio (motor_v2/laboratorio_partido.gd).
const SEED_RELATO := 20261201

var fallos := 0


func _init() -> void:
	var k := _jugar(PARTIDOS)
	var gestos: float = k["regates"]
	_ok(gestos / PARTIDOS >= PISO_GESTOS, "hay regates: %.1f gestos por partido (al menos %.1f)" % [gestos / PARTIDOS, PISO_GESTOS])
	var amague: float = k["regates_amague"] / maxf(gestos, 1.0)
	_ok(amague >= AMAGUE_MIN and amague <= AMAGUE_MAX,
		"el rival se come el amague el %.0f%% de las veces (entre %.0f%% y %.0f%%)" % [100.0 * amague, 100.0 * AMAGUE_MIN, 100.0 * AMAGUE_MAX])
	var ganados: float = k["regates_ganados"] / maxf(gestos, 1.0)
	_ok(ganados >= PISO_GANADOS, "el %.0f%% de los regates deja la pelota en su equipo (al menos %.0f%%)" % [100.0 * ganados, 100.0 * PISO_GANADOS])
	_ok(k["evento_0"] > 0.0 and k["evento_1"] > 0.0,
		"salen los dos regates: elástica %d, croqueta %d" % [int(k["evento_0"]), int(k["evento_1"])])
	_ok(k["evento_0"] + k["evento_1"] == k["regates_ganados"], "cada regate que sirve deja su evento")
	_ok(k["correcciones"] == 0.0, "nadie corrige la pelota (%d)" % int(k["correcciones"]))
	# Sin la opción en el cerebro, nadie encara: es el motor de antes.
	var cerebro: Dictionary = FisicaV2.datos()["cerebro"]
	var factor: float = cerebro["regate_factor"]
	cerebro["regate_factor"] = 0.0
	var sin := _jugar(1)
	cerebro["regate_factor"] = factor
	_ok(sin["regates"] == 0.0 and sin["decide"] == 0.0, "con cerebro.regate_factor en 0 nadie encara")
	_relato()
	var a: Object = CerebroV2.armar_partido(SEED, "Tiki taka", "Juego directo", DIVISION, DIVISION, true)
	var b: Object = CerebroV2.armar_partido(SEED, "Tiki taka", "Juego directo", DIVISION, DIVISION, true)
	a.simular(60 * 60 * 3)
	b.simular(60 * 60 * 3)
	_ok(a.huella() == b.huella() and int(a.contadores()["regates"]) > 0, "la misma semilla da la misma huella con regates")
	print("FALLOS=%d" % fallos)
	quit(1 if fallos > 0 else 0)


## Los contadores sumados de `partidos` partidos con reglas, más `decide` (las
## veces que el cerebro eligió encarar) y `evento_<TipoRegate>`.
func _jugar(partidos: int) -> Dictionary:
	var k := {"regates": 0.0, "regates_amague": 0.0, "regates_ganados": 0.0, "correcciones": 0.0, "decide": 0.0,
		"evento_0": 0.0, "evento_1": 0.0}
	for n in partidos:
		var e: Array = ESTILOS[n % ESTILOS.size()]
		var c: Object = CerebroV2.armar_partido(SEED + n, e[0], e[1], DIVISION, DIVISION, true)
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < PASOS_TOPE:
			c.simular(600)
			pasos += 600
		var cuenta: Dictionary = c.contadores()
		for clave in ["regates", "regates_amague", "regates_ganados", "correcciones"]:
			k[clave] += float(cuenta[clave])
		k["decide"] += float(c.contadores_cerebro()["regate"])
		for ev in c.eventos():
			if str(ev["tipo"]) == "regate":
				k["evento_%d" % int(ev["detalle"])] += 1.0
	return k


## El partido como lo juega la liga: el regate llega al relato con su nombre.
func _relato() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_RELATO
	var local: Team = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(DIVISION), "Uruguay",
		NivelDivision.realizacion(DIVISION))
	var visitante: Team = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(DIVISION), "Uruguay",
		NivelDivision.realizacion(DIVISION))
	var r: Dictionary = MotorV2.simular(local, visitante, rng, true)
	var nombres := RelatoPartido.nombres(local, visitante)
	var con_nombre := 0
	var total := 0
	for ev in r["eventos"]:
		if str(ev["tipo"]) != "gambeta" or str(ev["resultado"]) != "pasa":
			continue
		total += 1
		var linea := RelatoPartido.linea(ev, nombres)
		if MotorV2.REGATES.has(str(ev.get("regate", ""))) and (linea.contains("Elástica") or linea.contains("Croqueta")) \
				and not linea.contains("el rival"):
			con_nombre += 1
	_ok(total > 0 and con_nombre == total, "el relato nombra el regate y a los dos jugadores (%d de %d)" % [con_nombre, total])


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)
