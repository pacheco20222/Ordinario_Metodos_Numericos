function yq = nm_spline_natural(x, y, xq)
% NM_SPLINE_NATURAL  Trazador (spline) cúbico natural, S''(x1)=S''(xn)=0.
%   Resuelve el sistema tridiagonal para los momentos M_i = S''(x_i)
%   con el algoritmo de Thomas y evalúa por tramos.
x = x(:); y = y(:); xq = xq(:);
n = numel(x);
h = diff(x);
if n < 3
    yq = interp1(x, y, xq, 'linear', 'extrap');
    return
end
% Sistema para M(2..n-1)
a = [0; h(2:end-1)];                 % subdiagonal
b = 2 * (h(1:end-1) + h(2:end));     % diagonal
c = [h(2:end-1); 0];                 % superdiagonal
d = 6 * ( (y(3:end) - y(2:end-1)) ./ h(2:end) - ...
          (y(2:end-1) - y(1:end-2)) ./ h(1:end-1) );
M = [0; nm_thomas(a, b, c, d); 0];
% Localizar tramo de cada xq
k = discretize_local(x, xq);
hk = h(k);
A = (x(k+1) - xq) ./ hk;
B = (xq - x(k)) ./ hk;
yq = A .* y(k) + B .* y(k+1) + ...
     ((A.^3 - A) .* M(k) + (B.^3 - B) .* M(k+1)) .* (hk.^2) / 6;
end

function k = discretize_local(x, xq)
% índice k tal que x(k) <= xq < x(k+1), acotado a 1..n-1 (vectorizado)
n = numel(x);
k = floor(interp1(x, (1:n)', xq, 'linear', 'extrap'));
k = max(1, min(k, n-1));
end
