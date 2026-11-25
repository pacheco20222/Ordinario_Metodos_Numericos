% GENERAR_FIGURAS  Genera todas las figuras del documento y la presentación
% en dos versiones: figuras/claro (fondo blanco) y figuras/oscuro.
%   Usa paletas definidas a mano para que el resultado sea idéntico en
%   cualquier versión de MATLAB (con o sin temas claro/oscuro).
%   Ejecutar desde la carpeta del proyecto:  generar_figuras
clear; close all;
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'metodos'));
temas = {'claro', 'oscuro'};

% ---------------- Datos ----------------
fprintf('Cargando datos y calculando...\n');
Dco = nm_cargar_datos(fullfile(raiz, 'datos', 'motor_ralenti_cofre.csv'));
Dca = nm_cargar_datos(fullfile(raiz, 'datos', 'motor_ralenti_cabina.csv'));
Dma = nm_cargar_datos(fullfile(raiz, 'datos', 'manejo_tablero.csv'));
S   = nm_senal_prueba(10, 100, 0.03, 0);

Rco = nm_procesar(Dco.t, Dco.Y(:,3), struct('metodoDrift', 'tendencia'));
Rca = nm_procesar(Dca.t, Dca.Y(:,3), struct('metodoDrift', 'tendencia'));
derivas = {'ninguna', 'sesgo', 'tendencia'};
nomDer  = {'Sin corrección', 'Sesgo constante (MC grado 0)', 'Tendencia MC grado 1'};
Rdr = cell(1, 3);
for k = 1:3
    Rdr{k} = nm_procesar(Dco.t, Dco.Y(:,3), struct('metodoDrift', derivas{k}));
end
Rma0 = nm_procesar(Dma.t, Dma.Y(:,1), struct('metodoDrift', 'ninguna', 'usarAtipicos', true));
Rma1 = nm_procesar(Dma.t, Dma.Y(:,1), struct('metodoDrift', 'sesgo', 'usarAtipicos', true));
RmaA = nm_procesar(Dma.t, Dma.Y(:,1), struct('usarAtipicos', true));

% Interpolación: RMSE con 5 % de pérdida simulada (promedio de 5 semillas)
metI = {'lineal', 'lagrange', 'spline'};
nomI = {'Lineal', 'Newton local cúbico', 'Spline cúbico natural'};
casos = {Dco, 3, 'Cofre (z)'; Dca, 3, 'Cabina (z)'; Dma, 1, 'Manejo (x)'};
RMSE = zeros(size(casos,1) + 1, 3);
for c = 1:size(casos,1)
    D = casos{c,1}; e = casos{c,2};
    for m = 1:3
        acum = 0;
        for sem = 1:5
            Rp = nm_procesar(D.t, D.Y(:,e), struct('pPerdida', 5, 'semilla', sem, ...
                'metodoInterp', metI{m}, 'usarAtipicos', true));
            acum = acum + Rp.perdida.rmse;
        end
        RMSE(c, m) = acum / 5;
    end
end
for m = 1:3   % señal sintética: error máximo en los faltantes vs analítica
    [yu, r] = nm_interpolar(S.t, S.a, metI{m});
    RMSE(end, m) = sqrt(mean((yu(r.esFaltante) - S.aRef(r.esFaltante)).^2));
end
nomCasos = [casos(:,3); {'Sintética (suave)'}];

% Convergencia
hs = [0.1 0.05 0.025 0.0125];
mD = {'adelante', 'atras', 'centrada', 'cinco'}; nD = {'Adelante O(h)', 'Atrás O(h)', 'Centrada O(h^2)', '5 puntos O(h^4)'};
ED = zeros(4, numel(hs));
for i = 1:4
    for j = 1:numel(hs)
        x = (0:hs(j):2*pi)';
        ED(i,j) = max(abs(nm_derivada(sin(x), hs(j), mD{i}) - cos(x)));
    end
end
ns = [12 24 48 96]; Hn = pi ./ ns;
mJ = {'trapecio', 'simpson13', 'simpson38'}; nJ = {'Trapecio O(h^2)', 'Simpson 1/3 O(h^4)', 'Simpson 3/8 O(h^4)'};
EJ = zeros(3, numel(ns));
for i = 1:3
    for j = 1:numel(ns)
        x = linspace(0, pi, ns(j)+1)';
        EJ(i,j) = abs(nm_integral(sin(x), Hn(j), mJ{i}) - 2);
    end
