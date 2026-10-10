extends SceneTree

# BUG: en un saque de arco el arquero mandaba globo a un lateral y la pelota
# se iba por la banda. Un lateral recibe raso: ningún pase del arquero con
# receptor LAT puede salir con globo.

const SEED := 98000
const PARTIDOS := 60
const ARQ := 0
const LAT := 2

var fallos := 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		print("FAIL ", msg)
		fallos += 1


func _init() -> void:
	var pases_a_lat := 0
	var globos_a_lat := 0
	for n in PARTIDOS:
		var c: Object = CerebroV2.armar_partido(SEED + n, "", "", 4, 4, true)
		var roles: PackedInt32Array = c.get_roles()
		var prev: Dictionary = c.contadores()
		var pasos := 0
		var vigilar := false
		var base := 0
		var espera := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 130:
			c.avanzar()
			pasos += 1
			var k: Dictionary = c.contadores()
			if vigilar:
				espera += 1
				var reg: Array = c.registro_pases()
				if reg.size() > base:
					var r: Dictionary = reg[base]
					base += 1
					if int(roles[int(r["pateador"])]) == ARQ:
						var rec: int = int(r["receptor"])
						if rec >= 0 and int(roles[rec]) == LAT:
							pases_a_lat += 1
							if bool(r["globo"]):
								globos_a_lat += 1
						vigilar = false
				elif espera > 1200:
					vigilar = false
			if int(k["saques_saque_arco"]) > int(prev["saques_saque_arco"]):
				vigilar = true
				base = c.registro_pases().size()
				espera = 0
			prev = k
	print("pases del arquero a laterales=%d con globo=%d" % [pases_a_lat, globos_a_lat])
	_ok(globos_a_lat == 0, "ningún saque de arco a un lateral sale con globo")
	quit(1 if fallos > 0 else 0)
