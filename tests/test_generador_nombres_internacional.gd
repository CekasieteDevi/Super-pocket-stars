extends SceneTree

## Nombres por país para el pool internacional (§10.1) — antes los 110
## clubes del exterior eran placeholders "Brasil FC 01" y sus jugadores
## usaban el mismo pool uruguayo que el resto de la pirámide.
## Correr con: godot --headless --script tests/test_generador_nombres_internacional.gd

const SEED := 9898

const PAISES_CON_POOL := [
	"Brasil", "Espana", "Inglaterra", "Italia", "Alemania", "Francia",
	"Argentina", "Portugal", "Paises Bajos", "Mexico", "Colombia",
]


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_todos_los_paises_extranjeros_tienen_pool(rng)
	_test_alias_acentuados_resuelven_al_mismo_pool(rng)
	_test_nombre_club_no_es_el_placeholder_viejo(rng)
	_test_nombre_club_respeta_usados(rng)
	_test_nombre_jugador_usa_el_pool_del_pais(rng)
	_test_pais_desconocido_no_rompe(rng)
	_test_alemania_a_veces_suma_sufijo(rng)
	_test_inglaterra_pone_la_ciudad_primero(rng)
	_test_integracion_confederacion_genera_nombres_reales(rng)
	_test_integracion_club_exterior_jugadores_del_pais(rng)

	quit()


func _test_todos_los_paises_extranjeros_tienen_pool(rng: RandomNumberGenerator) -> void:
	print("=== Los 11 paises extranjeros (todos menos Uruguay) tienen pool propio ===")
	var ok := true
	for pais in PAISES_CON_POOL:
		if not GeneradorNombresInternacional.tiene_pais(pais):
			ok = false
			print("FALLA: %s no tiene pool." % pais)
	if ok:
		print("OK: los 11 tienen pool (%s)." % [PAISES_CON_POOL])


func _test_alias_acentuados_resuelven_al_mismo_pool(rng: RandomNumberGenerator) -> void:
	print("\n=== 'España'/'México'/'Países Bajos' (acentuados) resuelven al mismo pool que 'Espana'/'Mexico'/'Paises Bajos' ===")
	var ok := true
	ok = ok and GeneradorNombresInternacional.tiene_pais("España")
	ok = ok and GeneradorNombresInternacional.tiene_pais("México")
	ok = ok and GeneradorNombresInternacional.tiene_pais("Países Bajos")
	if ok:
		print("OK: los tres alias resuelven a un pool valido.")
	else:
		print("FALLA")


func _test_nombre_club_no_es_el_placeholder_viejo(rng: RandomNumberGenerator) -> void:
	print("\n=== nombre_club() ya no da el placeholder viejo 'Pais FC 01' ===")
	var usados := {}
	var ok := true
	for pais in PAISES_CON_POOL:
		var nombre := GeneradorNombresInternacional.nombre_club(pais, rng, usados)
		if nombre.begins_with("%s FC " % pais):
			ok = false
			print("FALLA: %s sigue dando el placeholder (%s)." % [pais, nombre])
	if ok:
		print("OK: ninguno de los 11 paises cae en el placeholder viejo.")


func _test_nombre_club_respeta_usados(rng: RandomNumberGenerator) -> void:
	print("\n=== nombre_club() no repite nombres ya usados (dentro del mismo pais) ===")
	var usados := {}
	var nombres := {}
	var ok := true
	for i in range(10):
		var nombre := GeneradorNombresInternacional.nombre_club("Brasil", rng, usados)
		if nombres.has(nombre):
			ok = false
			print("FALLA: '%s' salio repetido." % nombre)
			break
		nombres[nombre] = true
	if ok:
		print("OK: 10 nombres de club de Brasil, todos distintos.")


func _test_nombre_jugador_usa_el_pool_del_pais(rng: RandomNumberGenerator) -> void:
	print("\n=== nombre_jugador() usa el pool de apellidos del pais pedido, no el de Uruguay ===")
	var datos: Dictionary = GeneradorNombresInternacional._datos()
	var apellidos_brasil: Array = datos["Brasil"]["apellidos_jugador"]
	var apellidos_uruguay: Array = DataLoader.load_json("res://data/nombres.json")["apellidos_jugador"]

	var ok := true
	for i in range(30):
		var identidad := GeneradorNombresInternacional.nombre_jugador("Brasil", rng)
		if not apellidos_brasil.has(identidad["apellido"]):
			ok = false
			print("FALLA: apellido '%s' no esta en el pool de Brasil." % identidad["apellido"])
			break
	if ok:
		print("OK: 30 jugadores de Brasil, todos con apellido del pool de Brasil.")