end
He = [0.02 0.01 0.005];
mE = {'euler', 'heun', 'rk4'}; nE = {'Euler O(h)', 'Heun O(h^2)', 'RK4 O(h^4)'};
EE = zeros(3, numel(He));
for i = 1:3
    for j = 1:numel(He)
        tt = (0:He(j):10)'; aa = S.A*sin(S.w*tt) + S.b0 + S.b1*tt;
        [~, xx] = nm_edo_movimiento(tt, aa, mE{i});
        xr = S.A/S.w*(tt - sin(S.w*tt)/S.w) + S.b0*tt.^2/2 + S.b1*tt.^3/6;
        EE(i,j) = max(abs(xx - xr));
    end
end

% Frecuencia dominante por ventanas de 8 s (cofre y cabina)
[tvCo, fvCo] = frec_ventanas(Rco.t, Rco.y, 8);
[tvCa, fvCa] = frec_ventanas(Rca.t, Rca.y, 8);
desfaseCabina = (11*60 + 53 + 57.7/60) - (11*60 + 22 + 1.3/60);   % min entre inicios

% ---------------- Figuras ----------------
for it = 1:2
    P = paleta(temas{it});
    carpeta = fullfile(raiz, 'figuras', temas{it});
    if ~exist(carpeta, 'dir'), mkdir(carpeta); end
    fprintf('Tema %s -> %s\n', temas{it}, carpeta);

    % F01 Señal sintética: datos con faltantes e interpolación
    f = nueva(P, [900 380]); ax = axes(f); hold(ax, 'on');
    plot(ax, S.tRef, S.aRef, ':', 'Color', P.gris, 'LineWidth', 1);
    plot(ax, S.t, S.a, '.', 'Color', P.c{1}, 'MarkerSize', 8);
    [yu, r] = nm_interpolar(S.t, S.a, 'spline');
    plot(ax, r.malla(r.esFaltante), yu(r.esFaltante), 'o', 'Color', P.rojo, 'MarkerFaceColor', P.rojo, 'MarkerSize', 5);
    xlim(ax, [0 4]);
    estilo(ax, P, 'Señal de prueba: muestras, faltantes y reconstrucción (spline)', 't [s]', 'a [m/s^2]');
    leyenda(ax, P, {'Solución analítica', 'Muestras disponibles', 'Puntos interpolados'});
    guardar(f, carpeta, 'f01_senal_prueba_faltantes');

    % F02 Convergencia (3 paneles)
    f = nueva(P, [1200 400]);
    ax = subplot(1,3,1, 'Parent', f); hold(ax, 'on');
    est = {'-o', '--s', '-o', '-o'};   % adelante y atrás tienen el mismo error: se distinguen por estilo
    for i = 1:4, loglog(ax, hs, ED(i,:), est{i}, 'Color', P.c{i}, 'LineWidth', 1.4, 'MarkerSize', 6 + 3*(i==2)); end
    set(ax, 'XScale', 'log', 'YScale', 'log');
    estilo(ax, P, 'Derivada (f = sin t)', 'h', 'error máximo'); leyenda(ax, P, nD, 'southeast');
    ax = subplot(1,3,2, 'Parent', f); hold(ax, 'on');
    for i = 1:3, loglog(ax, Hn, EJ(i,:), '-o', 'Color', P.c{i}, 'LineWidth', 1.4, 'MarkerFaceColor', P.c{i}); end
    set(ax, 'XScale', 'log', 'YScale', 'log');
    estilo(ax, P, 'Integral de sin t en [0, π] = 2', 'h', 'error absoluto'); leyenda(ax, P, nJ, 'southeast');
    ax = subplot(1,3,3, 'Parent', f); hold(ax, 'on');
    for i = 1:3, loglog(ax, He, EE(i,:), '-o', 'Color', P.c{i}, 'LineWidth', 1.4, 'MarkerFaceColor', P.c{i}); end
    set(ax, 'XScale', 'log', 'YScale', 'log');
    estilo(ax, P, 'EDO: posición x(t)', 'h [s]', 'error máximo'); leyenda(ax, P, nE, 'southeast');
    guardar(f, carpeta, 'f02_convergencia');

    % F03 Señal real del cofre: completa y zoom de 0.4 s
    f = nueva(P, [1100 420]);
    ax = subplot(1,2,1, 'Parent', f);
    plot(ax, Rco.tOrig, Rco.yOrig, 'Color', P.c{1}, 'LineWidth', 0.5);
    estilo(ax, P, 'Cofre, motor en ralentí (eje z)', 't [s]', 'a [m/s^2]'); xlim(ax, [0 Rco.t(end)]);
    ax = subplot(1,2,2, 'Parent', f); hold(ax, 'on');
    idx = Rco.tOrig >= 20 & Rco.tOrig <= 20.4;
    plot(ax, Rco.tOrig(idx), Rco.yOrig(idx), '-o', 'Color', P.c{1}, 'MarkerFaceColor', P.c{1}, 'MarkerSize', 4);
    estilo(ax, P, 'Zoom 0.4 s: ≈4 muestras por ciclo', 't [s]', 'a [m/s^2]');
    guardar(f, carpeta, 'f03_cofre_senal_y_zoom');

    % F04 Espectros cofre vs cabina
    f = nueva(P, [1000 420]); ax = axes(f); hold(ax, 'on');
    plot(ax, Rco.fEsp, Rco.ampEsp, 'Color', P.c{1}, 'LineWidth', 1);
    plot(ax, Rca.fEsp, Rca.ampEsp, 'Color', P.c{2}, 'LineWidth', 1);
    plot(ax, Rco.fDom, interp1(Rco.fEsp, Rco.ampEsp, Rco.fDom), 'v', 'Color', P.c{1}, 'MarkerFaceColor', P.c{1}, 'MarkerSize', 8);
    plot(ax, Rca.fDom, interp1(Rca.fEsp, Rca.ampEsp, Rca.fDom), 'v', 'Color', P.c{2}, 'MarkerFaceColor', P.c{2}, 'MarkerSize', 8);
    text(ax, Rco.fDom + 0.8, interp1(Rco.fEsp, Rco.ampEsp, Rco.fDom), sprintf('%.2f Hz ≈ %.0f rpm (frío)', Rco.fDom, 30*Rco.fDom), 'Color', P.fg);
    text(ax, Rca.fDom - 0.8, interp1(Rca.fEsp, Rca.ampEsp, Rca.fDom), sprintf('%.2f Hz ≈ %.0f rpm (caliente)', Rca.fDom, 30*Rca.fDom), 'Color', P.fg, 'HorizontalAlignment', 'right');
    xlim(ax, [0 50]);
    estilo(ax, P, 'Espectro de la vibración (FFT, eje z) — Kia Forte 2019, 4 cilindros', 'f [Hz]', 'amplitud [m/s^2]');
    leyenda(ax, P, {'Cofre (motor frío)', 'Descansabrazos (motor caliente)'});
    guardar(f, carpeta, 'f04_espectro_cofre_vs_cabina');

    % F05 Frecuencia dominante vs tiempo (calentamiento del motor)
    f = nueva(P, [900 400]); ax = axes(f); hold(ax, 'on');
    plot(ax, tvCo/60, 30*fvCo, '-o', 'Color', P.c{1}, 'MarkerFaceColor', P.c{1}, 'LineWidth', 1.4);
    plot(ax, desfaseCabina + tvCa/60, 30*fvCa, '-s', 'Color', P.c{2}, 'MarkerFaceColor', P.c{2}, 'LineWidth', 1.4);
    plot(ax, (11*60+25+54.7/60) - (11*60+22+1.3/60), 30*23.05, 'd', 'Color', P.c{3}, 'MarkerFaceColor', P.c{3}, 'MarkerSize', 8);
    plot(ax, (11*60+55+33.5/60) - (11*60+22+1.3/60), 30*22.65, 'd', 'Color', P.c{4}, 'MarkerFaceColor', P.c{4}, 'MarkerSize', 8);
    estilo(ax, P, 'Ralentí estimado: rpm = 120 f / 4 cilindros', 'minutos desde el arranque', 'rpm');
    leyenda(ax, P, {'Cofre (esta app)', 'Descansabrazos (esta app)', 'Cofre (phyphox)', 'Descansabrazos (phyphox)'}, 'northeast');
    guardar(f, carpeta, 'f05_rpm_vs_tiempo');

    % F06 Drift: velocidad y posición del carro estacionado
    f = nueva(P, [1100 420]);
    ax = subplot(1,2,1, 'Parent', f); hold(ax, 'on');
    for k = 1:3, plot(ax, Rdr{k}.t, Rdr{k}.v, 'Color', P.c{k}, 'LineWidth', 1.3); end
    estilo(ax, P, 'Velocidad integrada (carro quieto: v = 0)', 't [s]', 'v [m/s]');
    leyenda(ax, P, nomDer, 'southwest');
    ax = subplot(1,2,2, 'Parent', f); hold(ax, 'on');
    for k = 1:3, plot(ax, Rdr{k}.t, Rdr{k}.x, 'Color', P.c{k}, 'LineWidth', 1.3); end
    estilo(ax, P, sprintf('Posición: x(T) = %.1f / %.2f / %.2f m', Rdr{1}.xFinal, Rdr{2}.xFinal, Rdr{3}.xFinal), 't [s]', 'x [m]');
    guardar(f, carpeta, 'f06_drift_velocidad_posicion');

    % F07 Interpolación: RMSE por método y caso
    f = nueva(P, [950 420]); ax = axes(f); hold(ax, 'on');
    b = bar(ax, RMSE, 'grouped');
    for m = 1:3, set(b(m), 'FaceColor', P.c{m}, 'EdgeColor', 'none'); end
    for m = 1:3, set(b(m), 'BaseValue', 1e-6); end
    set(ax, 'YScale', 'log', 'XTick', 1:numel(nomCasos), 'XTickLabel', nomCasos);
    ylim(ax, [1e-6 3]);
    estilo(ax, P, 'Error de interpolación (5 % de muestras eliminadas)', '', 'RMSE [m/s^2] (escala log)');
    leyenda(ax, P, nomI, 'northeast');
    guardar(f, carpeta, 'f07_interpolacion_rmse');

    % F08 Atípico detectado con Hampel en el manejo
    f = nueva(P, [950 400]); ax = axes(f); hold(ax, 'on');
    idx = Rma0.tOrig >= 23.5 & Rma0.tOrig <= 25;
    plot(ax, Rma0.tOrig(idx), Rma0.yOrig(idx), '-', 'Color', P.c{1});
    ia = RmaA.falt.idxAtipico;
    sel = RmaA.falt.tOrdenado(ia) >= 23.5 & RmaA.falt.tOrdenado(ia) <= 25;
    plot(ax, RmaA.falt.tOrdenado(ia(sel)), RmaA.falt.yOrdenado(ia(sel)), 'o', 'Color', P.rojo, 'MarkerSize', 9, 'LineWidth', 1.5);
    idx2 = RmaA.t >= 23.5 & RmaA.t <= 25;
    plot(ax, RmaA.t(idx2), RmaA.y(idx2), '-', 'Color', P.c{2}, 'LineWidth', 1.2);
    estilo(ax, P, 'Manejo, eje x: pico aislado de -29.4 m/s^2 (≈3 g) detectado con Hampel', 't [s]', 'a [m/s^2]');
    leyenda(ax, P, {'Señal original', 'Atípicos detectados', 'Señal reconstruida'}, 'southeast');
    guardar(f, carpeta, 'f08_atipico_hampel');

    % F09 Factor de amplitud de las derivadas numéricas vs frecuencia
    f = nueva(P, [900 400]); ax = axes(f); hold(ax, 'on');
    r = linspace(0.001, 0.5, 300); th = 2*pi*r;
    plot(ax, r, 2*sin(th/2)./th, 'Color', P.c{1}, 'LineWidth', 1.5);
    plot(ax, r, sin(th)./th, 'Color', P.c{2}, 'LineWidth', 1.5);
    plot(ax, r, (8*sin(th) - sin(2*th))./(6*th), 'Color', P.c{3}, 'LineWidth', 1.5);
    plot(ax, [Rco.fDom Rco.fDom]/100, [0 1.05], '--', 'Color', P.gris);
    text(ax, Rco.fDom/100 + 0.005, 0.1, sprintf('motor: f/f_s = %.3f', Rco.fDom/100), 'Color', P.fg);
    ylim(ax, [0 1.05]);
    estilo(ax, P, 'Amplitud que conserva cada derivada numérica (1 = exacta)', 'f / f_s', '|D_{num}| / |D_{exacta}|');
    leyenda(ax, P, {'Adelante/atrás', 'Centrada', '5 puntos'}, 'southwest');
    guardar(f, carpeta, 'f09_factor_derivadas');

    % F10 Manejo: velocidad con y sin corrección de drift
    f = nueva(P, [950 400]); ax = axes(f); hold(ax, 'on');
    plot(ax, Rma0.t, 3.6*Rma0.v, 'Color', P.c{1}, 'LineWidth', 1.3);
    plot(ax, Rma1.t, 3.6*Rma1.v, 'Color', P.c{2}, 'LineWidth', 1.3);
    estilo(ax, P, 'Manejo (eje x del teléfono): velocidad por RK4', 't [s]', 'v [km/h]');
    leyenda(ax, P, {'Sin corrección', 'Sesgo constante (MC grado 0)'}, 'northwest');
    guardar(f, carpeta, 'f10_manejo_velocidad');

    % F11 Tendencia por mínimos cuadrados (grados 1-3) sobre el manejo
    f = nueva(P, [950 400]); ax = axes(f); hold(ax, 'on');
    % Se grafica la media móvil de 1 s (la vibración cruda tapa las tendencias)
    mm = conv(RmaA.y, ones(100,1)/100, 'same');
    plot(ax, RmaA.t, mm, 'Color', P.gris, 'LineWidth', 1);
    eq = cell(1, 3);
    for g = 1:3
        rg = nm_minimos_cuadrados(RmaA.t, RmaA.y, g);
        plot(ax, RmaA.t, rg.yfit, 'Color', P.c{g}, 'LineWidth', 2.2);
        eq{g} = sprintf('Grado %d (R^2 = %.4f)', g, rg.R2);
    end
    plot(ax, [RmaA.t(1) RmaA.t(end)], [0 0], ':', 'Color', P.fg);
    ylim(ax, [-1 1]);
    estilo(ax, P, 'Tendencias por mínimos cuadrados: sesgo y deriva del sensor (manejo, eje x)', 't [s]', 'a [m/s^2]');
    leyenda(ax, P, [{'Señal (media móvil 1 s)'}, eq, {'a = 0'}], 'northeast');
    guardar(f, carpeta, 'f11_tendencia_mc');
