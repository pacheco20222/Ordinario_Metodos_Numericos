# Protocolo de medición — iPhone + phyphox + carro

## Seguridad (obligatorio)
- **El conductor no toca el teléfono.** Otra persona controla phyphox, o se inicia la medición antes de arrancar.
- Ensayo B solo en estacionamiento vacío o calle sin tráfico, en línea recta, a baja velocidad.

## Preparación
1. phyphox → experimento **"Aceleración (sin g)"** (*Acceleration without g*).
2. Teléfono **plano, pantalla hacia arriba, con la parte superior apuntando al frente del carro**, bien fijo (tapete antiderrapante o cinta), sobre la consola o el piso del copiloto.
   - Ejes de phyphox en iPhone: **x** = lateral (giros), **y** = adelante/atrás (acelerar/frenar), **z** = vertical (vibración del motor/camino).
3. Tomar una foto del montaje (va en el documento).
4. Anotar: modelo del carro, número de cilindros y rpm de ralentí si hay tacómetro.

## Ensayo A — Vibración del motor (carro estacionado)
| Tiempo | Acción |
|---|---|
| 0–10 s | Motor apagado, nadie se mueve (reposo: calibra el sesgo) |
| 10 s | Encender motor |
| 10–40 s | Ralentí |
| 40–50 s | Mantener ≈1200 rpm (si hay tacómetro, anotar el valor) |
| 50–60 s | Regresar a ralentí y detener la medición |
- En la app: eje **z**, vista **Espectro (FFT)**. Comprobar que rpm ≈ 120·f / cilindros coincide con el tacómetro.
- Límite: el iPhone muestrea a ≈100 Hz, entonces solo se ven frecuencias < 50 Hz (Nyquist). Con 4 cilindros eso equivale a ≈1500 rpm; por eso no se sube más.

## Ensayo B — Arranque, crucero y frenado
| Tiempo | Acción |
|---|---|
| 0–5 s | Detenido |
| 5–15 s | Acelerar suave hasta ≈20 km/h |
| 15–20 s | Mantener velocidad (copiloto anota la velocidad del velocímetro) |
| 20–28 s | Frenar hasta detenerse |
| 28–33 s | Detenido, terminar medición |
- En la app: eje **y**, corrección de drift **Sesgo constante**, EDO **RK4**.
- Validación: velocidad máxima de la app (km/h) vs velocímetro; distancia x(T) vs distancia medida (cajones de estacionamiento ≈ 2.5 m c/u, o Google Maps).
- Repetir 2–3 veces y probar sin corrección de drift para mostrar el error.

## Exportar desde phyphox
Menú (⋮) → **Exportar datos** → **CSV (Comma, decimal point)**. Se descarga un .zip; descomprimir y usar `Raw Data.csv`.
Copiarlo a `datos/` con nombre descriptivo: `motor_ralenti.csv`, `arranque_frenado_1.csv`.
