extends SceneTree

## Cuanto le suma a un equipo en el partido el ejercicio que tiene puesto,
## en los dos motores. A entrena un ejercicio y B no entrena nada; mismos
## planteles y mismas semillas para cada ejercicio, asi la diferencia
## contra "libre" es del ejercicio y no del sorteo.
##
## Sirve para calibrar Entrenamiento.EQUIVALENCIA: el efecto de cada
## ejercicio tiene que dar parecido en el MotorEspacial y en el MatchEngine.
## El bonus se agranda (AMPLIFICAR) para que el efecto quede por encima del
## ruido; el reparto entre ejercicios no cambia, porque escala igual.
## Correr no escala: su fila del espacial sale al valor real, y la del
## abstracto sale agrandada (ver Entrenamiento.EQUIVALENCIA).
##
##   <godot> --path . --headless --script tests/_diag_entrenamiento_partido.gd [-- ejercicio ...]
##
## Con ejercicios despues de "--" mide solo esos (mas "libre", que es la
## base). Sirve para repartir la corrida en varios procesos.

const SEED := 9100
const PARTIDOS := 300
const DIVISION := 4
const AMPLIFICAR := 5.0

const EJERCICIOS := [
	["libre", "libre"],
	["correr", "libre"], ["rondo", "libre"], ["obstaculos", "libre"], ["gimnasio", "libre"],
	["libre", "penales"], ["libre", "tiros_libres"], ["libre", "centros"], ["libre", "presion"],
]


func _init() -> void:
	Entrenamiento.BONUS_DUELO *= AMPLIFICAR
	print("bonus por duelo %.1f, %d partidos por fila, division %d" % [
		Entrenamiento.BONUS_DUELO, PARTIDOS, DIVISION + 1])
	print("ejercicio      | espacial GF   GC  dif  | abstracto GF   GC  dif")
	var base := {}
	var pedidos := OS.get_cmdline_user_args()
	var corridas := []
	for par in EJERCICIOS:
		var n: String = par[0] if par[0] != "libre" else par[1]
		if pedidos.is_empty() or n == "libre" or pedidos.has(n):
			corridas.append(par)
	for par in corridas:
		var esp := _medir(par, true)
		var abs_ := _medir(par, false)
		if base.is_empty():
			base = {"esp": esp, "abs": abs_}
		var nombre: String = par[0] if par[0] != "libre" else par[1]
		print("%-14s | %+5.2f %+5.2f %+5.2f    | %+5.2f %+5.2f %+5.2f" % [
			nombre,
			esp[0] - base["esp"][0], esp[1] - base["esp"][1],
			(esp[0] - esp[1]) - (base["esp"][0] - base["esp"][1]),
			abs_[0] - base["abs"][0], abs_[1] - base["abs"][1],
			(abs_[0] - abs_[1]) - (base["abs"][0] - base["abs"][1])])
	print("(libre: espacial %.2f-%.2f, abstracto %.2f-%.2f)" % [
		base["esp"][0], base["esp"][1], base["abs"][0], base["abs"][1]])
	quit()


## Goles de A y de B por partido.
func _medir(par: Array, espacial: bool) -> Array:
	var ga := 0
	var gb := 0
	for i in range(PARTIDOS):
		var r1 := RandomNumberGenerator.new()
		r1.seed = SEED + i
		var a := Team.generar("A", r1, 0, NivelDivision.potencial(DIVISION),
			"Uruguay", NivelDivision.realizacion(DIVISION))
		var b := Team.generar("B", r1, 400, NivelDivision.potencial(DIVISION),
			"Uruguay", NivelDivision.realizacion(DIVISION))
		a.ejercicio_fisico = par[0]
		a.ejercicio_tactico = par[1]
		b.ejercicio_fisico = "libre"
		b.ejercicio_tactico = "libre"
		# Mitad de local y mitad de visitante: la localia no se mezcla con
		# el ejercicio.
		var a_local: bool = i % 2 == 0
		var home: Team = a if a_local else b
		var away: Team = b if a_local else a
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED * 7 + i
		var res: Dictionary = MotorEspacial.simular(home, away, r2, false) if espacial \
			else MatchEngine.simular(home, away, r2)
		var gl := int(res["goles_local"])
		var gv := int(res["goles_visitante"])
		ga += gl if a_local else gv
		gb += gv if a_local else gl
	return [float(ga) / PARTIDOS, float(gb) / PARTIDOS]