end
fprintf('Listo: %d figuras por tema.\n', 11);

% ======================= Funciones locales =======================
function P = paleta(tema)
if strcmp(tema, 'claro')
    P.bg = [1 1 1]; P.fg = [0.15 0.15 0.15]; P.grid = [0.15 0.15 0.15]; P.gris = [0.55 0.55 0.55];
    P.c = {[0 0.447 0.741], [0.85 0.325 0.098], [0.466 0.674 0.188], [0.494 0.184 0.556]};
    P.rojo = [0.80 0.10 0.10];
else
    P.bg = [0.10 0.11 0.13]; P.fg = [0.92 0.92 0.92]; P.grid = [0.85 0.85 0.85]; P.gris = [0.60 0.60 0.62];
    P.c = {[0.35 0.65 1.00], [1.00 0.60 0.25], [0.55 0.85 0.35], [0.80 0.55 1.00]};
    P.rojo = [1.00 0.35 0.35];
end
end

function f = nueva(P, tam)
f = figure('Visible', 'off', 'Color', P.bg, 'Position', [50 50 tam], 'InvertHardcopy', 'off');
end

function estilo(ax, P, titulo, xl, yl)
set(ax, 'Color', P.bg, 'XColor', P.fg, 'YColor', P.fg, 'GridColor', P.grid, ...
    'GridAlpha', 0.15, 'FontSize', 11, 'Box', 'on');
