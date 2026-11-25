function dy = nm_derivada(y, h, metodo)
% NM_DERIVADA  Derivada numérica de una señal uniformemente muestreada.
%   metodo:
%     'adelante'  f'(x) ≈ [f(x+h) - f(x)]/h                  O(h)
%     'atras'     f'(x) ≈ [f(x) - f(x-h)]/h                  O(h)
%     'centrada'  f'(x) ≈ [f(x+h) - f(x-h)]/(2h)             O(h^2)
%     'cinco'     f'(x) ≈ [-f(x+2h)+8f(x+h)-8f(x-h)+f(x-2h)]/(12h)  O(h^4)
%   En los extremos se usan fórmulas unilaterales del orden adecuado.
y = y(:); n = numel(y);
dy = zeros(n,1);
if n < 2, return; end
switch lower(metodo)
    case 'adelante'
        dy(1:n-1) = (y(2:n) - y(1:n-1)) / h;
        dy(n) = (y(n) - y(n-1)) / h;                     % atrás en el último
    case 'atras'
        dy(2:n) = (y(2:n) - y(1:n-1)) / h;
        dy(1) = (y(2) - y(1)) / h;                       % adelante en el primero
    case 'centrada'
        if n < 3, dy(:) = (y(2)-y(1))/h; return; end
        dy(2:n-1) = (y(3:n) - y(1:n-2)) / (2*h);
        dy(1) = (-3*y(1) + 4*y(2) - y(3)) / (2*h);       % O(h^2) unilateral
        dy(n) = ( 3*y(n) - 4*y(n-1) + y(n-2)) / (2*h);
    case 'cinco'
        if n < 5, dy = nm_derivada(y, h, 'centrada'); return; end
        i = 3:n-2;
        dy(i) = (-y(i+2) + 8*y(i+1) - 8*y(i-1) + y(i-2)) / (12*h);
        % Extremos: fórmulas unilaterales de 5 puntos O(h^4)
        dy(1) = (-25*y(1) + 48*y(2) - 36*y(3) + 16*y(4) - 3*y(5)) / (12*h);
        dy(2) = (-3*y(1) - 10*y(2) + 18*y(3) - 6*y(4) + y(5)) / (12*h);
        dy(n)   = ( 25*y(n) - 48*y(n-1) + 36*y(n-2) - 16*y(n-3) + 3*y(n-4)) / (12*h);
        dy(n-1) = ( 3*y(n) + 10*y(n-1) - 18*y(n-2) + 6*y(n-3) - y(n-4)) / (12*h);
    otherwise
        error('nm_derivada:metodo', 'Método desconocido: %s', metodo);
end
end
