function info = nm_duracion(t)
% NM_DURACION  Duración total y parámetros de muestreo de una señal.
%   info = nm_duracion(t) devuelve una estructura con:
%     .T      duración total  T = t(end) - t(1)            [s]
%     .N      número de muestras
%     .dt     paso de muestreo nominal (mediana de diff(t)) [s]
%     .fs     frecuencia de muestreo nominal 1/dt           [Hz]
%     .dtStd  desviación estándar de diff(t) (jitter)       [s]
t = t(:);
t = t(~isnan(t));
if numel(t) < 2
    error('nm_duracion:datos', 'Se requieren al menos 2 instantes de tiempo.');
end
d = diff(t);
info.T     = t(end) - t(1);
info.N     = numel(t);
info.dt    = median(d);
info.fs    = 1 / info.dt;
info.dtStd = std(d);
end
