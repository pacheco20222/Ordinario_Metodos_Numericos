addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'metodos'));
D = nm_cargar_datos(fullfile(fileparts(mfilename('fullpath')), '..', 'datos', 'ejemplo_sintetico_phyphox.csv'));
fprintf('Cargado %s: N=%d, señales: %s\n', D.archivo, numel(D.t), strjoin(D.nombres, ' | '));
R = nm_procesar(D.t, D.Y(:,3), struct('metodoDrift','tendencia'));
fprintf('T=%.3f s fs=%.2f Hz | NaN=%d huecos=%d faltantes malla=%d\n', R.duracion.T, R.duracion.fs, R.falt.nNaN, R.falt.nHuecos, R.falt.nFaltantes);
fprintf('Integral=%.4f  v(T)=%.4f  x(T)=%.4f  jerk máx=%.3f  fDom=%.2f Hz  R2=%.4f\n', R.I, R.vFinal, R.xFinal, R.dyMax, R.fDom, R.tend.R2);
R2 = nm_procesar(D.t, D.Y(:,3), struct('metodoDrift', 'ninguna'));
fprintf('SIN corrección de drift: v(T)=%.4f  x(T)=%.4f\n', R2.vFinal, R2.xFinal);
s = nm_senal_prueba(10,100,0.03);
C = nm_comparar_metodos(s.t, s.a, struct('metodoDrift','ninguna'), s);
fprintf('\n%-18s %-24s %-16s %-12s %-12s\n','Proceso','Método','Resultado','Err analít','Dif MATLAB');
for i=1:size(C,1), fprintf('%-18s %-24s %-16s %-12.3e %-12.3e\n', C{i,:}); end

fprintf('\nCorrecciones de drift (eje z del ejemplo):\n');
for m = {'ninguna','sesgo','tendencia','reposo'}
  Rm = nm_procesar(D.t, D.Y(:,3), struct('metodoDrift', m{1}));
  fprintf('  %-10s v(T)=%9.4f m/s  x(T)=%9.4f m\n', m{1}, Rm.vFinal, Rm.xFinal);
end
r0 = nm_minimos_cuadrados((0:9)', (1:10)', 0); chk(abs(r0.p - 5.5) < 1e-12, 'MC grado 0 = media');
fprintf('Frecuencia dominante ejemplo: %.2f Hz\n', R.fDom);

fprintf('\nPérdida simulada del 5 %% en datos "reales" (eje z), error contra valores verdaderos:\n');
for m = {'lineal','lagrange','spline'}
  Rp = nm_procesar(D.t, D.Y(:,3), struct('pPerdida', 5, 'metodoInterp', m{1}));
  fprintf('  %-9s RMSE=%.4f  emax=%.4f  (%d muestras evaluadas)\n', m{1}, Rp.perdida.rmse, Rp.perdida.emax, numel(Rp.perdida.tRem));
end
chk(Rp.perdida.rmse < 0.5, 'error de interpolación con pérdida simulada calculado');
