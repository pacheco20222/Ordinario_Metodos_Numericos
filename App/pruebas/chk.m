function chk(cond, msg)
% CHK  Imprime [OK] o [FALLA] para una condición de prueba.
if cond, fprintf('  [OK]   %s\n', msg); else, fprintf('  [FALLA] %s\n', msg); end
end
