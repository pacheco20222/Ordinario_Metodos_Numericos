function [I, Iacum] = nm_integral(y, h, metodo)
% NM_INTEGRAL  Integral definida y acumulada de una señal uniforme.
%   metodo:
%     'trapecio'   I = h/2 [f0 + 2Σf_i + fn]                       O(h^2)
%     'simpson13'  I = h/3 [f0 + 4Σf_impar + 2Σf_par + fn]         O(h^4)
%                  (si el número de intervalos es impar, los 3 últimos
%                   intervalos se integran con Simpson 3/8)
%     'simpson38'  I = 3h/8 [f0 + 3f1 + 3f2 + 2f3 + ...]           O(h^4)
%                  (el residuo de 1 o 2 intervalos se cubre con
%                   Simpson 1/3, manteniendo O(h^4))
%   Iacum(k) = ∫_{t1}^{tk} y dt  (acumulada, misma longitud que y)
y = y(:); n = numel(y); m = n - 1;   % m = número de intervalos
if n < 2, I = 0; Iacum = zeros(n,1); return; end
switch lower(metodo)
    case 'trapecio'
        seg = h/2 * (y(1:m) + y(2:n));
    case 'simpson13'
        seg = segmentos_parabolicos(y, h);
    case 'simpson38'
        seg = segmentos_cubicos(y, h);
    otherwise
        error('nm_integral:metodo', 'Método desconocido: %s', metodo);
end
Iacum = [0; cumsum(seg)];
switch lower(metodo)
    case 'trapecio'
        I = Iacum(end);
    case 'simpson13'
        I = simpson13_total(y, h);
    case 'simpson38'
        I = simpson38_total(y, h);
end
end

% ---------- Integral total con las fórmulas compuestas clásicas ----------
function I = simpson13_total(y, h)
n = numel(y); m = n - 1;
if m == 1, I = h/2*(y(1)+y(2)); return; end
if mod(m,2) == 0
    I = h/3 * (y(1) + 4*sum(y(2:2:n-1)) + 2*sum(y(3:2:n-2)) + y(n));
else
    if m == 3, I = 3*h/8*(y(1)+3*y(2)+3*y(3)+y(4)); return; end
    k = n - 3;   % Simpson 1/3 en [1,k], Simpson 3/8 en [k,n]
    I = h/3 * (y(1) + 4*sum(y(2:2:k-1)) + 2*sum(y(3:2:k-2)) + y(k)) + ...
        3*h/8 * (y(k) + 3*y(k+1) + 3*y(k+2) + y(k+3));
end
end

function I = simpson38_total(y, h)
n = numel(y); m = n - 1;
r = mod(m, 3);
q = m - r;              % intervalos cubiertos con 3/8
if r == 1 && q >= 3
    q = q - 3;          % residuo de 4 intervalos -> 2 x Simpson 1/3 (O(h^4))
    r = 4;
end
I = 0;
if q >= 3
    idx = 1:3:q-2;      % inicio de cada bloque de 3 intervalos
    I = 3*h/8 * sum(y(idx) + 3*y(idx+1) + 3*y(idx+2) + y(idx+3));
end
k = q + 1;              % primer nodo del residuo
switch r
    case 1              % solo hay 1 intervalo en total
        I = I + h/2*(y(n-1) + y(n));
    case 2
        I = I + h/3*(y(k) + 4*y(k+1) + y(k+2));
    case 4
        I = I + h/3*(y(k) + 4*y(k+1) + 2*y(k+2) + 4*y(k+3) + y(k+4));
end
end

% ---------- Segmentos para la integral acumulada ----------
function seg = segmentos_parabolicos(y, h)
% Integral de cada intervalo [x_k, x_k+1] con la parábola que pasa por
% 3 nodos vecinos. Dos intervalos consecutivos suman exactamente la regla
% de Simpson 1/3: h/12(5f0+8f1-f2) + h/12(-f0+8f1+5f2) = h/3(f0+4f1+f2).
n = numel(y); m = n - 1; seg = zeros(m,1);
if n < 3, seg = h/2*(y(1:m)+y(2:n)); return; end
for k = 1:m
    if mod(k,2) == 1 && k+2 <= n          % primer intervalo del par
        seg(k) = h/12 * (5*y(k) + 8*y(k+1) - y(k+2));
    else                                  % segundo intervalo del par
        seg(k) = h/12 * (-y(k-1) + 8*y(k) + 5*y(k+1));
    end
end
end

function seg = segmentos_cubicos(y, h)
% Integral de cada intervalo con el polinomio cúbico por 4 nodos;
% tres intervalos consecutivos suman la regla de Simpson 3/8.
n = numel(y); m = n - 1; seg = zeros(m,1);
if n < 4, seg = segmentos_parabolicos(y, h); return; end
for k = 1:m
    p = mod(k-1, 3);                      % posición dentro del bloque
    b = k - p;                            % primer nodo del bloque
    if b + 3 > n, b = n - 3; p = k - b; end
    f = y(b:b+3);
    switch p
        case 0, w = [9 19 -5 1];
        case 1, w = [-1 13 13 -1];
        otherwise, w = [1 -5 19 9];
    end
    seg(k) = h/24 * (w * f);
end
end
