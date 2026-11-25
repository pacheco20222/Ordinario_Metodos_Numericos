function [yu, r] = nm_interpolar(t, y, metodo, opciones)
% NM_INTERPOLAR  Detecta faltantes y reconstruye la señal sobre una malla
% uniforme con el método elegido.
%   metodo: 'lineal' | 'lagrange' (Newton local cúbico) | 'spline' (natural)
%   opciones (struct, opcional): .factorHueco, .usarAtipicos, .kMAD, .gradoLagrange
%   yu : señal reconstruida sobre r.malla
%   r  : resultado de nm_detectar_faltantes (+ r.metodo)
if nargin < 3 || isempty(metodo), metodo = 'spline'; end
if nargin < 4, opciones = struct(); end
fh = campo(opciones, 'factorHueco', 1.5);
ua = campo(opciones, 'usarAtipicos', false);
km = campo(opciones, 'kMAD', 5);
gl = campo(opciones, 'gradoLagrange', 3);

r = nm_detectar_faltantes(t, y, fh, ua, km);
x  = r.tValido; v = r.yValido; xq = r.malla;
yu = nm_evaluar_interp(x, v, xq, metodo, gl);
r.metodo = metodo;
end

function v = campo(s, nombre, def)
if isfield(s, nombre) && ~isempty(s.(nombre)), v = s.(nombre); else, v = def; end
end
