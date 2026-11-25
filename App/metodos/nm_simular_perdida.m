function [t2, y2, P] = nm_simular_perdida(t, y, porcentaje, semilla)
% NM_SIMULAR_PERDIDA  Elimina a propósito un porcentaje de muestras de una
% señal REAL para poder medir el error de interpolación (se conoce el
% valor verdadero de cada muestra eliminada).
%   La pérdida se genera en ráfagas de 1 a 5 muestras (como ocurre con un
%   sensor real cuando el sistema operativo se ocupa): la mitad de las
%   ráfagas se marca como NaN y la otra mitad se elimina (hueco temporal).
%   P.tRem, P.yRem  tiempos y valores verdaderos de las muestras perdidas
if nargin < 4 || isempty(semilla), semilla = 1; end
t = t(:); y = y(:); n = numel(t);
t2 = t; y2 = y;
P.tRem = zeros(0,1); P.yRem = zeros(0,1); P.porcentaje = porcentaje;
if porcentaje <= 0 || n < 20, return; end
rng(semilla);
objetivo = round(porcentaje/100 * n);
marcado = false(n,1);
tipoNaN = false(n,1);
intentos = 0;
while sum(marcado) < objetivo && intentos < 10*n
    intentos = intentos + 1;
    L  = randi(5);                          % largo de la ráfaga
    i0 = randi([3, n - L - 2]);             % nunca en los extremos
    idx = i0:i0+L-1;
    if any(marcado(max(1,i0-2):min(n,i0+L+1))), continue; end   % ráfagas separadas
    marcado(idx) = true;
    tipoNaN(idx) = rand < 0.5;
end
ok = ~isnan(y) & marcado;                   % solo se evalúan muestras con valor
P.tRem = t(ok); P.yRem = y(ok);
y2(marcado & tipoNaN) = NaN;
quitar = marcado & ~tipoNaN;
t2(quitar) = []; y2(quitar) = [];
P.nNaN = sum(marcado & tipoNaN); P.nQuitadas = sum(quitar);
end
