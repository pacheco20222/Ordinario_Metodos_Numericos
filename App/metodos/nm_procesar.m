function R = nm_procesar(t, y, op)
% NM_PROCESAR  Motor del programa: ejecuta toda la cadena numérica.
%   Datos crudos -> duración -> detección de faltantes -> interpolación
%   (malla uniforme) -> derivada -> integral -> tendencia por mínimos
%   cuadrados -> (opcional) corrección de drift -> EDO de movimiento.
%   La GUI solo llama a esta función y grafica; así el motor puede
%   probarse sin interfaz.
if nargin < 3, op = struct(); end
op = valores_por_defecto(op);

R.op = op;
% 0) (Opcional) pérdida simulada de datos para medir el error real de
%    interpolación sobre la señal medida
[t, y, R.perdida] = nm_simular_perdida(t, y, op.pPerdida, op.semilla);
R.tOrig = t(:); R.yOrig = y(:);
R.duracion = nm_duracion(t);

% 1) Faltantes + interpolación
opI = struct('factorHueco', op.factorHueco, 'usarAtipicos', op.usarAtipicos, ...
             'kMAD', op.kMAD, 'gradoLagrange', op.gradoLagrange);
[R.y, R.falt] = nm_interpolar(t, y, op.metodoInterp, opI);
R.t  = R.falt.malla;
R.h  = R.falt.dt;
R.esFaltante = R.falt.esFaltante;
if ~isempty(R.perdida.tRem)
    yEst = nm_evaluar_interp(R.falt.tValido, R.falt.yValido, R.perdida.tRem, ...
                             op.metodoInterp, op.gradoLagrange);
    e = yEst - R.perdida.yRem;
    R.perdida.yEst = yEst;
    R.perdida.rmse = sqrt(mean(e.^2));
    R.perdida.emax = max(abs(e));
else
    R.perdida.rmse = NaN; R.perdida.emax = NaN; R.perdida.yEst = [];
end

% 2) Derivada
R.dy = nm_derivada(R.y, R.h, op.metodoDerivada);

% 3) Tendencia por mínimos cuadrados (sobre la señal reconstruida)
R.tend = nm_minimos_cuadrados(R.t, R.y, op.gradoTendencia);
R.yTend = R.tend.yfit;

% 4) Corrección de deriva (drift) antes de integrar
%    'ninguna'   : se integra la señal tal cual
%    'sesgo'     : resta el sesgo constante = ajuste MC de grado 0 (la media).
%                  Garantiza v(T) ≈ v(0); válido si el sistema inicia y
%                  termina en reposo (p. ej. arranque-frenado del carro).
%    'tendencia' : resta la tendencia MC del grado seleccionado
%                  (sesgo + deriva térmica del sensor).
%    'reposo'    : resta la media de los primeros tReposo segundos, cuando
%                  se sabe que el sensor estaba quieto (calibración).
switch op.metodoDrift
    case 'ninguna'
        R.sesgo = zeros(size(R.y));
    case 'sesgo'
        r0 = nm_minimos_cuadrados(R.t, R.y, 0);
        R.sesgo = r0.yfit;
    case 'tendencia'
        R.sesgo = R.yTend;
    case 'reposo'
        idx = R.t <= R.t(1) + op.tReposo;
        if sum(idx) < 2, idx(1:min(2, end)) = true; end
        R.sesgo = mean(R.y(idx)) * ones(size(R.y));
    otherwise
        error('nm_procesar:drift', 'Corrección de drift desconocida: %s', op.metodoDrift);
end
R.yInt = R.y - R.sesgo;
[R.I, R.Iacum] = nm_integral(R.yInt, R.h, op.metodoIntegral);

% 5) EDO de movimiento: v y x a partir de a(t)
[R.v, R.x] = nm_edo_movimiento(R.t, R.yInt, op.metodoEDO, 0, 0);

% 6) Indicadores
R.pico    = max(abs(R.y));
R.rms     = sqrt(mean(R.y.^2));
R.dyMax   = max(abs(R.dy));
R.vFinal  = R.v(end);
R.xFinal  = R.x(end);
[R.fDom, R.fEsp, R.ampEsp] = espectro(R.y - mean(R.y), R.h, op.fMin);
end

function op = valores_por_defecto(op)
d = struct('metodoInterp','spline','gradoLagrange',3,'factorHueco',1.5, ...
           'usarAtipicos',false,'kMAD',5,'metodoDerivada','centrada', ...
           'metodoIntegral','simpson13','metodoEDO','rk4', ...
           'gradoTendencia',1,'metodoDrift','sesgo','tReposo',2, ...
           'pPerdida',0,'semilla',1,'fMin',5);
% Compatibilidad con la opción anterior (lógica)
if isfield(op, 'corregirDrift') && ~isfield(op, 'metodoDrift')
    if op.corregirDrift, op.metodoDrift = 'tendencia'; else, op.metodoDrift = 'ninguna'; end
end
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(op, f{i}) || isempty(op.(f{i})), op.(f{i}) = d.(f{i}); end
end
end

function [f, fr, A] = espectro(y, h, fMin)
% Espectro de amplitud de un lado (FFT) y frecuencia dominante buscada
% solo para f >= fMin (separa la vibración del motor del movimiento lento)
n = numel(y);
if n < 4, f = NaN; fr = 0; A = 0; return; end
Y = fft(y);
A = abs(Y(1:floor(n/2)+1)) / n;
A(2:end-1) = 2 * A(2:end-1);
fr = (0:floor(n/2))' / (n*h);
B = A; B(fr < max(fMin, eps)) = 0;
[~, k] = max(B);
f = fr(k);
end
