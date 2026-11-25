function x = nm_gauss_pivoteo(A, b)
% NM_GAUSS_PIVOTEO  Eliminación gaussiana con pivoteo parcial y
% sustitución hacia atrás. Resuelve A x = b.
n = size(A,1);
Ab = [A b(:)];
for k = 1:n-1
    [~, p] = max(abs(Ab(k:n, k)));
    p = p + k - 1;
    if Ab(p,k) == 0
        error('nm_gauss_pivoteo:singular', 'Matriz singular.');
    end
    if p ~= k
        Ab([k p], :) = Ab([p k], :);
    end
    for i = k+1:n
        f = Ab(i,k) / Ab(k,k);
        Ab(i,k:end) = Ab(i,k:end) - f * Ab(k,k:end);
    end
end
x = zeros(n,1);
for i = n:-1:1
    suma = 0;
    for j = i+1:n
        suma = suma + Ab(i,j) * x(j);
    end
    x(i) = (Ab(i,end) - suma) / Ab(i,i);
end
end
