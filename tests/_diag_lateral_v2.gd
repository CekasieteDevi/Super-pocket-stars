extends SceneTree

## Etapa 6 del Motor V2 (docs/motor_v2.md): a cuánto queda el rival más cercano
## cuando sale el lateral. La regla pide reglas.distancia_lateral_m (2 m) desde
## el punto de la raya. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_lateral_v2.gd -- partidos=80 division=4 semilla=97000

const SEED := 97000
## Cada cuántos pasos se mira la cancha (0,05 s).
const CADA_PASOS := 3
## El cuerpo se para a 2,00 m del punto: "adentro" es a menos de esto.
const ADENTRO_M := 1.9
const MUY_ADENTRO_M := 1.5


func _init() -> void:
	var partidos := 80
	var division := 4
	var semilla := SEED
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"partidos": partidos = maxi(1, int(p[1]))
			"division": division = int(p[1])
			"semilla": semilla = int(p[1])
	var saques := 0.0
	var al_que_saca := 0.0
	var al_punto := 0.0
	var adentro := 0.0
	var muy_adentro := 0.0
	for n in partidos:
		var c: Object = CerebroV2.armar_partido(semilla + n, "", "", division, division, true)
		var pasos := 0
		# La última medida con la pelota en las manos: la del saque.
		var ultima := -1.0
		var ultima_punto := -1.0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(CADA_PASOS)
			pasos += CADA_PASOS
			var estado: Dictionary = c.get_estado()
			var ejecutor := int(estado["ejecutor"])
			if str(estado["parada"]) == "lateral" and ejecutor >= 0 and int(c.get_lateral_en_manos()) >= 0:
				var pos: PackedVector2Array = c.get_pos()
				var equipos: PackedInt32Array = c.get_equipos()
				var punto: Vector2 = estado["punto"]
				ultima = 1e9
				ultima_punto = 1e9
				for i in pos.size():
					if int(equipos[i]) != int(equipos[ejecutor]):
						ultima = minf(ultima, pos[i].distance_to(pos[ejecutor]))
						ultima_punto = minf(ultima_punto, pos[i].distance_to(punto))
			elif ultima >= 0.0:
				saques += 1.0
				al_que_saca += ultima
				al_punto += ultima_punto
				if ultima_punto < ADENTRO_M:
					adentro += 1.0
				if ultima_punto < MUY_ADENTRO_M:
					muy_adentro += 1.0
				ultima = -1.0
	var n_saques := maxf(saques, 1.0)
	print("[lateral] D%d, %d partidos, semilla %d: %.1f laterales por partido. El rival más cercano queda a %.2f m del que saca y a %.2f m del punto de la raya; a menos de %.1f m del punto en el %.0f%% de los laterales y a menos de %.1f m en el %.0f%%." % [
		division + 1, partidos, semilla, saques / partidos, al_que_saca / n_saques, al_punto / n_saques, ADENTRO_M,
		100.0 * adentro / n_saques, MUY_ADENTRO_M, 100.0 * muy_adentro / n_saques])
	quit()
