"""Resume la matriz completa; remuestrea parejas de ida/vuelta, no partidos sueltos."""
import hashlib
import json
import random
import statistics
import sys
from pathlib import Path


def intervalo_pareado(filas, referencia):
    por_semilla = {}
    for fila in filas:
        por_semilla.setdefault(fila["semilla"], []).append(
            fila["actual"]["goles"] - fila[referencia]["goles"]
        )
    diferencias = [statistics.mean(valores) for valores in por_semilla.values()]
    azar = random.Random(97000)
    medias = sorted(
        statistics.mean(azar.choices(diferencias, k=len(diferencias)))
        for _ in range(5000)
    )
    return [medias[125], medias[4874]]


def analizar(carpeta):
    archivos = sorted(carpeta.glob("celda_*/resultados.json"))
    assert len(archivos) == 6, "Faltan celdas completas"
    resumen = []
    versiones = set()
    for archivo in archivos:
        datos = json.loads(archivo.read_text(encoding="utf-8-sig"))
        filas = datos["filas"]
        assert len(filas) >= 100 and len(filas) == datos["parejas_por_celda"] * 2
        assert datos["diferencias_fotogramas"] == 0 and all(f["coincide"] for f in filas)
        assert len({(f["semilla"], f["vuelta"]) for f in filas}) == len(filas)
        parejas = {}
        for fila in filas:
            parejas.setdefault(fila["semilla"], set()).add(fila["vuelta"])
        assert all(lados == {False, True} for lados in parejas.values())
        for motor in ["actual", "base"]:
            copia = archivo.parent / f"motor_{motor}.gd"
            assert hashlib.sha256(copia.read_bytes()).hexdigest() == datos[f"{motor}_sha256"]
        versiones.add(tuple(datos[k] for k in ["actual_sha256", "base_sha256", "abstracto_sha256"]))
        celda = {"division_a": filas[0]["division_a"], "division_b": filas[0]["division_b"],
                 "partidos": len(filas), "parejas": len(parejas)}
        for motor in ["actual", "base", "abstracto"]:
            celda[motor] = {
                metrica: statistics.mean(f[motor][metrica] for f in filas)
                for metrica in ["goles", "ms"]
            }
            if motor != "abstracto":
                celda[motor]["tiros"] = statistics.mean(f[motor]["tiros"] for f in filas)
            celda[motor]["goles_a"] = statistics.mean(
                f[motor]["visitante" if f["vuelta"] else "local"] for f in filas
            )
            celda[motor]["goles_b"] = celda[motor]["goles"] - celda[motor]["goles_a"]
        celda["ms_con_fotogramas"] = statistics.mean(f["ms_con_fotogramas"] for f in filas)
        celda["ic95_diferencia_base"] = intervalo_pareado(filas, "base")
        celda["ic95_diferencia_abstracto"] = intervalo_pareado(filas, "abstracto")
        for referencia in ["base", "abstracto"]:
            denominador = celda[referencia]["goles"]
            celda[f"goles_vs_{referencia}_pct"] = 100 * (celda["actual"]["goles"] / denominador - 1) if denominador else None
        celda["tiros_vs_base_pct"] = 100 * (celda["actual"]["tiros"] / celda["base"]["tiros"] - 1)
        celda["coste_vs_base_pct"] = 100 * (celda["actual"]["ms"] / celda["base"]["ms"] - 1)
        celda["senales"] = [
            clave for clave, limite in [("goles_vs_base_pct", 15), ("goles_vs_abstracto_pct", 15),
                                       ("tiros_vs_base_pct", 15), ("coste_vs_base_pct", 20)]
            if celda[clave] is not None and abs(celda[clave]) > limite
        ]
        resumen.append(celda)
    assert len(versiones) == 1, "Se mezclaron versiones entre celdas"
    salida = {"partidos": sum(c["partidos"] for c in resumen),
              "simulaciones": sum(c["partidos"] for c in resumen) * 4,
              "metodo_ic": "Bootstrap de 5000 remuestras de parejas ida/vuelta, percentiles 2.5 y 97.5; semilla 97000.",
              "versiones": list(next(iter(versiones))), "celdas": resumen}
    (carpeta / "resumen.json").write_text(json.dumps(salida, ensure_ascii=False, indent=2), encoding="utf-8")
    print("celda | goles actual/base/abstracto | tiros actual/base | diferencia base IC95 | señales")
    for c in resumen:
        print(f"D{c['division_a']}/D{c['division_b']} | "
              f"{c['actual']['goles']:.2f}/{c['base']['goles']:.2f}/{c['abstracto']['goles']:.2f} | "
              f"{c['actual']['tiros']:.2f}/{c['base']['tiros']:.2f} | "
              f"{c['ic95_diferencia_base']} | {c['senales']}")
    print(f"VERIFICADO: {salida['partidos']} enfrentamientos; {salida['simulaciones']} simulaciones")


if __name__ == "__main__":
    analizar(Path(sys.argv[1]))
