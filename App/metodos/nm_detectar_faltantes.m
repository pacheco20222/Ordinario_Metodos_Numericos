function r = nm_detectar_faltantes(t, y, factorHueco, usarAtipicos, kMAD)
% NM_DETECTAR_FALTANTES  Detecta datos faltantes en una señal muestreada.
%   Tres tipos de faltante:
%     1) NaN en y (muestra perdida/corrupta)
%     2) Huecos en el tiempo: diff(t) > factorHueco * mediana(diff(t))
%     3) (opcional) Valores atípicos por filtro de Hampel LOCAL:
%        |y_i - mediana_local| > kMAD * 1.4826 * MAD_local  (ventana ±25)
%        Un criterio global marcaría como atípicos los baches reales del
%        camino (señal no estacionaria); el local solo marca picos aislados.
%   r.malla   malla temporal uniforme t0:dt:tf (dt = mediana)
%   r.esFaltante  vector lógico sobre r.malla (true = hay que interpolar)
%   r.tValido, r.yValido  muestras confiables originales
%   r.nNaN, r.nHuecos, r.nAtipicos, r.nFaltantes  conteos
%   r.huecos  matriz [t_inicio t_fin] de cada hueco temporal
if nargin < 3 || isempty(factorHueco), factorHueco = 1.5; end
if nargin < 4 || isempty(usarAtipicos), usarAtipicos = false; end
if nargin < 5 || isempty(kMAD), kMAD = 5; end
t = t(:); y = y(:);

% Ordenar por tiempo y eliminar tiempos repetidos
[t, idx] = sort(t); y = y(idx);
[t, iu] = unique(t); y = y(iu);

esNaN = isnan(y);
esAtip = false(size(y));
if usarAtipicos
    esAtip = nm_hampel(y, 25, kMAD);       % ventana de ±25 muestras
end
ok = ~esNaN & ~esAtip;
tV = t(ok); yV = y(ok);

d  = diff(t);
dt = median(d);
iH = find(d > factorHueco * dt);
huecos = [t(iH) t(iH+1)];

% Malla uniforme que cubre toda la señal
n  = round((t(end) - t(1)) / dt);
malla = t(1) + (0:n)' * dt;

% Un punto de la malla es "faltante" si no hay una muestra válida
% a menos de dt/2 de él
pos = interp1(tV, (1:numel(tV))', malla, 'nearest', 'extrap');
distancia = abs(malla - tV(pos));
esFalt = distancia > dt/2;

r.malla      = malla;
r.dt         = dt;
r.esFaltante = esFalt;
r.tValido    = tV;
r.yValido    = yV;
r.nNaN       = sum(esNaN);
r.nAtipicos  = sum(esAtip);
r.nHuecos    = numel(iH);
r.huecos     = huecos;
r.nFaltantes = sum(esFalt);
r.idxNaN     = find(esNaN);
r.idxAtipico = find(esAtip);
r.tOrdenado  = t;
r.yOrdenado  = y;
end
