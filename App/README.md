# Analizador numérico de vibraciones (Métodos Numéricos — Proyecto integrador)

## Ejecutar
1. Abrir **esta carpeta** como carpeta actual en MATLAB (R2023 o posterior; solo MATLAB base, sin toolboxes).
2. Ventana de comandos: `ejecutar_app`
3. Pulsar **Señal de prueba** (validación analítica) o **Cargar datos** (`datos/*.csv`).

## Pruebas
| Comando | Qué verifica |
|---|---|
| `run pruebas/prueba_metodos.m` | 19 pruebas: exactitud y orden de convergencia de cada método |
| `run pruebas/prueba_motor.m` | Cadena completa sin interfaz, correcciones de drift, pérdida simulada |
| `run pruebas/prueba_datos_reales.m` | Análisis de las 3 mediciones reales (frecuencias, drift, interpolación, comparación) |
| `run pruebas/prueba_gui.m` | Interfaz completa: botones, todos los menús, tiempo real, grabación y exportación |

## Figuras para el documento y la presentación
`generar_figuras` → 11 figuras en `figuras/claro/` y `figuras/oscuro/` (PNG, 200 dpi): convergencia, espectros, rpm vs tiempo, drift, interpolación, atípico (Hampel), factor de las derivadas, tendencia por mínimos cuadrados.
Además, el botón **Exportar** de la app guarda cada gráfica en tema claro y oscuro (MATLAB R2025a o posterior).

## Estructura
- `AnalizadorVibracionesApp.m` — interfaz gráfica (uifigure, estructura de App Designer)
- `metodos/` — matemática implementada a mano (funciones `nm_*`)
- `pruebas/` — pruebas automáticas
- `datos/` — mediciones (phyphox) y ejemplo sintético
- `bitacora.md` — errores y soluciones
- `protocolo_medicion.md` — cómo tomar los datos en el carro
- `resultados_reales.md` — resultados de las mediciones reales (Kia Forte 2019)
