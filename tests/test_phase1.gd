extends SceneTree

## Fase 1 del roadmap (GDD §13, §18): generador de jugadores + media general + genética.
## Correr con: godot --headless --script tests/test_phase1.gd
##
## Criterios de aceptación:
##   1. Curva de medias creíble.
##   2. Tiers de genética en la proporción de la tabla del §4.
##   3. Un defensor con quite 80 tiene media alta; un delantero con quite 80 no.

const N := 10000
const SEED := 12345


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var players := []
	for i in range(N):
		players.append(PlayerGenerator.generate(i, rng))

	_print_tier_distribution(players)
	_print_media_curve(players)
	_print_position_sanity_check()
	_print_sample(players)

	quit()


func _print_tier_distribution(players: Array) -> void:
	var counts := {}
	for p in players:
		var t = p["genetica_tier"]
		counts[t] = counts.get(t, 0) + 1

	print("\n=== Distribucion de tiers de genetica (N=%d) ===" % players.size())
	for t in Genetics.get_tiers():
		var name = t["tier"]
		var esperado = float(t["prob"])
		var real = counts.get(name, 0)
		var pct = 100.0 * real / players.size()
		print("%-12s esperado %5.2f%%  real %5.2f%%  (%d)" % [name, esperado, pct, real])


func _print_media_curve(players: Array) -> void:
	var buckets := {}
	for p in players:
		var b = int(p["media"] / 10) * 10
		buckets[b] = buckets.get(b, 0) + 1

	print("\n=== Curva de medias (posicion natural) ===")
	var keys = buckets.keys()
	keys.sort()
	for k in keys:
		var bar := "#".repeat(int(buckets[k] / 20.0))
		print("%3d-%3d : %s (%d)" % [k, k + 9, bar, buckets[k]])


func _print_position_sanity_check() -> void:
	print("\n=== Chequeo posicion: quite 80 en DFC vs DC ===")
	var base_attrs := {}
	for attr in PlayerGenerator.get_all_attributes():
		base_attrs[attr] = 50
	base_attrs["quite"] = 80

	var media_dfc := PlayerGenerator.compute_media(base_attrs, "DFC")
	var media_dc := PlayerGenerator.compute_media(base_attrs, "DC")
	print("Media como DFC (quite 80, resto 50): %.1f" % media_dfc)
	print("Media como DC  (quite 80, resto 50): %.1f" % media_dc)
	if media_dfc > media_dc:
		print("OK: el quite alto pesa en el defensor y no en el delantero.")
	else:
		print("FALLA: revisar pesos de posicion.")


func _print_sample(players: Array) -> void:
	print("\n=== Muestra de 5 jugadores ===")
	for i in range(5):
		var p = players[i]
		print("#%d %s | genetica %s (potencial %d) | media %.1f | mejor pos: %s (%.1f)" % [
			p["id"], p["posicion"], p["genetica_tier"], p["potencial"],
			p["media"], p["mejor_posicion"], p["media_mejor_posicion"]
		])
