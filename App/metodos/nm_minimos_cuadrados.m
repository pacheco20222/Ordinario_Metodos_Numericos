function r = nm_minimos_cuadrados(t, y, grado)
% NM_MINIMOS_CUADRADOS  Ajuste polinomial por mínimos cuadrados.
%   Minimiza S = Σ (y_i - p(t_i))^2 resolviendo las ecuaciones normales
%       (Z' Z) a = Z' y ,   Z = [1  s  s^2 ... s^g]
%   con la variable escalada s = (t - mu)/sigma para evitar el mal
%   condicionamiento de la matriz de Vandermonde. El sistema se resuelve
%   con eliminación gaussiana con pivoteo parcial (nm_gauss_pivoteo).
%   r.a      coeficientes en s (a0, a1, ..., ag)
%   r.p      coeficientes en t, orden descendente (compatible con polyval)
%   r.yfit   valores ajustados,  r.R2  coeficiente de determinación
%   Grado 0 = media (sesgo constante).
%   r.Syx    error estándar de la estimación, r.cond  número de condición
t = t(:); y = y(:);
ok = ~isnan(y) & ~isnan(t);
t = t(ok); y = y(ok);
n = numel(t);
if n <= grado
    error('nm_minimos_cuadrados:datos', 'Se requieren más de %d puntos.', grado);
end
mu = mean(t); sg = std(t); if sg == 0, sg = 1; end
s = (t - mu) / sg;
Z = ones(n, grado+1);
for j = 2:grado+1
    Z(:,j) = Z(:,j-1) .* s;
end
N = Z' * Z;
a = nm_gauss_pivoteo(N, Z' * y);
yfit = Z * a;
St = sum((y - mean(y)).^2);
Sr = sum((y - yfit).^2);
r.a    = a;
r.mu   = mu;
r.sigma = sg;
r.grado = grado;
r.yfit = yfit;
r.t    = t;
r.R2   = 1 - Sr / max(St, eps);
r.Syx  = sqrt(Sr / max(n - (grado+1), 1));
r.cond = cond(N);
r.p    = coef_en_t(a, mu, sg);
end

function p = coef_en_t(a, mu, sg)
% Convierte p(s), s=(t-mu)/sg, a coeficientes en t (orden descendente)
g = numel(a) - 1;
p = zeros(1, g+1);          % ascendente temporal
base = 1;                   % polinomio ((t-mu)/sg)^j en t, ascendente
for j = 0:g
    if j > 0
        base = conv(base, [-mu/sg, 1/sg]);
    end
    p(1:numel(base)) = p(1:numel(base)) + a(j+1) * base;
end
p = fliplr(p);
end
