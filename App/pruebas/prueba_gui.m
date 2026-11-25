% PRUEBA_GUI  Prueba automática de la interfaz (ejecutar en MATLAB).
%   Abre la app, presiona cada botón, recorre TODAS las opciones de cada
%   menú, reproduce en tiempo real, graba un segmento y exporta en los
%   3 formatos. Cualquier error detiene la prueba y muestra dónde ocurrió.
clc;
raiz = fileparts(fileparts(mfilename('fullpath')));
addpath(raiz, fullfile(raiz, 'metodos'));
salida = fullfile(tempdir, 'prueba_app_vibraciones');
if ~exist(salida, 'dir'), mkdir(salida); end
fprintf('Salida de exportación: %s\n', salida);

app = AnalizadorVibracionesApp;
app.ArchivoPrueba = salida;
limpiar = onCleanup(@() delete(app));
pulsar  = @(b) b.ButtonPushedFcn(b, []);
nPasos = 0;

% 1) Señal de prueba analítica
pulsar(app.BtnPrueba); nPasos = nPasos + 1;
assert(~strcmp(app.Val.T.Text, '—'), 'No se mostraron resultados');
fprintf('[OK] Señal de prueba: T = %s, I = %s\n', app.Val.T.Text, app.Val.I.Text);

% 2) Recorrer todas las opciones de todos los menús
menus = {app.DDInterp, app.DDDerivada, app.DDIntegral, app.DDEDO, ...
         app.DDGradoLS, app.DDDrift, app.DDVista};
for m = 1:numel(menus)
    dd = menus{m};
    valores = dd.ItemsData;
    for k = 1:numel(valores)
        dd.Value = valores{k};
        dd.ValueChangedFcn(dd, []); nPasos = nPasos + 1;
        drawnow;
    end
    dd.Value = valores{1}; dd.ValueChangedFcn(dd, []);
    fprintf('[OK] Menú "%s": %d opciones\n', dd.Items{1}, numel(valores));
end
app.DDInterp.Value = 'lagrange'; app.DDInterp.ValueChangedFcn(app.DDInterp, []);
for g = 1:6
    app.SpnGradoLagrange.Value = g; app.SpnGradoLagrange.ValueChangedFcn(app.SpnGradoLagrange, []);
end
app.ChkAtipicos.Value = true; app.ChkAtipicos.ValueChangedFcn(app.ChkAtipicos, []);
app.DDDrift.Value = 'reposo'; app.DDDrift.ValueChangedFcn(app.DDDrift, []);
app.SpnReposo.Value = 1; app.SpnReposo.ValueChangedFcn(app.SpnReposo, []);
app.SpnCilindros.Value = 6; app.SpnCilindros.ValueChangedFcn(app.SpnCilindros, []);
app.SpnFMin.Value = 1; app.SpnFMin.ValueChangedFcn(app.SpnFMin, []);
if strcmp(char(app.DDTema.Enable), 'on')
    temaInicial = app.DDTema.Value;
    for tm = {'light', 'dark', temaInicial}
        app.DDTema.Value = tm{1}; app.DDTema.ValueChangedFcn(app.DDTema, []); drawnow;
    end
    fprintf('[OK] Menú de tema (claro/oscuro/automático)\n');
end
app.SpnCilindros.Value = 4; app.SpnCilindros.ValueChangedFcn(app.SpnCilindros, []);
fprintf('[OK] Spinners y casillas\n');

% 3) Validación de métodos
pulsar(app.BtnComparar);
assert(size(app.TblComparacion.Data, 1) >= 15, 'Tabla de comparación incompleta');
fprintf('[OK] Comparación: %d filas\n', size(app.TblComparacion.Data, 1));

% 4) Carga de archivo real (formato phyphox) y todos sus ejes
app.ChkAtipicos.Value = false;
app.cargarArchivo(fullfile(raiz, 'datos', 'ejemplo_sintetico_phyphox.csv'));
for k = 1:numel(app.DDSenal.ItemsData)
    app.DDSenal.Value = app.DDSenal.ItemsData(k);
    app.DDSenal.ValueChangedFcn(app.DDSenal, []);
end
fprintf('[OK] Archivo phyphox: %d señales, faltantes = %s\n', numel(app.DDSenal.Items), app.Val.interp.Text);
app.SpnPerdida.Value = 5; app.SpnPerdida.ValueChangedFcn(app.SpnPerdida, []);
assert(~startsWith(app.Val.perd.Text, '—'), 'No se calculó el error con pérdida simulada');
fprintf('[OK] Pérdida simulada 5 %%: %s\n', app.Val.perd.Text);
pulsar(app.BtnComparar);
app.SpnPerdida.Value = 0;
reales = {'motor_ralenti_cofre.csv', 'manejo_tablero.csv', ...
          fullfile('originales_phyphox', 'acc_without_g_outside_car.xlsx')};
for k = 1:numel(reales)
    ruta = fullfile(raiz, 'datos', reales{k});
    if exist(ruta, 'file')
        app.cargarArchivo(ruta);
        fprintf('[OK] Datos reales %s: T = %s | f dom = %s\n', reales{k}, app.Val.T.Text, app.Val.f.Text);
    end
end
app.cargarArchivo(fullfile(raiz, 'datos', 'ejemplo_sintetico_phyphox.csv')); app.SpnPerdida.ValueChangedFcn(app.SpnPerdida, []);

% 5) Tiempo real + grabación + exportación en los 3 formatos
app.DDVelocidad.Value = 2;                  % 3 grabaciones caben en 30 s
formatos = app.DDFormato.ItemsData;
for k = 1:numel(formatos)
    app.DDFormato.Value = formatos{k};
    app.EdtNombre.Value = sprintf('prueba_%d', k);
    pulsar(app.BtnIniciar);  pause(1.0);
    assert(strcmp(char(app.BtnGrabar.Enable), 'on'), 'El botón Grabar no se habilitó');
    pulsar(app.BtnGrabar);   pause(1.5);
    pulsar(app.BtnDetenerGrab);
    pulsar(app.BtnIniciar);                     % pausa
    assert(isempty(app.UltimoError), ['Error en tiempo real: ' app.UltimoError]);
    pulsar(app.BtnExportar);
    archivo = fullfile(salida, [app.EdtNombre.Value formatos{k}]);
    assert(exist(archivo, 'file') == 2, ['No se creó ' archivo]);
    fprintf('[OK] Grabación exportada: %s\n', archivo);
end
assert(exist(fullfile(salida, 'prueba_1_original_claro.png'), 'file') == 2, 'No se exportó PNG (claro)');
if isprop(app.UIFigure, 'Theme')
    assert(exist(fullfile(salida, 'prueba_1_original_oscuro.png'), 'file') == 2, 'No se exportó PNG (oscuro)');
    fprintf('[OK] PNG en tema claro y oscuro\n');
end

% 6) Exportar señal completa sin grabación
pulsar(app.BtnPrueba);
app.EdtNombre.Value = 'completa'; app.DDFormato.Value = '.csv';
pulsar(app.BtnExportar);
assert(exist(fullfile(salida, 'completa.csv'), 'file') == 2);
T = readtable(fullfile(salida, 'completa.csv'));
fprintf('[OK] Exportación completa: %d filas x %d columnas\n', height(T), width(T));

fprintf('\n===== PRUEBA DE INTERFAZ SUPERADA (%d acciones) =====\n', nPasos);
if ispc, winopen(salida); end
