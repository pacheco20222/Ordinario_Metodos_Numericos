function yq = nm_evaluar_tendencia(r, tq)
% NM_EVALUAR_TENDENCIA  Evalúa el polinomio de mínimos cuadrados en tq
% (con la variable escalada, numéricamente estable). Horner.
s = (tq(:) - r.mu) / r.sigma;
yq = r.a(end) * ones(size(s));
for j = numel(r.a)-1:-1:1
    yq = yq .* s + r.a(j);
end
end
