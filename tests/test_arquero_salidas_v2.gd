extends SceneTree

## Motor V2: la salida del arquero a los centros (Canchita, "Saliendo a una
## pelota que no es un remate" y _alto_que_cree_alcanzar). Revisión del
## 2026-10-03: "salió a buscar un centro y le pasó por arriba; debería pasar
## cuando el golero es malo".
##
## Sin partido: un arquero solo en su arco y un centro que cae al área chica
## desde la banda, diez semillas por caso. No depende del azar de un partido:
## - al centro que llega a la altura de las manos salen los dos, el de mucho
##   achique y el de poco, y lo tocan;
## - al que pasa por arriba de lo que alcanza, el de mucho achique no sale y
##   el de poco sale y le pasa por arriba.
## Y en 40 partidos de quinta, salen a centros y casi ninguno pasa por arriba.
## La medición por división está en tests/_diag_salidas_v2.gd.

const SEED := 97100
const VECES := 10
const PARTIDOS := 40
## El centro sale de la banda derecha, a 8,5 m del fondo, y tarda esto en
## llegar frente al arco, a 2 m de la línea.
const DESDE := Vector3(44.0, 0.11, 30.0)
const LLEGA_X := 50.5
const VUELO_SEG := 1.6
const GRAVEDAD := 9.81
const ARQUERO := 1

var fallos := 0


func _init() -> void:
	for alto in [1.2, 1.8]:
		for achique in [100.0, 0.0]:
			var r := _serie(alto, achique)
			_ok(r["toca"] == VECES and r["falla"] == 0,
				"centro a %.1f m de alto, achique %d: sale y lo toca %d de %d (falla %d)" % [alto, achique, r["toca"], VECES, r["falla"]])
	for alto in [2.7, 3.1]:
		var bueno := _serie(alto, 100.0)
		_ok(bueno["sale"] == 0 and bueno["falla"] == 0,
			"centro a %.1f m de alto, achique 100: no sale (%d salidas, %d falladas)" % [alto, bueno["sale"], bueno["falla"]])
		var malo := _serie(alto, 0.0)
		_ok(malo["sale"] == VECES and malo["por_arriba"] == VECES and malo["toca"] == 0,
			"centro a %.1f m de alto, achique 0: sale %d de %d y le pasa por arriba %d" % [alto, malo["sale"], VECES, malo["por_arriba"]])
	_partidos()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


## Diez centros iguales con semillas distintas: en cuántos el arquero hace un
## gesto (sale), toca la pelota, falla la salida y le pasa por arriba.
func _serie(alto: float, achique: float) -> Dictionary:
	var r := {"sale": 0, "toca": 0, "falla": 0, "por_arriba": 0}
	for k in VECES:
		var c := _cancha(SEED + k, achique)
		# El otro, lejos: el centro es solo del arquero.
		c.poner_jugador(0, Vector2(0.0, -20.0), PI * 0.5)
		c.poner_jugador(ARQUERO, Vector2(51.7, 0.0), -PI * 0.5)
		var meta := Vector3(LLEGA_X, alto, 0.0)
		var vel := Vector3((meta.x - DESDE.x) / VUELO_SEG,
			(meta.y - DESDE.y + 0.5 * GRAVEDAD * VUELO_SEG * VUELO_SEG) / VUELO_SEG, (meta.z - DESDE.z) / VUELO_SEG)
		c.lanzar(DESDE, vel, Vector3.ZERO, 0)
		var sale := false
		for paso in 240:
			c.avanzar()
			sale = sale or str(c.get_accion(ARQUERO)) != ""
		var n: Dictionary = c.contadores()
		r["sale"] += 1 if sale else 0
		r["toca"] += 1 if int(n["salidas_arquero"]) > 0 else 0
		r["falla"] += 1 if int(n["salidas_falladas"]) > 0 else 0
		r["por_arriba"] += 1 if int(n["salidas_por_arriba"]) > 0 else 0
	return r


## En el partido los arqueros salen a centros. Las que le pasan por arriba son
## pocas: en 100 partidos de primera, 0,01 por partido contra 0,31 que toca
## (tests/_diag_salidas_v2.gd, semilla 97000).
func _partidos() -> void:
	var tocadas := 0
	var por_arriba := 0
	for n in PARTIDOS:
		var c: Object = CerebroV2.armar_partido(SEED + n, "", "", 4, 4, true)
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 12:
			c.simular(600)
			pasos += 600
		var k: Dictionary = c.contadores()
		tocadas += int(k["salidas_arquero"])
		por_arriba += int(k["salidas_por_arriba"])
	_ok(tocadas >= 5 and por_arriba * 3 <= tocadas,
		"en %d partidos los arqueros tocan %d pelotas saliendo y %d les pasan por arriba" % [PARTIDOS, tocadas, por_arriba])


## Modo ARCO: el 1 defiende el arco de +x. El 0 no juega.
static func _cancha(semilla: int, achique: float) -> Object:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	c.configurar(FisicaV2.parametros(), FisicaV2.parametros_cuerpo(), FisicaV2.clips(), FisicaV2.parametros_toque())
	c.configurar_remate(FisicaV2.parametros_remate(), FisicaV2.parametros_arquero())
	var a := {"velocidad": 70.0, "aceleracion": 70.0, "agilidad": 70.0, "pases": 70.0, "control": 70.0,
		"tiro": 70.0, "golpe": 70.0, "cabezazo": 70.0}
	c.agregar(0, FisicaV2.jugador_de(a).merged(a))
	var g := {"velocidad": 60.0, "aceleracion": 60.0, "agilidad": 60.0, "reflejos": 70.0, "estirada": 70.0,
		"agarre": 70.0, "achique": achique, "arquero": true}
	c.agregar(1, FisicaV2.jugador_de(g).merged(g))
	c.empezar(CanchitaV2Nativa.ARCO, semilla)
	return c


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