func _test_pais_desconocido_no_rompe(rng: RandomNumberGenerator) -> void:
	print("\n=== Un pais sin pool (ej. un typo) no rompe, cae al fallback ===")
	var usados := {}
	var nombre_club := GeneradorNombresInternacional.nombre_club("Narnia", rng, usados)
	var identidad := GeneradorNombresInternacional.nombre_jugador("Narnia", rng)
	if not nombre_club.is_empty() and not identidad["apellido"].is_empty():
		print("OK: club='%s' jugador='%s %s' (fallback, no crashea)." % [nombre_club, identidad["nombre"], identidad["apellido"]])
	else:
		print("FALLA")


func _test_alemania_a_veces_suma_sufijo(rng: RandomNumberGenerator) -> void:
	print("\n=== Alemania a veces suma un sufijo (04/09/1899) al nombre del club ===")
	var usados := {}
	var con_sufijo := 0
	for i in range(60):
		var nombre := GeneradorNombresInternacional.nombre_club("Alemania", rng, usados)
		if nombre.ends_with(" 04") or nombre.ends_with(" 09") or nombre.ends_with(" 1899"):
			con_sufijo += 1
	if con_sufijo > 0:
		print("OK: %d/60 nombres de Alemania con sufijo numerico." % con_sufijo)
	else:
		print("FALLA: ninguno con sufijo en 60 intentos.")


func _test_inglaterra_pone_la_ciudad_primero(rng: RandomNumberGenerator) -> void:
	print("\n=== Inglaterra: 'ciudad + tipo' (ej. 'Preston United'), no al reves ===")
	var usados := {}
	var datos: Dictionary = GeneradorNombresInternacional._datos()["Inglaterra"]
	var tipos: Array = datos["tipos_club"]

	var nombre := GeneradorNombresInternacional.nombre_club("Inglaterra", rng, usados)
	var ultima_palabra := nombre.split(" ")[-1]
	if tipos.has(ultima_palabra):
		print("OK: '%s' termina en un tipo (%s), la ciudad va primero." % [nombre, ultima_palabra])
	else:
		print("FALLA: '%s'" % nombre)


func _test_integracion_confederacion_genera_nombres_reales(rng: RandomNumberGenerator) -> void:
	print("\n=== Integracion: Confederacion.generar() ya no usa el placeholder viejo ===")
	var piramide := Piramide.generar(rng)
	var confederacion := Confederacion.generar(piramide, rng)

	var ok := true
	var revisados := 0
	for pais_entry in confederacion.paises:
		if pais_entry["es_uruguay"]:
			continue
		for club in pais_entry["clubes"]:
			revisados += 1
			if club.nombre.begins_with("%s FC " % pais_entry["nombre"]):
				ok = false

	if ok and revisados == 110:
		print("OK: 110 clubes del exterior revisados, ninguno con el placeholder viejo.")
	else:
		print("FALLA: ok=%s revisados=%d (esperados 110)" % [ok, revisados])


func _test_integracion_club_exterior_jugadores_del_pais(rng: RandomNumberGenerator) -> void:
	print("\n=== Integracion: al materializar un club del exterior, sus jugadores tienen apellidos de SU pais ===")
	var piramide := Piramide.generar(rng)
	var confederacion := Confederacion.generar(piramide, rng)

	var club_brasil: ClubExterior = null
	for pais_entry in confederacion.paises:
		if pais_entry["nombre"] == "Brasil":
			club_brasil = pais_entry["clubes"][0]
			break

	var equipo := club_brasil.obtener_equipo(rng)
	var datos: Dictionary = GeneradorNombresInternacional._datos()
	var apellidos_brasil: Array = datos["Brasil"]["apellidos_jugador"]

	var ok := true
	for j in equipo.todos_los_jugadores():
		if not apellidos_brasil.has(j["apellido"]):
			ok = false
			break

	if ok:
		print("OK: los 18 jugadores del club de Brasil tienen apellido del pool de Brasil.")
	else:
		print("FALLA")
