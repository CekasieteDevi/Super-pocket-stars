extends SceneTree

## Motor V2 (BUG-016): el arquero que saca con la mano o de voleo gira hacia
## donde la manda antes de arrancar el gesto (Canchita::avanzar). El gesto traba
## el rumbo: sin el giro la pelota salía para otro lado que el cuerpo. En estos
## partidos, con la biblioteca anterior, 5 de 7 saques salían a más de 30°.

const SEED := 97000
const PARTIDOS := 15
## El pase sale con error (toque.error_pase_rad): el peor medido en 120
## partidos de décima fue 21°.
const TOPE_GRADOS := 30.0
const SAQUES := ["Arquero_Lanza", "Arquero_Voleo"]

var fallos := 0


func _init() -> void:
	var saques := 0
	var torcidos := 0
	var peor := 0.0
	for n in PARTIDOS:
		var c: Object = CerebroV2.armar_partido(SEED + n, "", "", 4, 4, true)
		var previo := -1
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 130:
			c.avanzar()
			pasos += 1
			var manos: int = c.get_en_manos()
			if manos < 0 and previo >= 0 and str(c.get_accion(previo)) in SAQUES:
				var vel: Vector3 = c.get_pelota_vel()
				var rumbo: float = c.get_rumbo()[previo]
				var grados := absf(rad_to_deg(wrapf(atan2(vel.x, vel.z) - rumbo, -PI, PI)))
				saques += 1
				peor = maxf(peor, grados)
				if grados > TOPE_GRADOS:
					torcidos += 1
			previo = manos
		# La regresión corta el test con 30 s de log quieto.
		print("partido %d: %d saques" % [n, saques])
	_ok(saques >= 5, "el arquero saca con la mano o de voleo (%d saques)" % saques)
	_ok(torcidos == 0, "la pelota sale hacia donde mira el arquero (%d de %d a más de %.0f°, el peor %.1f°)" % [
		torcidos, saques, TOPE_GRADOS, peor])
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
