# Resultados con datos reales (Kia Forte L 2019, motor 4 cilindros; iPhone 15 Pro Max, phyphox 1.2.1)

Fecha de medición: 2026-11-24, 11:22–11:56 (UTC-6), motor recién encendido (frío) al inicio. Muestreo 100.0 Hz (Δt = 0.01000 s, jitter 1.7e-6 s).
Generado con `pruebas/prueba_datos_reales.m`.

## Mediciones
| Archivo | Condición | Duración | Muestras | NaN | Huecos |
|---|---|---|---|---|---|
| `motor_ralenti_cofre.csv` | Carro estacionado, motor en ralentí, teléfono sobre el cofre | 63.97 s | 6 397 | 0 | 0 |
| `manejo_tablero.csv` | Manejando, teléfono sobre el tablero | 78.52 s | 7 851 | 0 | 0 |
| `motor_ralenti_cabina.csv` | Estacionado en ralentí, teléfono sobre la tapa del descansabrazos (consola central) | 63.54 s | 6 353 | 0 | 0 |

Los datos reales no traen huecos → la interpolación se evalúa eliminando a propósito el 5 % de las muestras (pérdida simulada en ráfagas) y comparando contra el valor verdadero.

## 1. Vibración del motor (cofre)
- Frecuencia dominante **25.26 Hz** en los 3 ejes → rpm = 120·f / 4 cil ≈ **758 rpm** (ralentí típico de un 4 cilindros).
- Por ventanas de 8 s la frecuencia baja de **25.75 → 25.00 Hz** en un minuto; la medición de phyphox (Acceleration Spectrum) 3 min después dio **≈23 Hz** con armónico en 45 Hz → el ralentí bajó conforme el motor se calentó (ralentí de arranque en frío).
- RMS: x 0.185, y 0.215, z 0.289 m/s². Amplitud de desplazamiento estimada del cofre: x ≈ a_rms/ω² ≈ **11.5 µm** (eje z).

### Integración y drift (eje z, RK4) — verdad física: el carro está quieto (v = 0, x ≈ 0)
| Corrección | v(T) [m/s] | v máx [m/s] | x(T) [m] |
|---|---|---|---|
| Ninguna | −4.094 | 4.094 | **−127.2** |
| Sesgo constante (MC grado 0) | −0.006 | 0.088 | 3.55 |
| Tendencia MC grado 1 | −0.006 | 0.031 | **−0.31** |
Un sesgo de solo −0.064 m/s² integrado 64 s produce 127 m de "desplazamiento" falso. La tendencia por mínimos cuadrados lo reduce más de 400 veces.

### Interpolación con 5 % de pérdida simulada (eje z, 322 muestras evaluadas)
| Método | RMSE [m/s²] | Error máx |
|---|---|---|
| **Lineal** | **0.388** | 0.955 |
| Newton local cúbico | 0.534 | 1.291 |
| Spline cúbico natural | 0.583 | 1.487 |

## 2. Manejo (tablero)
- Pico aislado de **−29.4 m/s² (≈3 g) en t = 24.24 s** (una sola muestra; las vecinas ≈ 1 m/s²): golpe/falla del sensor. El filtro de Hampel lo detecta; el pico del eje x pasa de 25.3 a 3.5 m/s².
- MAD global marcaba 106 "atípicos" en el eje z (eran baches reales) → se cambió a Hampel local (1–5 por eje).
- Vibración vertical (z) dominante **34.2 Hz** (≈1030 rpm en marcha); por ventanas 30–49 Hz (900–1480 rpm).
- Eje x, RK4: sin corrección v(T) = 4.45 m/s y x(T) = 180 m; con sesgo constante v(T) = 0.002 m/s y v máx 2.76 m/s (≈ 9.9 km/h).

### Interpolación con 5 % de pérdida (eje x): lineal 0.567, Newton 0.806, spline 0.949 m/s² (RMSE).

## 3. Ralentí medido en la cabina (descansabrazos) y calentamiento del motor
| Hora | Medición | f dominante | rpm (4 cil) |
|---|---|---|---|
| 11:22 | Cofre, inicio (ventana 0–8 s) | 25.75 Hz | 773 |
| 11:23 | Cofre, final (ventana 48–56 s) | 25.00 Hz | 750 |
| 11:25 | Cofre, Acceleration Spectrum de phyphox | ≈23.05 Hz | ≈692 |
| 11:54 | Cabina, esta app | **22.86 Hz** | **686** |
| 11:55 | Cabina, Acceleration Spectrum de phyphox | 22.65 Hz | 680 |
- La frecuencia de la app coincide con la de phyphox (diferencia 0.2 Hz, menor que la resolución de phyphox de 0.39 Hz) → **validación cruzada contra otro software**.
- El ralentí bajó de ≈773 a ≈686 rpm en 32 min: el motor se calentó (en frío la computadora del motor eleva el ralentí).
- Eje y de la cabina: domina **45.74 Hz = 2 × 22.86 Hz** (segundo armónico).
- **Cofre vs cabina (eje z):** RMS 0.286 → 0.430 m/s², amplitud en la fundamental 0.127 → 0.213 m/s². La cabina vibró **más**: la tapa plástica del descansabrazos se comporta como un panel ligero que amplifica, y las dos mediciones tuvieron rpm distintas (motor frío vs caliente). Por eso **no** se puede afirmar el aislamiento de los soportes del motor con estos datos. Hipótesis refutada → se documenta.
- Drift en cabina (eje z, quieto): sin corrección x(T) = −163.1 m; con tendencia MC x(T) = 0.12 m.
- Interpolación 5 % (eje z): lineal 0.601, Newton 0.828, spline 0.848 m/s² (RMSE) → misma conclusión en las 3 mediciones.

## 4. Interpretación numérica (para el análisis)
- **Interpolación:** con señal suave (sintética) gana el spline (7.6e-6 vs 7.4e-3 lineal); con la vibración real gana la lineal. A 25 Hz con fs = 100 Hz hay **≈3.96 muestras por ciclo** y ruido: los polinomios cúbicos oscilan entre muestras (sobreajuste); la lineal está acotada por los datos vecinos.
- **Derivada a 25.26 Hz** (θ = ωh = 1.587 rad), factor de amplitud teórico: adelante 0.898 (desfase 45.5°), centrada **0.630**, 5 puntos **0.843**. La centrada subestima la amplitud del jerk 37 %; la de 5 puntos 16 %.
- **Integral:** sin corrección, trapecio −3.9988, Simpson 1/3 −3.9978, Simpson 3/8 −4.0086 (diferencias < 0.25 %). Con ruido cercano a Nyquist los pesos alternados 4-2-4 de Simpson pierden su ventaja.
- **EDO:** Heun vs cumtrapz difieren 4e-5 m (son la misma regla); RK4 vs Euler difieren ~0.3 m en x(T).
- **Mínimos cuadrados:** R² ≈ 0 en la vibración (la tendencia no explica la oscilación, solo el sesgo/deriva), lo cual es correcto: la tendencia se usa para quitar el drift, no para modelar la vibración.
