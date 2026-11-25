function [v, x] = nm_edo_movimiento(t, a, metodo, v0, x0)
% NM_EDO_MOVIMIENTO  Integra la cinemática a partir de la aceleración
% medida resolviendo el sistema de EDOs de primer orden:
%       dx/dt = v ,   dv/dt = a(t) ,   x(t0)=x0, v(t0)=v0
%   metodo: 'euler' | 'heun' (RK2) | 'rk4'
%   a(t) en puntos intermedios (t + h/2) se obtiene con interpolación
%   cúbica local de Newton (4 nodos).
if nargin < 4 || isempty(v0), v0 = 0; end
if nargin < 5 || isempty(x0), x0 = 0; end
t = t(:); a = a(:); n = numel(t);
v = zeros(n,1); x = zeros(n,1);
v(1) = v0; x(1) = x0;
metodo = lower(metodo);
if strcmp(metodo, 'rk4')
    tm = t(1:n-1) + diff(t)/2;
    am = nm_lagrange_local(t, a, tm, 4);     % a(t + h/2)
end
for k = 1:n-1
    h = t(k+1) - t(k);
    switch metodo
        case 'euler'
            x(k+1) = x(k) + h * v(k);
            v(k+1) = v(k) + h * a(k);
        case 'heun'
            % predictor
            vp = v(k) + h * a(k);
            % corrector (promedio de pendientes)
            v(k+1) = v(k) + h/2 * (a(k) + a(k+1));
            x(k+1) = x(k) + h/2 * (v(k) + vp);
        case 'rk4'
            % f(t,[x;v]) = [v; a(t)]
            k1x = v(k);              k1v = a(k);
            k2x = v(k) + h/2*k1v;    k2v = am(k);
            k3x = v(k) + h/2*k2v;    k3v = am(k);
            k4x = v(k) + h*k3v;      k4v = a(k+1);
            x(k+1) = x(k) + h/6*(k1x + 2*k2x + 2*k3x + k4x);
            v(k+1) = v(k) + h/6*(k1v + 2*k2v + 2*k3v + k4v);
        otherwise
            error('nm_edo_movimiento:metodo', 'Método desconocido: %s', metodo);
    end
end
end
