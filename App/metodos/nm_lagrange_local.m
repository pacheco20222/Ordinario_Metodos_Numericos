function yq = nm_lagrange_local(x, y, xq, m)
% NM_LAGRANGE_LOCAL  Interpolación polinomial de Newton (diferencias
% divididas) usando los m puntos válidos más cercanos a cada xq.
%   Se usa un polinomio LOCAL de grado m-1 (por defecto m=4, cúbico) para
%   evitar el fenómeno de Runge que aparece con un único polinomio global.
if nargin < 4 || isempty(m), m = 4; end
x = x(:); y = y(:); xq = xq(:);
n = numel(x);
m = min(m, n);
yq = zeros(size(xq));
% índice del primer nodo >= xq (vectorizado, x ordenado)
J = ceil(interp1(x, (1:n)', xq, 'linear', 'extrap'));
J = max(1, min(J, n));
for k = 1:numel(xq)
    j = J(k);
    i0 = j - floor(m/2);
    i0 = max(1, min(i0, n - m + 1));
    idx = i0:(i0 + m - 1);
    xs = x(idx); ys = y(idx);
    % Tabla de diferencias divididas (in situ)
    c = ys;
    for orden = 2:m
        for i = m:-1:orden
            c(i) = (c(i) - c(i-1)) / (xs(i) - xs(i-orden+1));
        end
    end
    % Evaluación con esquema de Horner
    p = c(m);
    for i = m-1:-1:1
        p = p .* (xq(k) - xs(i)) + c(i);
    end
    yq(k) = p;
end
end
