extends SceneTree

## Público (§8.4 #22, core/publico.gd) — modificador de bloque C que
## escala linealmente con Team.fans, 0 a +5. Correr con:
## godot --headless --script tests/test_publico.gd

func _init() -> void:
	_test_sin_fans_no_hay_bonus()
	_test_fans_al_maximo_da_el_bonus_maximo()
	_test_a_mitad_de_fans_da_la_mitad_del_bonus()
	_test_clampea_valores_fuera_de_rango()

	quit()


func _test_sin_fans_no_hay_bonus() -> void:
	print("=== 0 fans = 0 bonus (estadio vacio) ===")
	if is_equal_approx(Publico.modificador(0.0), 0.0):
		print("OK")
	else:
		print("FALLA: %.2f" % Publico.modificador(0.0))


func _test_fans_al_maximo_da_el_bonus_maximo() -> void:
	print("\n=== 100 fans = bonus maximo (+5) ===")
	if is_equal_approx(Publico.modificador(100.0), Publico.BONUS_MAXIMO):
		print("OK: +%.1f" % Publico.BONUS_MAXIMO)
	else:
		print("FALLA: %.2f" % Publico.modificador(100.0))


func _test_a_mitad_de_fans_da_la_mitad_del_bonus() -> void:
	print("\n=== 50 fans = mitad del bonus maximo (escala lineal) ===")
	if is_equal_approx(Publico.modificador(50.0), Publico.BONUS_MAXIMO / 2.0):
		print("OK: +%.2f" % Publico.modificador(50.0))
	else:
		print("FALLA: %.2f" % Publico.modificador(50.0))


func _test_clampea_valores_fuera_de_rango() -> void:
	print("\n=== Valores fuera de [0,100] se clampean (no deberia pasar, pero por las dudas) ===")
	var ok: bool = is_equal_approx(Publico.modificador(-10.0), 0.0) and is_equal_approx(Publico.modificador(150.0), Publico.BONUS_MAXIMO)
	if ok:
		print("OK")
	else:
		print("FALLA: modificador(-10)=%.2f modificador(150)=%.2f" % [Publico.modificador(-10.0), Publico.modificador(150.0)])
