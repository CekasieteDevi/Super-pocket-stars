#!/usr/bin/env python3
"""Arma data/acciones_v2.json para el Motor V2 (docs/motor_v2.md, etapa 2).

Junta dos fuentes, sin Blender:
1. Las definiciones de tools/blender/animaciones_jugador.py (ticks,
   contacto, hueso, aérea). Se leen con `ast`: el script importa bpy y no se
   puede ejecutar acá.
2. Los GLB que usa el juego (assets/3d/jugador.glb y golero.glb): Godot sin
   pantalla lee la duración real de cada animación y mide dónde está el
   punto que toca la pelota en el cuadro de contacto (tools/medir_clips_v2.gd).

Rehacelo cada vez que cambien los clips:
    GODOT=/ruta/al/godot python3 tools/generar_acciones_v2.py
tests/test_cuerpo_v2.gd falla si el JSON no coincide con los GLB.
"""
import ast
import json
import os
import subprocess
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = os.path.join(RAIZ, "tools", "blender", "animaciones_jugador.py")
MEDIR = "res://tools/medir_clips_v2.gd"
CAMPOS = ("ticks", "contacto", "aerea", "bucle", "hueso")


def _valor(nodo):
    """Literales y cuentas entre números (contacto=4.0 / 11.0)."""
    if isinstance(nodo, ast.BinOp):
        a, b = _valor(nodo.left), _valor(nodo.right)
        return {ast.Div: a / b, ast.Mult: a * b, ast.Add: a + b, ast.Sub: a - b}[type(nodo.op)]
    return ast.literal_eval(nodo)


def _campos(llamada, definiciones):
    """Los campos de un dict(...) de una definición. `dict(D['X'], ...)` hereda de X."""
    datos = {}
    for arg in llamada.args:
        if isinstance(arg, ast.Subscript) and isinstance(arg.slice, ast.Constant):
            datos.update(definiciones.get(arg.slice.value, {}))
    for kw in llamada.keywords:
        if kw.arg in CAMPOS:
            try:
                datos[kw.arg] = _valor(kw.value)
            except (ValueError, KeyError, TypeError):
                pass
    return datos


def definiciones_blender():
    arbol = ast.parse(open(BLENDER, encoding="utf-8").read())
    definiciones = {}
    for nodo in ast.walk(arbol):
        # D['Nombre'] = dict(...)
        if isinstance(nodo, ast.Assign) and len(nodo.targets) == 1:
            t = nodo.targets[0]
            if (isinstance(t, ast.Subscript) and isinstance(t.value, ast.Name) and t.value.id == "D"
                    and isinstance(t.slice, ast.Constant) and isinstance(nodo.value, ast.Call)
                    and isinstance(nodo.value.func, ast.Name) and nodo.value.func.id == "dict"):
                definiciones[t.slice.value] = _campos(nodo.value, definiciones)
        # def definicion_agarrar(): return dict(...)  ->  'Agarrar'
        if isinstance(nodo, ast.FunctionDef) and nodo.name.startswith("definicion_"):
            for hijo in ast.walk(nodo):
                if isinstance(hijo, ast.Return) and isinstance(hijo.value, ast.Call):
                    nombre = nodo.name[len("definicion_"):].capitalize()
                    definiciones[nombre] = _campos(hijo.value, definiciones)
    return definiciones


def main():
    godot = os.environ.get("GODOT")
    if not godot:
        sys.exit("Falta GODOT=/ruta/al/godot")
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(definiciones_blender(), f)
        ruta = f.name
    try:
        r = subprocess.run([godot, "--path", RAIZ, "--headless", "--script", MEDIR, "--",
                            "definiciones=" + ruta, "salida=res://data/acciones_v2.json"],
                           capture_output=True, text=True)
    finally:
        os.unlink(ruta)
    lineas = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("[acciones_v2]")]
    print("\n".join(lineas))
    if r.returncode != 0 or not any("ESCRITO" in l for l in lineas):
        sys.exit("medir_clips_v2.gd falló:\n" + r.stdout[-3000:] + r.stderr[-3000:])


if __name__ == "__main__":
    main()
