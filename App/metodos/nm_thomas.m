function x = nm_thomas(a, b, c, d)
% NM_THOMAS  Resuelve un sistema tridiagonal A x = d  (algoritmo de Thomas).
%   a: subdiagonal (a(1) no se usa), b: diagonal, c: superdiagonal
%   (c(end) no se usa), d: lado derecho. Costo O(n).
n = numel(d);
a = a(:); b = b(:); c = c(:); d = d(:);
for i = 2:n
    w = a(i) / b(i-1);
    b(i) = b(i) - w * c(i-1);
    d(i) = d(i) - w * d(i-1);
end
x = zeros(n,1);
x(n) = d(n) / b(n);
for i = n-1:-1:1
    x(i) = (d(i) - c(i) * x(i+1)) / b(i);
end
end
