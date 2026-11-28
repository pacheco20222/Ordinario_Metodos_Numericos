# Documento del proyecto (LaTeX, APA 7)

## Compilar
- **Overleaf:** subir la carpeta `Documento/` **y** `App/` (el documento toma las figuras de `../App/figuras/claro/` y el código de `../App/`). Compilador: **XeLaTeX**; bibliografía: **Biber**.
- **Local:** `latexmk -xelatex main.tex` (requiere TeX Live con `apa7`, `biblatex-apa`, `biber`, fuentes TeX Gyre Termes y DejaVu Sans Mono).

La portada firmada se entrega por separado.

## Estructura
| Archivo | Contenido |
|---|---|
| `main.tex` | Preámbulo APA 7 (modo estudiante) y orden de secciones |
| `secciones/00_resumen.tex` … `06_conclusiones.tex` | Cuerpo del documento |
| `secciones/A_bitacora.tex`, `B_pruebas.tex`, `C_codigo.tex` | Apéndices (bitácora, salida de pruebas, código completo) |
| `anexos/` | Filas de la bitácora (generadas de `App/bitacora.md`) y salidas de las pruebas |
| `referencias.bib` | Referencias (APA 7 vía biblatex-apa) |
| `capturas/` | Capturas y fotografías (ver lista abajo) |

## Capturas pendientes (`capturas/`)
Si un archivo no existe, el PDF muestra un recuadro "PENDIENTE" en su lugar.
| Archivo | Qué capturar |
|---|---|
| `montaje_cofre.jpg` | Foto del teléfono sobre el cofre |
| `montaje_cabina.jpg` | Foto del teléfono sobre el descansabrazos |
| `app_general.png` | Ventana completa, `motor_ralenti_cofre.csv`, eje z, **tema claro** |
| `app_tiempo_real.png` | Pestaña Tiempo real con la grabación activa (segmento rojo, lámpara encendida) |
| `app_validacion.png` | Pestaña Validación después de "Comparar todos los métodos" |
| `app_exportacion.png` | Diálogo de guardado con el nombre escrito |
| `app_archivos.png` | Carpeta con el .xlsx y los PNG claro/oscuro exportados |
| `foto_app_funcionando.jpg` | Fotografía (con el celular) de la computadora ejecutando la app |
