# Prompt para Claude Code — Mini plataforma web del Analizador de Vibraciones

> Copia todo lo que está debajo de la línea y pégalo en Claude Code, abierto en la raíz del repositorio `Ordinario_Metodos_Numericos`.

---

Quiero que construyas una **mini plataforma web estática** para acompañar mi proyecto final de Métodos Numéricos. Es un analizador numérico de vibraciones en MATLAB que ya está en este repositorio. La web es un extra para la presentación: debe verse profesional, funcionar sin servidor y desplegarse en **GitHub Pages**. Lee primero `App/README.md`, `App/resultados_reales.md`, `App/bitacora.md`, `App/metodos/*.m` y `Documento/secciones/02_marco_teorico.tex` para entender el proyecto.

## Contexto del proyecto
- Caso: vibración de un Kia Forte L 2019 (4 cilindros) medida con el acelerómetro de un iPhone 15 Pro Max usando phyphox a 100 Hz.
- Tres mediciones reales en `App/datos/`: `motor_ralenti_cofre.csv`, `motor_ralenti_cabina.csv`, `manejo_tablero.csv`. Formato phyphox: columna 1 = tiempo (s); columnas 2–4 = aceleración lineal x, y, z (m/s²); columna 5 = magnitud.
- Métodos en MATLAB (carpeta `App/metodos/`): detección de faltantes (NaN, huecos, filtro de Hampel), interpolación (lineal, Newton local cúbico, spline cúbico natural con Thomas), derivada (adelante, atrás, centrada, 5 puntos), integral (trapecio, Simpson 1/3, Simpson 3/8, acumulada), EDO del movimiento (Euler, Heun, RK4), mínimos cuadrados con variable escalada y Gauss con pivoteo, corrección de deriva (ninguna, sesgo, tendencia, reposo), FFT y rpm = 120·f/cilindros.
- Resultados clave que la web debe reproducir: f dominante del cofre 25.26 Hz (≈758 rpm); cabina 22.86 Hz (≈686 rpm); drift del cofre sin corrección x(T) = −127.23 m y con tendencia MC grado 1 x(T) = −0.31 m (RK4, eje z).

## Lo que debe tener la web
1. **Inicio**: título del proyecto, resumen corto del caso, las cifras clave en tarjetas (rpm, drift 127 m → 0.31 m, órdenes de convergencia) y botones a las secciones.
2. **Analizador interactivo** (la pieza principal):
   - Cargar un CSV o XLSX de phyphox (arrastrar y soltar) o elegir una de las 3 mediciones incluidas.
   - Los mismos controles que la app de MATLAB: eje, interpolación, grado Lagrange, % de pérdida simulada, atípicos (Hampel), derivada, integral, EDO, grado de tendencia, corrección de deriva, cilindros y f mínima del espectro.
   - Gráficas interactivas (zoom/pan): señal original con puntos interpolados, señal procesada + tendencia, derivada, velocidad/posición, espectro.
   - Panel de resultados con los mismos indicadores que la app de MATLAB.
   - **Modo tiempo real**: reproducir la señal con ventana móvil, botones Iniciar grabación / Terminar grabación y exportar el segmento a CSV con el nombre que escriba el usuario (igual que en MATLAB).
3. **Simulador de motor**: sliders de rpm (600–6000), cilindros (3, 4, 6, 8), frecuencia de muestreo (25–400 Hz), ruido, sesgo del sensor y % de pérdida. Genera una señal sintética y la procesa en vivo. Debe mostrar claramente el **aliasing**: cuando la frecuencia de encendido supera fs/2, la frecuencia medida es falsa. Muestra la frecuencia real contra la medida y una alerta de Nyquist. También debe dejar ver cómo el sesgo produce desplazamiento falso (½·b·t²) y cómo lo corrige la tendencia por mínimos cuadrados.
4. **Comparación de métodos**: tabla y gráfica de barras (escala log) con el error de cada método, contra la señal analítica de prueba (`nm_senal_prueba.m`: A=2, f=1.37 Hz, b0=0.05, b1=0.01, 10 s, 100 Hz, 3 % faltantes) y contra la pérdida simulada en datos reales. Incluye las gráficas de convergencia log-log con la pendiente (orden) calculada.
5. **Teoría**: las fórmulas de cada método, en KaTeX y en español, tomadas de `Documento/secciones/02_marco_teorico.tex`.
6. **Ejecutar en MATLAB**:
   - Un botón **"Abrir en MATLAB Online"** que use el formato `https://matlab.mathworks.com/open/github/v1?repo=pacheco20222/Ordinario_Metodos_Numericos&file=App/ejecutar_app.m`. Verifica en la documentación de MathWorks el formato exacto vigente del enlace "Open in MATLAB Online" antes de usarlo.
   - Un bloque **"Código MATLAB equivalente"** que genere en vivo, con los parámetros elegidos en la web, la llamada a `nm_procesar(t, y, struct(...))`, con botón de copiar. Así se demuestra que la web y MATLAB usan los mismos métodos.
   - Deja claro en la página que ejecutar MATLAB en el servidor requeriría MATLAB Web App Server o Production Server, que necesitan licencia; por eso la web usa una reimplementación en TypeScript validada contra MATLAB.

## Requisitos técnicos
- Stack: **Vite + TypeScript** (React o Svelte, a tu criterio). Gráficas con **Plotly.js** o **uPlot**. Fórmulas con **KaTeX**. XLSX con **SheetJS**. Sin backend.
- **Núcleo numérico en TypeScript** (`web/src/numerics/`): traduce fielmente cada `nm_*.m` (mismos algoritmos, mismos casos en los bordes, mismo manejo de residuos en Simpson). No uses librerías numéricas que hagan el trabajo por ti. La FFT puede ser una implementación propia radix-2 con relleno de ceros, o una DFT directa si n es pequeño; documenta la decisión. **Ojo:** la frecuencia dominante debe coincidir con MATLAB (25.26 Hz), así que no cambies la resolución espectral sin comprobarlo.
- **Pruebas** (Vitest) que repliquen `App/pruebas/prueba_metodos.m`: órdenes de convergencia (derivadas 1/1/2/4, integrales 2/4/4, EDO ≈1/2/4) y exactitud de Simpson con cúbicas. Agrega una prueba con `motor_ralenti_cofre.csv` que verifique fDom = 25.26 ± 0.02 Hz y x(T) sin corrección = −127.2 ± 0.5 m (RK4, eje z, spline).
- Si te sirve para validar, crea `App/exportar_referencia_web.m`, que guarde en JSON los resultados de MATLAB para las 3 mediciones. Así las pruebas comparan contra MATLAB directamente.
- Todo en **español**. Tema claro/oscuro con interruptor. Diseño responsivo, que se vea bien en un proyector.
- Despliegue: carpeta `web/`, workflow de GitHub Actions que construya y publique en GitHub Pages, y `web/README.md` con instrucciones.
- No modifiques nada en `App/metodos/`, `App/AnalizadorVibracionesApp.m` ni `Documento/` sin preguntarme.

## Cómo quiero que trabajes
1. Primero dame un plan corto: estructura de carpetas, librerías y orden de trabajo. Espera mi OK.
2. Implementa primero el núcleo numérico con sus pruebas y no sigas a la interfaz hasta que pasen.
3. Luego la interfaz, sección por sección.
4. Al final: `npm run build` sin errores, todas las pruebas en verde y una captura o descripción de cada sección. Agrega una entrada a `App/bitacora.md` por cada error relevante que encuentres y cómo lo resolviste, con el mismo formato de tabla.
