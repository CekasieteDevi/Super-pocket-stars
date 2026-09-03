extends SceneTree

## Público (§8.4 #22, core/publico.gd) — modificador de bloque C que
## escala linealmente con el APOYO de la hinchada (0..1, ver Fans.apoyo),
## de 0 a +5. Recibe el apoyo y no Team.fans: desde la v1.5 la hinchada
## es una cantidad real y exponencial, y un numero de ocho digitos
## saturaria el bonus para cualquier club de primera. Correr con:
## godot --headless --script tests/test_publico.gd

func _init() -> void:
	_test_sin_fans_no_hay_bonus()
	_test_apoyo_al_maximo_da_el_bonus_maximo()
	_test_a_mitad_de_apoyo_da_la_mitad_del_bonus()
	_test_clampea_valores_fuera_de_rango()

	quit()


func _test_sin_fans_no_hay_bonus() -> void:
	print("=== apoyo 0 = 0 bonus (estadio vacio) ===")
	if is_equal_approx(Publico.modificador(0.0), 0.0):
		print("OK")
	else:
		print("FALLA: %.2f" % Publico.modificador(0.0))


func _test_apoyo_al_maximo_da_el_bonus_maximo() -> void:
	print("\n=== 100 fans = bonus maximo (+5) ===")
	if is_equal_approx(Publico.modificador(100.0), Publico.BONUS_MAXIMO):
		print("OK: +%.1f" % Publico.BONUS_MAXIMO)
	else:
		print("FALLA: %.2f" % Publico.modificador(100.0))


func _test_a_mitad_de_apoyo_da_la_mitad_del_bonus() -> void:
	print("\n=== apoyo 0.5 = mitad del bonus maximo (escala lineal) ===")
	if is_equal_approx(Publico.modificador(0.5), Publico.BONUS_MAXIMO / 2.0):
		print("OK: +%.2f" % Publico.modificador(0.5))
	else:
		print("FALLA: %.2f" % Publico.modificador(0.5))


func _test_clampea_valores_fuera_de_rango() -> void:
	print("\n=== Valores fuera de [0,1] se clampean (no deberia pasar, pero por las dudas) ===")
	var ok: bool = is_equal_approx(Publico.modificador(-0.5), 0.0) and is_equal_approx(Publico.modificador(3.0), Publico.BONUS_MAXIMO)
	if ok:
		print("OK")
	else:
		print("FALLA: modificador(-0.5)=%.2f modificador(3)=%.2f" % [Publico.modificador(-0.5), Publico.modificador(3.0)])
