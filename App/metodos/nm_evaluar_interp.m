function yq = nm_evaluar_interp(x, y, xq, metodo, gradoLagrange)
% NM_EVALUAR_INTERP  Evalúa el interpolante elegido en puntos arbitrarios xq.
%   metodo: 'lineal' | 'lagrange' (Newton local de grado gradoLagrange) | 'spline'
if nargin < 5 || isempty(gradoLagrange), gradoLagrange = 3; end
x = x(:); y = y(:); xq = xq(:);
switch lower(metodo)
    case 'lineal'
        n = numel(x);
        k = floor(interp1(x, (1:n)', xq, 'linear', 'extrap'));
        k = max(1, min(k, n-1));
        w = (xq - x(k)) ./ (x(k+1) - x(k));
        yq = (1 - w) .* y(k) + w .* y(k+1);
    case 'lagrange'
        yq = nm_lagrange_local(x, y, xq, gradoLagrange + 1);
    case 'spline'
        yq = nm_spline_natural(x, y, xq);
    otherwise
        error('nm_evaluar_interp:metodo', 'Método desconocido: %s', metodo);
end
end
