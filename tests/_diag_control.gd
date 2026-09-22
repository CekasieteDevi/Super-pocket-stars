extends SceneTree

## Etapa 3 del plan de realismo: barrido de los pesos de control y
## orientacion. No es un test: mide. Corre los mismos partidos, con las mismas
## semillas, con varias configuraciones de `control` en el mismo proceso, y
## compara contra "neutra": sin toque largo, demora igual a la espera vieja y
## sin cono de giro. La neutra reproduce el motor anterior a la etapa salvo
## la tirada del control y el giro del cuerpo, que siguen corriendo.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_control.gd -- partidos=6 configs=neutra,actual

const SEED := 33100

const ESCENARIOS := [
	{"a": 0, "b": 0, "etiqueta": "D1 parejo"},
	{"a": 0, "b": 3, "etiqueta": "D1 favorito"},
	{"a": 4, "b": 4, "etiqueta": "D5 parejo"},
	{"a": 9, "b": 9, "etiqueta": "D10 parejo"},
]

const ESTILOS := [
	["Tiki taka", "Juego directo"],
	["Presion alta", "Contragolpe"],
]

## Configuraciones con nombre. Cada una pisa solo lo que nombra; el resto
## sale del json.
const CONFIGS := {
	"neutra": {"malo_max": 0.0, "demora_facil": 1.0, "demora_dificil": 1.0, "cono_sin_giro": 4.0},
	"actual": {},
	"sin_cono": {"cono_sin_giro": 4.0},
	"sin_toque": {"malo_max": 0.0},
	"demora_neutra": {"demora_facil": 1.0, "demora_dificil": 1.0},
	"facil08": {"demora_facil": 0.8, "demora_dificil": 1.8},
	"facil07": {"demora_facil": 0.7, "demora_dificil": 1.9},
	"cono25": {"cono_sin_giro": 2.5},
	"malo05": {"malo_max": 0.5},
	"malo08": {"malo_max": 0.8},
	"f08_c25": {"demora_facil": 0.8, "demora_dificil": 1.8, "cono_sin_giro": 2.5},
	"f08_c25_m05": {"demora_facil": 0.8, "demora_dificil": 1.8, "cono_sin_giro": 2.5, "malo_max": 0.5},
	"f08_sin_cono": {"demora_facil": 0.8, "demora_dificil": 1.8, "cono_sin_giro": 4.0},
	"sin_definir": {"fraccion_para_definir": 1.0},
	"definir06": {"fraccion_para_definir": 0.6},
	"definir025": {"fraccion_para_definir": 0.25},
}

var partidos := 6
var nombres: Array = ["neutra", "actual"]


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() != 2:
			continue
		match partes[0]:
			"partidos": partidos = maxi(1, int(partes[1]))
			"configs": nombres = Array(partes[1].split(","))
	MotorEspacial.pesos_control()
	var originales: Dictionary = MotorEspacial._pesos_control_cache.duplicate()
	print("## Barrido de control - semilla %d, %d partidos por celda, %d celdas" % [
		SEED, partidos, ESCENARIOS.size() * ESTILOS.size()])
	print("%-14s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s" % [
		"config", "goles", "tiros", "pases", "intent", "perd", "pos/t", "recep",
		"toques", "dific", "dem/c", "giro%", "t_vel", "t_pres", "t_ang"])
	for nombre in nombres:
		MotorEspacial._pesos_control_cache = originales.duplicate()
		for clave in CONFIGS.get(nombre, {}):
			MotorEspacial._pesos_control_cache[clave] = CONFIGS[nombre][clave]
		var m := _medir()
		print("%-14s %6.2f %6.2f %6.1f %6.1f %6.1f %6.3f %6.1f %6.2f %6.3f %6.3f %6.1f %6.3f %6.3f %6.3f" % [
			nombre, m["goles"], m["tiros"], m["pases"], m["intentos"], m["perdidas"],
			m["pos_ticks"], m["recepciones"], m["toques"], m["dificultad"], m["demora_c"],
			m["giro_pct"], m["t_vel"], m["t_pres"], m["t_ang"]])
	quit()


func _medir() -> Dictionary:
	var suma := {}
	var n := 0
	for esc in ESCENARIOS:
		for par in ESTILOS:
			for i in range(partidos):
				var st := _partido(esc, par, SEED + i * 17)
				for k in st:
					suma[k] = float(suma.get(k, 0.0)) + float(st[k])
				n += 1
	var r := {}
	for k in suma:
		r[k] = suma[k] / float(n)
	var rec: float = maxf(float(suma.get("recepciones", 0.0)), 1.0)
	r["dificultad"] = float(suma.get("dif_sum", 0.0)) / rec
	r["t_vel"] = float(suma.get("vel_sum", 0.0)) / rec
	r["t_pres"] = float(suma.get("pres_sum", 0.0)) / rec
	r["t_ang"] = float(suma.get("ang_sum", 0.0)) / rec
	r["demora_c"] = float(suma.get("demora", 0.0)) / maxf(float(suma.get("cadencia", 0.0)), 1.0)
	r["giro_pct"] = 100.0 * float(suma.get("giro", 0.0)) / maxf(float(suma.get("decisiones", 0.0)), 1.0)
	return r


func _partido(esc: Dictionary, par: Array, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(esc["a"]),
		"Uruguay", NivelDivision.realizacion(esc["a"]))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(esc["b"]),
		"Uruguay", NivelDivision.realizacion(esc["b"]))
	a.estilo = par[0]
	b.estilo = par[1]
	var rng_p := RandomNumberGenerator.new()
	rng_p.seed = semilla
	var res := MotorEspacial.simular(a, b, rng_p, false)
	var st: Dictionary = res["stats"]
	var ctl: Dictionary = st.get("control", {})
	var pd: Dictionary = st["pase_detalle"]
	var decisiones := 0
	for t in st["decisiones"]:
		decisiones += int(st["decisiones"][t])
	return {
		"goles": float(res["goles_local"]) + float(res["goles_visitante"]),
		"tiros": float(st["tiros"]["home"]) + float(st["tiros"]["away"]),
		"pases": float(st["pases"]["home"]) + float(st["pases"]["away"]),
		"intentos": float(pd["intentos"]),
		"perdidas": float(st["robos"]["ganados"]) + float(pd["interceptado_vuelo"])
			+ float(pd["rival_llego_antes"]) + float(pd["fuera"]),
		"pos_ticks": (float(st["posesion"]["home"]) + float(st["posesion"]["away"])) / maxf(float(st["ticks"]), 1.0),
		"recepciones": float(ctl.get("recepciones", 0)),
		"toques": float(ctl.get("toques_largos", 0)),
		"dif_sum": float(ctl.get("dificultad", 0.0)),
		"vel_sum": float(ctl.get("velocidad", 0.0)),
		"pres_sum": float(ctl.get("presion", 0.0)),
		"ang_sum": float(ctl.get("angulo", 0.0)),
		"demora": float(ctl.get("demora", 0)),
		"cadencia": float(ctl.get("cadencia", 0)),
		"giro": float(ctl.get("decisiones_con_giro", 0)),
		"decisiones": float(decisiones),
	}
