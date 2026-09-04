#!/usr/bin/env bash
# Corre TODA la regresion en paralelo y devuelve 1 si algo fallo.
#
# En serie tarda mas de diez minutos, y casi todo ese tiempo son dos o
# tres tests que simulan temporadas enteras de las diez divisiones.
# Los 81 tests son procesos independientes: cada uno arma su propio mundo
# con su propia semilla y el unico que toca el disco (test_guardado) usa
# su archivo aparte, user://partida_test.json. O sea que se pueden correr
# todos a la vez sin pisarse.
#
#   bash tests/correr_regresion.sh [trabajos]
#
# `trabajos` por defecto = la mitad de los nucleos, para no dejar la
# maquina sin aire mientras corre.

set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-E:/IntelliJ/Super Pocket Stars/Godot_v4.7.1-stable_win64_console.exe}"
if [ ! -f "$GODOT" ]; then
	echo "No encuentro Godot en: $GODOT"
	echo "Pasalo con GODOT=/ruta/al/godot bash tests/correr_regresion.sh"
	exit 2
fi

NUCLEOS="$(nproc 2>/dev/null || echo 4)"
TRABAJOS="${1:-$(( NUCLEOS / 2 ))}"
[ "$TRABAJOS" -lt 1 ] && TRABAJOS=1

SALIDA="$(mktemp -d)"
trap 'rm -rf "$SALIDA"' EXIT

# Los mas lentos primero: con los pesados al final, los ultimos minutos
# quedan con un solo proceso corriendo y el resto de los nucleos parados.
#
# Medidos en serie (894s la regresion entera): gradiente_persiste 245s,
# libro_de_pases 203s, calendario 88s, gamestate_flujo 74s, noticias 74s.
# Esos cinco son 684 de los 894 — los otros 76 tests juntos son 210s. Si
# se agrega uno pesado, va aca.
LENTOS="test_gradiente_persiste test_libro_de_pases test_calendario"
LENTOS="$LENTOS test_gamestate_flujo test_noticias test_phase2"
LENTOS="$LENTOS test_phase7_internacional test_copas_por_temporada"
ORDEN=""
for n in $LENTOS; do
	[ -f "tests/$n.gd" ] && ORDEN="$ORDEN tests/$n.gd"
done
for f in tests/test_*.gd; do
	case " $ORDEN " in *" $f "*) continue ;; esac
	ORDEN="$ORDEN $f"
done

INICIO="$(date +%s)"
for f in $ORDEN; do
	while [ "$(jobs -rp | wc -l)" -ge "$TRABAJOS" ]; do
		wait -n 2>/dev/null || sleep 0.2
	done
	(
		nombre="$(basename "$f" .gd)"
		"$GODOT" --path . --headless --script "$f" >"$SALIDA/$nombre.log" 2>&1
	) &
done
wait

FALLOS=0
for f in $ORDEN; do
	nombre="$(basename "$f" .gd)"
	log="$SALIDA/$nombre.log"
	[ -f "$log" ] || continue
	if grep -q "FALLA\|SCRIPT ERROR" "$log"; then
		echo "### $f"
		grep "FALLA\|SCRIPT ERROR" "$log" | head -5
		FALLOS=$(( FALLOS + 1 ))
	fi
done

TOTAL="$(ls tests/test_*.gd | wc -l)"
echo "ARCHIVOS_CON_FALLAS=$FALLOS de $TOTAL en $(( $(date +%s) - INICIO ))s con $TRABAJOS en paralelo"
[ "$FALLOS" -eq 0 ] || exit 1