grid(ax, 'on');
title(ax, titulo, 'Color', P.fg, 'FontWeight', 'bold');
xlabel(ax, xl, 'Color', P.fg); ylabel(ax, yl, 'Color', P.fg);
end

function leyenda(ax, P, nombres, pos)
if nargin < 4, pos = 'northeast'; end
legend(ax, nombres, 'Location', pos, 'TextColor', P.fg, 'Color', P.bg, 'EdgeColor', P.gris);
end

function guardar(f, carpeta, nombre)
archivo = fullfile(carpeta, [nombre '.png']);
if exist('exportgraphics', 'file') || exist('exportgraphics', 'builtin')
    exportgraphics(f, archivo, 'Resolution', 200, 'BackgroundColor', 'current');
else
    print(f, archivo, '-dpng', '-r200');
end
close(f);
fprintf('   %s\n', [nombre '.png']);
end

function [tc, fv] = frec_ventanas(t, y, W)
% Frecuencia dominante (>5 Hz) en ventanas de W segundos con ventana de Hann
h = t(2) - t(1); n = round(W / h);
k0 = 1:n:numel(y) - n + 1;
tc = zeros(numel(k0), 1); fv = tc;
w = 0.5 - 0.5*cos(2*pi*(0:n-1)'/(n-1));
for i = 1:numel(k0)
    s = y(k0(i):k0(i)+n-1); s = (s - mean(s)) .* w;
    A = abs(fft(s)); A = A(1:floor(n/2)+1);
    fr = (0:floor(n/2))' / (n*h);
    A(fr < 5) = 0;
    [~, j] = max(A);
    fv(i) = fr(j); tc(i) = t(k0(i)) + W/2;
end
end
