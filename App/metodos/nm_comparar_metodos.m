function C = nm_comparar_metodos(t, y, op, ref)
% NM_COMPARAR_METODOS  Ejecuta TODOS los métodos de cada proceso sobre la
% misma señal y los compara contra:
%   (a) la función interna de MATLAB equivalente (validación), y
%   (b) la solución analítica, si se proporciona en ref (señal de prueba).
%   Con señal real y pérdida simulada (op.pPerdida > 0), la columna de
%   error de interpolación es el RMSE contra las muestras verdaderas.
%   Si no hay faltantes ni pérdida, se simula un 5 % automáticamente.
%   C es un cell array {Proceso, Método, Resultado, ErrorAnalítico, DifMATLAB}
if nargin < 3, op = struct(); end
if nargin < 4, ref = []; end
hayRef = ~isempty(ref);
C = {};
base = nm_procesar(t, y, op);
tm = base.t; h = base.h; fa = base.esFaltante;
tv = base.falt.tValido; yv = base.falt.yValido;
if hayRef
    aR  = interp1(ref.tRef, ref.aRef,  tm);
    daR = interp1(ref.tRef, ref.daRef, tm);
    vR  = interp1(ref.tRef, ref.vRef,  tm);
    xR  = interp1(ref.tRef, ref.xRef,  tm);
end

% --- Interpolación ---
% Si la señal no tiene faltantes (caso típico de datos reales) se elimina
% automáticamente el 5 % de las muestras para poder evaluar los métodos.
mI = {'lineal','lagrange','spline'}; mM = {'linear','','spline'};
nombresI = {'Lineal','Newton local (cúbico)','Spline cúbico natural'};
if any(fa) || base.op.pPerdida > 0
    bI = base;
else
    opP = base.op; opP.pPerdida = 5;
    bI = nm_procesar(t, y, opP);
end
faI = bI.esFaltante; tvI = bI.falt.tValido; yvI = bI.falt.yValido; tmI = bI.t;
P = bI.perdida;
for i = 1:3
    eA = NaN; dM = NaN;
    if hayRef && any(faI)
        % señal de prueba: error contra la solución analítica en los faltantes
        yi = nm_interpolar(t, y, mI{i}, struct('factorHueco', base.op.factorHueco, ...
             'usarAtipicos', base.op.usarAtipicos, 'gradoLagrange', base.op.gradoLagrange));
        aRi = interp1(ref.tRef, ref.aRef, tmI);
        eA = max(abs(yi(faI) - aRi(faI)));
        if ~isempty(mM{i})
            ym = interp1(tvI, yvI, tmI, mM{i});
            dM = max(abs(yi(faI) - ym(faI)));
        end
        txt = sprintf('%d pts', sum(faI));
    elseif ~isempty(P.tRem)
        % señal real: RMSE contra los valores verdaderos eliminados
        ye = nm_evaluar_interp(tvI, yvI, P.tRem, mI{i}, base.op.gradoLagrange);
        eA = sqrt(mean((ye - P.yRem).^2));
        if ~isempty(mM{i})
            ym = interp1(tvI, yvI, P.tRem, mM{i});
            dM = max(abs(ye - ym));
        end
        txt = sprintf('%d pts (%g %% simulado)', numel(P.tRem), P.porcentaje);
    else
        txt = '0 pts';
    end
    C(end+1,:) = {'Interpolación', nombresI{i}, txt, eA, dM}; %#ok<AGROW>
end

% --- Derivada --- (referencia MATLAB: gradient, diferencias centradas)
mD = {'adelante','atras','centrada','cinco'};
nD = {'Adelante O(h)','Atrás O(h)','Centrada O(h^2)','5 puntos O(h^4)'};
g = gradient(base.y, h);
for i = 1:4
    d = nm_derivada(base.y, h, mD{i});
    eA = NaN; if hayRef, eA = max(abs(d(3:end-2) - daR(3:end-2))); end
    C(end+1,:) = {'Derivada', nD{i}, sprintf('max|dy|=%.4g', max(abs(d))), eA, max(abs(d(3:end-2)-g(3:end-2)))}; %#ok<AGROW>
end

% --- Integral --- (referencia MATLAB: trapz)
mJ = {'trapecio','simpson13','simpson38'};
nJ = {'Trapecio O(h^2)','Simpson 1/3 O(h^4)','Simpson 3/8 O(h^4)'};
Iz = trapz(tm, base.y);
for i = 1:3
    I = nm_integral(base.y, h, mJ{i});
    eA = NaN; if hayRef, eA = abs(I - vR(end)); end
    C(end+1,:) = {'Integral', nJ{i}, sprintf('%.6f', I), eA, abs(I - Iz)}; %#ok<AGROW>
end

% --- EDO --- (referencia MATLAB: cumtrapz doble)
mE = {'euler','heun','rk4'}; nE = {'Euler O(h)','Heun / RK2 O(h^2)','Runge-Kutta 4 O(h^4)'};
vz = cumtrapz(tm, base.y); xz = cumtrapz(tm, vz);
for i = 1:3
    [v, x] = nm_edo_movimiento(tm, base.y, mE{i});
    eA = NaN; if hayRef, eA = max(abs(x - xR)); end
    C(end+1,:) = {'EDO x(t)', nE{i}, sprintf('x(T)=%.5f', x(end)), eA, max(abs(x - xz))}; %#ok<AGROW>
end

% --- Mínimos cuadrados --- (referencia MATLAB: polyfit)
for gdo = 1:4
    r = nm_minimos_cuadrados(tm, base.y, gdo);
    [pp, ~, mu] = polyfit(tm, base.y, gdo);
    yf = polyval(pp, tm, [], mu);
    C(end+1,:) = {'Mínimos cuadrados', sprintf('Grado %d', gdo), sprintf('R^2=%.5f', r.R2), NaN, max(abs(r.yfit - yf))}; %#ok<AGROW>
end
end
