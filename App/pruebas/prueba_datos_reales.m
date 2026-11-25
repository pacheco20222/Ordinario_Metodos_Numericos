% PRUEBA_DATOS_REALES  Analiza las mediciones reales (iPhone 15 Pro Max + phyphox)
raiz = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(raiz, 'metodos'));
archivos = {'motor_ralenti_cofre.csv', 'manejo_tablero.csv', 'motor_ralenti_cabina.csv'};
for a = 1:numel(archivos)
  D = nm_cargar_datos(fullfile(raiz, 'datos', archivos{a}));
  fprintf('\n=========== %s ===========\n', archivos{a});
  fprintf('Señales: %s\n', strjoin(D.nombres, ' | '));
  for e = 1:3
    R = nm_procesar(D.t, D.Y(:,e), struct('usarAtipicos', true));
    fprintf('Eje %d: T=%.2f s fs=%.1f Hz N=%d | NaN=%d huecos=%d atípicos=%d | fDom=%.2f Hz (%.0f rpm 4cil) | RMS=%.3f pico=%.3f | jerk máx=%.1f\n', ...
      e, R.duracion.T, R.duracion.fs, R.duracion.N, R.falt.nNaN, R.falt.nHuecos, R.falt.nAtipicos, R.fDom, 30*R.fDom, R.rms, R.pico, R.dyMax);
    if R.falt.nAtipicos > 0
      ia = R.falt.idxAtipico; fprintf('       atípicos en t = %s s\n', mat2str(R.falt.tOrdenado(ia)', 4));
    end
  end
  e = 3; if a == 2, e = 1; end
  fprintf('-- Eje %d: con y sin detección de atípicos, correcciones de drift (RK4):\n', e);
  for at = [false true]
    for m = {'ninguna','sesgo','tendencia'}
      R = nm_procesar(D.t, D.Y(:,e), struct('usarAtipicos', at, 'metodoDrift', m{1}));
      fprintf('   atípicos=%d %-10s v(T)=%8.4f  v máx=%7.3f m/s  x(T)=%9.3f m  pico=%.2f\n', at, m{1}, R.vFinal, max(abs(R.v)), R.xFinal, R.pico);
    end
  end
  fprintf('-- Pérdida simulada 5%% (eje %d), RMSE contra valor verdadero:\n', e);
  for m = {'lineal','lagrange','spline'}
    R = nm_procesar(D.t, D.Y(:,e), struct('pPerdida', 5, 'metodoInterp', m{1}, 'usarAtipicos', true));
    fprintf('   %-9s RMSE=%.4f  máx=%.4f  (%d pts)\n', m{1}, R.perdida.rmse, R.perdida.emax, numel(R.perdida.tRem));
  end
  fprintf('-- Integral (eje %d, sesgo, atípicos) por método:\n', e);
  for m = {'trapecio','simpson13','simpson38'}
    R = nm_procesar(D.t, D.Y(:,e), struct('metodoIntegral', m{1}, 'usarAtipicos', true));
    fprintf('   %-10s I=%.8f\n', m{1}, R.I);
  end
  tic; C = nm_comparar_metodos(D.t, D.Y(:,e), struct('usarAtipicos', true, 'pPerdida', 5)); tc = toc;
  fprintf('-- Comparación completa (%.2f s):\n', tc);
  for i=1:size(C,1), fprintf('   %-18s %-24s %-18s %-11.3e %-11.3e\n', C{i,:}); end
end
