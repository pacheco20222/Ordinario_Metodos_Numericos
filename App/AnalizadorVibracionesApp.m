classdef AnalizadorVibracionesApp < matlab.apps.AppBase
% ANALIZADORVIBRACIONESAPP  Interfaz gráfica para el análisis numérico de
% señales de aceleración (vibración/movimiento) medidas con el acelerómetro
% de un teléfono celular.
%
%   Procesos: duración de la señal, detección e interpolación de datos
%   faltantes, derivada (jerk), integral (velocidad), EDO de movimiento
%   (velocidad y posición), tendencia por mínimos cuadrados y corrección
%   de deriva (drift), reproducción en tiempo real con grabación y
%   exportación de resultados.
%
%   Ejecutar:   app = AnalizadorVibracionesApp;
%
%   Toda la matemática está en la carpeta /metodos (funciones nm_*).

    %% ===================== Componentes de la interfaz =====================
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        GridPrincipal       matlab.ui.container.GridLayout
        PanelControl        matlab.ui.container.Panel
        GridControl         matlab.ui.container.GridLayout

        % Datos
        BtnCargar           matlab.ui.control.Button
        BtnPrueba           matlab.ui.control.Button
        LblArchivo          matlab.ui.control.Label
        DDSenal             matlab.ui.control.DropDown

        % Parámetros de algoritmos
        DDInterp            matlab.ui.control.DropDown
        SpnGradoLagrange    matlab.ui.control.Spinner
        SpnFactorHueco      matlab.ui.control.Spinner
        SpnPerdida          matlab.ui.control.Spinner
        ChkAtipicos         matlab.ui.control.CheckBox
        DDDerivada          matlab.ui.control.DropDown
        DDIntegral          matlab.ui.control.DropDown
        DDEDO               matlab.ui.control.DropDown
        DDGradoLS           matlab.ui.control.DropDown
        DDDrift             matlab.ui.control.DropDown
        SpnReposo           matlab.ui.control.Spinner
        SpnCilindros        matlab.ui.control.Spinner
        SpnFMin             matlab.ui.control.Spinner
        DDTema              matlab.ui.control.DropDown
        DDVista             matlab.ui.control.DropDown
        BtnProcesar         matlab.ui.control.Button

        % Exportación
        EdtNombre           matlab.ui.control.EditField
        DDFormato           matlab.ui.control.DropDown
        ChkPNG              matlab.ui.control.CheckBox
        BtnExportar         matlab.ui.control.Button

        % Área de gráficas
        GridDerecha         matlab.ui.container.GridLayout
        AxOriginal          matlab.ui.control.UIAxes
        Tabs                matlab.ui.container.TabGroup
        TabProcesada        matlab.ui.container.Tab
        TabTiempoReal       matlab.ui.container.Tab
        TabValidacion       matlab.ui.container.Tab
        AxProcesada         matlab.ui.control.UIAxes

        % Tiempo real
        DDVelocidad         matlab.ui.control.DropDown
        SpnVentana          matlab.ui.control.Spinner
        BtnIniciar          matlab.ui.control.Button
        BtnGrabar           matlab.ui.control.Button
        BtnDetenerGrab      matlab.ui.control.Button
        LampGrabando        matlab.ui.control.Lamp
        LblRT               matlab.ui.control.Label
        AxRTa               matlab.ui.control.UIAxes
        AxRTv               matlab.ui.control.UIAxes

        % Validación
        BtnComparar         matlab.ui.control.Button
        TblComparacion      matlab.ui.control.Table
        AxErrores           matlab.ui.control.UIAxes

        % Resultados
        PanelResultados     matlab.ui.container.Panel
        GridResultados      matlab.ui.container.GridLayout
        Val                 struct          % etiquetas de valores
        LblEstado           matlab.ui.control.Label
    end

    %% ===================== Datos internos =====================
    properties (Access = public)
        % Si no está vacío, Exportar escribe aquí sin abrir diálogos
        % (lo usa pruebas/prueba_gui.m para la prueba automática).
        ArchivoPrueba = ''
        UltimoError   = ''      % último error del monitor en tiempo real
    end

    properties (Access = private)
        D        = []      % datos cargados (t, Y, nombres)
        R        = []      % resultados del motor numérico
        C        = {}      % tabla de comparación de métodos
        Ref      = []      % solución analítica (solo señal de prueba)
        Tmr      = []      % timer de reproducción en tiempo real
        idxRT    = 1       % índice actual de reproducción
        grabando = false
        idxIniGrab = []
        idxFinGrab = []
        hRTa; hRTv; hRTgrab_a; hRTgrab_v   % líneas de tiempo real
        PeriodoRT = 0.05   % s entre actualizaciones
        GrisRef = [0.55 0.55 0.55]   % curva analítica: visible en tema claro y oscuro
    end

    %% ===================== Lógica principal =====================
    methods (Access = private)

        function startupFcn(app)
            raiz = fileparts(mfilename('fullpath'));
            addpath(fullfile(raiz, 'metodos'));
            app.estado('Listo. Carga un archivo (CSV/XLSX/MAT) o genera la señal de prueba.');
            app.habilitar(false);
        end

        % ---------------- Carga de datos ----------------
        function cargarDatos(app)
            [f, p] = uigetfile({'*.csv;*.xlsx;*.xls;*.mat;*.txt', ...
                'Datos de aceleración (*.csv, *.xlsx, *.mat)'}, 'Selecciona el archivo de datos');
            figure(app.UIFigure);                 % regresar el foco a la app
            if isequal(f, 0), return; end
            app.cargarArchivo(fullfile(p, f));
        end
    end

    methods (Access = public)
        function cargarArchivo(app, ruta)
            % Carga un archivo de datos sin diálogo (también usado por las pruebas)
            [~, f, e] = fileparts(ruta); f = [f e];
            try
                app.detenerRT();
                app.D   = nm_cargar_datos(ruta);
                app.Ref = [];
                app.LblArchivo.Text = app.D.archivo;
                app.fijarItems(app.D.nombres);
                app.DDSenal.Value = min(3, numel(app.D.nombres));   % eje z por defecto
                app.SpnFMin.Value = 5;            % vibración del motor (> 5 Hz)
                [~, nom] = fileparts(f);
                app.EdtNombre.Value = ['resultados_' nom];
                app.habilitar(true);
                app.procesar();
            catch ME
                if ~isempty(app.ArchivoPrueba), rethrow(ME); end
                uialert(app.UIFigure, ME.message, 'Error al cargar');
            end
        end
    end

    methods (Access = private)

        function senalPrueba(app)
            app.detenerRT();
            s = nm_senal_prueba(10, 100, 0.03, 0);
            app.Ref = s;
            app.D = struct('t', s.t, 'Y', s.a, 'nombres', {{'a(t) = A sin(wt) + b0 + b1 t'}}, ...
                           'archivo', 'Señal de prueba analítica');
            app.LblArchivo.Text = app.D.archivo;
            app.fijarItems(app.D.nombres);
            app.DDSenal.Value = 1;
            app.DDDrift.Value = 'ninguna';        % para comparar contra la solución exacta
            app.SpnFMin.Value = 0.5;              % la señal de prueba oscila a 1.37 Hz
            app.EdtNombre.Value = 'resultados_senal_prueba';
            app.habilitar(true);
            app.procesar();
        end

        % ---------------- Procesamiento ----------------
        function op = opciones(app)
            op = struct( ...
                'metodoInterp',   app.DDInterp.Value, ...
                'gradoLagrange',  app.SpnGradoLagrange.Value, ...
                'factorHueco',    app.SpnFactorHueco.Value, ...
                'usarAtipicos',   app.ChkAtipicos.Value, ...
                'kMAD',           5, ...
                'metodoDerivada', app.DDDerivada.Value, ...
                'metodoIntegral', app.DDIntegral.Value, ...
                'metodoEDO',      app.DDEDO.Value, ...
                'gradoTendencia', app.DDGradoLS.Value, ...
                'metodoDrift',    app.DDDrift.Value, ...
                'tReposo',        app.SpnReposo.Value, ...
                'pPerdida',       app.SpnPerdida.Value, ...
                'semilla',        1, ...
                'fMin',           app.SpnFMin.Value);
        end

        function procesar(app)
            if isempty(app.D), return; end
            try
                app.detenerRT();
                app.SpnGradoLagrange.Enable = app.onoff(strcmp(app.DDInterp.Value, 'lagrange'));
                app.SpnReposo.Enable = app.onoff(strcmp(app.DDDrift.Value, 'reposo'));
                y = app.D.Y(:, app.DDSenal.Value);
                tic;
                app.R = nm_procesar(app.D.t, y, app.opciones());
                tp = toc;
                app.graficarOriginal();
                app.graficarProcesada();
                app.mostrarResultados();
                app.prepararRT();
                app.estado(sprintf('Procesado en %.1f ms  |  interpolación: %s, derivada: %s, integral: %s, EDO: %s', ...
                    1e3*tp, app.DDInterp.Value, app.DDDerivada.Value, app.DDIntegral.Value, app.DDEDO.Value));
            catch ME
                if ~isempty(app.ArchivoPrueba), rethrow(ME); end
                uialert(app.UIFigure, ME.message, 'Error en el procesamiento');
            end
        end

        % ---------------- Gráficas ----------------
        function graficarOriginal(app)
            ax = app.AxOriginal; R = app.R;
            cla(ax); hold(ax, 'on');
            plot(ax, R.tOrig, R.yOrig, '-', 'SeriesIndex', 1, 'LineWidth', 0.8, ...
                'DisplayName', 'Datos originales');
            f = R.esFaltante;
            if any(f)
                plot(ax, R.t(f), R.y(f), 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0.85 0.1 0.1], ...
                    'MarkerEdgeColor', 'none', 'DisplayName', sprintf('Interpolados (%d)', sum(f)));
            end
            if ~isempty(R.perdida.tRem)
                plot(ax, R.perdida.tRem, R.perdida.yRem, 's', 'MarkerSize', 5, ...
                    'MarkerEdgeColor', [0.20 0.75 0.20], 'DisplayName', ...
                    sprintf('Valor real eliminado (%d)', numel(R.perdida.tRem)));
            end
            if R.falt.nAtipicos > 0
                ia = R.falt.idxAtipico;
                plot(ax, R.falt.tOrdenado(ia), R.falt.yOrdenado(ia), 'x', 'Color', [0.93 0.69 0.13], ...
                    'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', 'Atípicos descartados');
            end
            hold(ax, 'off'); grid(ax, 'on');
            xlabel(ax, 't [s]'); ylabel(ax, 'a [m/s^2]');
            title(ax, sprintf('Señal original: %s', app.DDSenal.Items{app.DDSenal.ItemsData == app.DDSenal.Value}), ...
                'Interpreter', 'none');
            legend(ax, 'Location', 'northeast');
            xlim(ax, [R.t(1) R.t(end)]);
        end

        function graficarProcesada(app)
            ax = app.AxProcesada; R = app.R;
            cla(ax, 'reset');          % elimina también el eje derecho de yyaxis
            hold(ax, 'on');
            switch app.DDVista.Value
                case 'senal'
                    plot(ax, R.t, R.y, 'SeriesIndex', 1, 'DisplayName', ...
                        sprintf('Reconstruida (%s)', app.DDInterp.Value));
                    plot(ax, R.t, R.yTend, 'r-', 'LineWidth', 2, 'DisplayName', ...
                        sprintf('Tendencia MC grado %d (R^2=%.4f)', R.tend.grado, R.tend.R2));
                    if ~strcmp(R.op.metodoDrift, 'ninguna')
                        plot(ax, R.t, R.yInt, 'SeriesIndex', 5, 'DisplayName', ...
                            sprintf('Señal corregida (drift: %s)', R.op.metodoDrift));
                    end
                    yl = 'a [m/s^2]'; tt = 'Señal reconstruida y línea de tendencia (mínimos cuadrados)';
                    if ~isempty(app.Ref)
                        plot(ax, app.Ref.tRef, app.Ref.aRef, ':', 'Color', app.GrisRef, 'LineWidth', 1.2, 'DisplayName', 'Analítica');
                    end
                case 'derivada'
                    plot(ax, R.t, R.dy, 'SeriesIndex', 4, 'DisplayName', ...
                        sprintf('da/dt (%s)', app.DDDerivada.Value));
                    if ~isempty(app.Ref)
                        plot(ax, app.Ref.tRef, app.Ref.daRef, ':', 'Color', app.GrisRef, 'LineWidth', 1.2, 'DisplayName', 'Analítica');
                    end
                    yl = 'jerk da/dt [m/s^3]'; tt = 'Derivada de la señal (jerk)';
                case 'integral'
                    plot(ax, R.t, R.Iacum, 'SeriesIndex', 2, 'LineWidth', 1.2, ...
                        'DisplayName', sprintf('\\int a dt (%s)', app.DDIntegral.Value));
                    if ~isempty(app.Ref) && strcmp(R.op.metodoDrift, 'ninguna')
                        plot(ax, app.Ref.tRef, app.Ref.vRef, ':', 'Color', app.GrisRef, 'LineWidth', 1.2, 'DisplayName', 'Analítica');
                    end
                    yl = 'v [m/s]'; tt = sprintf('Integral acumulada de la señal = velocidad   (I total = %.5g)', R.I);
                case 'edo'
                    hold(ax, 'off'); yyaxis(ax, 'left'); hold(ax, 'on');
                    plot(ax, R.t, R.v, '-', 'DisplayName', sprintf('v(t) (%s)', app.DDEDO.Value));
                    ylabel(ax, 'v [m/s]');
                    yyaxis(ax, 'right'); hold(ax, 'on');
                    plot(ax, R.t, R.x, '-', 'DisplayName', sprintf('x(t) (%s)', app.DDEDO.Value));
                    if ~isempty(app.Ref) && strcmp(R.op.metodoDrift, 'ninguna')
                        plot(ax, app.Ref.tRef, app.Ref.xRef, ':', 'Color', app.GrisRef, 'LineWidth', 1.2, 'DisplayName', 'x analítica');
                    end
                    ylabel(ax, 'x [m]');
                    yl = ''; tt = 'EDO de movimiento: dx/dt = v,  dv/dt = a(t)';
                case 'espectro'
                    plot(ax, R.fEsp, R.ampEsp, 'SeriesIndex', 1, 'DisplayName', '|A(f)|');
                    plot(ax, R.fDom, interp1(R.fEsp, R.ampEsp, R.fDom), 'rv', 'MarkerFaceColor', 'r', ...
                        'DisplayName', sprintf('f dominante (≥%g Hz) = %.2f Hz', R.op.fMin, R.fDom));
                    xlabel(ax, 'f [Hz]');
                    yl = 'amplitud [m/s^2]'; tt = 'Espectro de frecuencia (FFT) — vibración del sistema';
            end
            hold(ax, 'off'); grid(ax, 'on');
            if ~isempty(yl), ylabel(ax, yl); end
            title(ax, tt);
            legend(ax, 'Location', 'northeast');
            if strcmp(app.DDVista.Value, 'espectro')
                xlim(ax, [0 R.fEsp(end)]);
            else
                xlabel(ax, 't [s]');
                xlim(ax, [R.t(1) R.t(end)]);
            end
        end

        function mostrarResultados(app)
            R = app.R; V = app.Val;
            V.T.Text     = sprintf('%.4f s', R.duracion.T);
            V.N.Text     = sprintf('%d (malla: %d)', R.duracion.N, numel(R.t));
            V.fs.Text    = sprintf('%.2f Hz  (Δt = %.4g s)', R.duracion.fs, R.h);
            V.falt.Text  = sprintf('NaN: %d | huecos: %d | atípicos: %d', R.falt.nNaN, R.falt.nHuecos, R.falt.nAtipicos);
            V.interp.Text = sprintf('%d puntos (%.2f %%)', R.falt.nFaltantes, 100*R.falt.nFaltantes/numel(R.t));
            V.I.Text     = sprintf('%.6g m/s', R.I);
            V.v.Text     = sprintf('%.5g m/s  (máx %.4g km/h)', R.vFinal, 3.6*max(abs(R.v)));
            V.x.Text     = sprintf('%.6g m', R.xFinal);
            V.dy.Text    = sprintf('%.5g m/s^3', R.dyMax);
            V.pico.Text  = sprintf('%.5g m/s^2  (RMS %.4g)', R.pico, R.rms);
            cil = app.SpnCilindros.Value;
            V.f.Text     = sprintf('%.2f Hz ≈ %.0f rpm (%d cil.)', R.fDom, 120*R.fDom/cil, cil);
            V.drift.Text = sprintf('%s  (sesgo medio %.4g m/s^2)', R.op.metodoDrift, mean(R.sesgo));
            if isnan(R.perdida.rmse)
                V.perd.Text = '— (sin pérdida simulada)';
            else
                V.perd.Text = sprintf('RMSE %.4g | máx %.4g m/s^2 (%d pts)', R.perdida.rmse, ...
                    R.perdida.emax, numel(R.perdida.tRem));
            end
            V.eq.Text    = app.ecuacion(R.tend.p);
            V.R2.Text    = sprintf('%.6f   (S_y/x = %.4g)', R.tend.R2, R.tend.Syx);
        end

        function s = ecuacion(~, p)
            g = numel(p) - 1; s = 'y = ';
            for k = 1:numel(p)
                e = g - k + 1; c = p(k);
                if k > 1
                    if c >= 0, s = [s ' + ']; else, s = [s ' - ']; end %#ok<AGROW>
                    c = abs(c);
                end
                switch e
                    case 0, s = [s sprintf('%.4g', c)]; %#ok<AGROW>
                    case 1, s = [s sprintf('%.4g t', c)]; %#ok<AGROW>
                    otherwise, s = [s sprintf('%.4g t^%d', c, e)]; %#ok<AGROW>
                end
            end
        end

        % ---------------- Comparación / validación ----------------
        function comparar(app)
            if isempty(app.D), return; end
            d = uiprogressdlg(app.UIFigure, 'Title', 'Comparación de métodos', ...
                'Message', 'Ejecutando todos los métodos...', 'Indeterminate', 'on');
            try
                y = app.D.Y(:, app.DDSenal.Value);
                op = app.opciones();
                if ~isempty(app.Ref), op.metodoDrift = 'ninguna'; end
                app.C = nm_comparar_metodos(app.D.t, y, op, app.Ref);
                T = app.C;
                for i = 1:size(T,1)
                    for j = 4:5
                        if isnan(T{i,j}), T{i,j} = '—'; else, T{i,j} = sprintf('%.3e', T{i,j}); end
                    end
                end
                app.TblComparacion.Data = T;
                % Gráfica de barras (escala log) del error
                ax = app.AxErrores; cla(ax);
                if isempty(app.Ref)
                    e = cell2mat(app.C(:,5)); etiqueta = 'Diferencia vs función de MATLAB';
                else
                    e = cell2mat(app.C(:,4)); etiqueta = 'Error vs solución analítica';
                end
                ok = ~isnan(e) & e > 0;
                nombres = cellfun(@(a, b) [a ': ' b], app.C(:,1), app.C(:,2), 'UniformOutput', false);
                if any(ok)
                    barh(ax, categorical(nombres(ok), nombres(ok)), e(ok), 'SeriesIndex', 1);
                    set(ax, 'XScale', 'log');
                end
                grid(ax, 'on');
                title(ax, etiqueta); xlabel(ax, 'error (escala log)');
                app.estado('Comparación terminada. Ver pestaña "Validación de métodos".');
            catch ME
                close(d);
                if ~isempty(app.ArchivoPrueba), rethrow(ME); end
                uialert(app.UIFigure, ME.message, 'Error en la comparación');
                return
            end
            close(d);
        end

        % ---------------- Tiempo real ----------------
        function prepararRT(app)
            R = app.R;
            app.idxRT = 1; app.idxIniGrab = []; app.idxFinGrab = [];
            cla(app.AxRTa); cla(app.AxRTv);
            app.hRTa = plot(app.AxRTa, NaN, NaN, 'SeriesIndex', 1);
            hold(app.AxRTa, 'on');
            app.hRTgrab_a = plot(app.AxRTa, NaN, NaN, 'r', 'LineWidth', 1.5);
            hold(app.AxRTa, 'off');
            app.hRTv = plot(app.AxRTv, NaN, NaN, 'SeriesIndex', 2);
            hold(app.AxRTv, 'on');
            app.hRTgrab_v = plot(app.AxRTv, NaN, NaN, 'r', 'LineWidth', 1.5);
            hold(app.AxRTv, 'off');
            ylim(app.AxRTa, app.rango(R.y)); ylim(app.AxRTv, app.rango(R.v));
            grid(app.AxRTa, 'on'); grid(app.AxRTv, 'on');
            ylabel(app.AxRTa, 'a [m/s^2]'); ylabel(app.AxRTv, 'v [m/s]'); xlabel(app.AxRTv, 't [s]');
            title(app.AxRTa, 'Monitor en tiempo real (rojo = segmento grabado)');
            app.LblRT.Text = 'Detenido';
            app.BtnIniciar.Text = '▶ Iniciar';
            app.BtnGrabar.Enable = 'off'; app.BtnDetenerGrab.Enable = 'off';
            app.LampGrabando.Color = [0.6 0.6 0.6]; app.grabando = false;
        end

        function iniciarPausarRT(app)
            if isempty(app.R), return; end
            if ~isempty(app.Tmr) && isvalid(app.Tmr) && strcmp(app.Tmr.Running, 'on')
                stop(app.Tmr);
                app.BtnIniciar.Text = '▶ Reanudar';
                app.LblRT.Text = sprintf('En pausa  t = %.2f s', app.R.t(app.idxRT));
                return
            end
            if app.idxRT >= numel(app.R.t), app.prepararRT(); end
            if isempty(app.Tmr) || ~isvalid(app.Tmr)
                app.Tmr = timer('ExecutionMode', 'fixedRate', 'Period', app.PeriodoRT, ...
                    'BusyMode', 'drop', 'TimerFcn', @(~,~) app.tickRT());
            end
            start(app.Tmr);
            app.BtnIniciar.Text = '⏸ Pausar';
            app.BtnGrabar.Enable = app.onoff(~app.grabando);
        end

        function tickRT(app)
            try
                R = app.R; n = numel(R.t);
                paso = max(1, round(app.DDVelocidad.Value * app.PeriodoRT / R.h));
                k = min(app.idxRT + paso, n);
                app.idxRT = k;
                w = app.SpnVentana.Value;
                i0 = find(R.t >= R.t(k) - w, 1, 'first');
                set(app.hRTa, 'XData', R.t(i0:k), 'YData', R.y(i0:k));
                set(app.hRTv, 'XData', R.t(i0:k), 'YData', R.v(i0:k));
                if ~isempty(app.idxIniGrab)
                    fin = k; if ~isempty(app.idxFinGrab), fin = app.idxFinGrab; end
                    g = max(app.idxIniGrab, i0):fin;
                    set(app.hRTgrab_a, 'XData', R.t(g), 'YData', R.y(g));
                    set(app.hRTgrab_v, 'XData', R.t(g), 'YData', R.v(g));
                end
                xl = [R.t(k) - w, max(R.t(k), R.t(1) + w)];
                xlim(app.AxRTa, xl); xlim(app.AxRTv, xl);
                txt = sprintf('t = %.2f s | a = %.3f m/s² | v = %.4f m/s | x = %.4f m', ...
                    R.t(k), R.y(k), R.v(k), R.x(k));
                if app.grabando
                    txt = sprintf('● GRABANDO (%d muestras) | %s', k - app.idxIniGrab + 1, txt);
                end
                app.LblRT.Text = txt;
                drawnow limitrate;
                if k >= n
                    stop(app.Tmr);
                    if app.grabando, app.detenerGrabacion(); end
                    app.BtnIniciar.Text = '▶ Reiniciar';
                    app.LblRT.Text = ['Fin de la señal. ' txt];
                end
            catch ME
                app.UltimoError = ME.message;
                app.detenerRT();
            end
        end

        function iniciarGrabacion(app)
            app.grabando = true;
            app.idxIniGrab = app.idxRT; app.idxFinGrab = [];
            app.LampGrabando.Color = [0.9 0.1 0.1];
            app.BtnGrabar.Enable = 'off'; app.BtnDetenerGrab.Enable = 'on';
            app.estado(sprintf('Grabación iniciada en t = %.3f s', app.R.t(app.idxRT)));
        end

        function detenerGrabacion(app)
            if ~app.grabando, return; end
            app.grabando = false;
            app.idxFinGrab = app.idxRT;
            app.LampGrabando.Color = [0.2 0.7 0.2];
            app.BtnGrabar.Enable = 'on'; app.BtnDetenerGrab.Enable = 'off';
            app.estado(sprintf('Grabación detenida: %.3f s a %.3f s (%d muestras). Escribe el nombre y pulsa Exportar.', ...
                app.R.t(app.idxIniGrab), app.R.t(app.idxFinGrab), app.idxFinGrab - app.idxIniGrab + 1));
        end

        function detenerRT(app)
            if ~isempty(app.Tmr) && isvalid(app.Tmr)
                stop(app.Tmr);
            end
            app.grabando = false;
        end

        % ---------------- Exportación ----------------
        function exportar(app)
            if isempty(app.R), return; end
            R = app.R;
            if app.grabando, app.detenerGrabacion(); end
            if isempty(app.idxIniGrab) || isempty(app.idxFinGrab)
                if ~isempty(app.ArchivoPrueba)
                    r = 'Señal completa';
                else
                r = uiconfirm(app.UIFigure, ['No hay un segmento grabado en tiempo real. ' ...
                    '¿Exportar la señal completa?'], 'Exportar', ...
                    'Options', {'Señal completa', 'Cancelar'}, 'DefaultOption', 1);
                end
                if strcmp(r, 'Cancelar'), return; end
                idx = 1:numel(R.t);
            else
                idx = app.idxIniGrab:app.idxFinGrab;
            end
            nombre = strtrim(app.EdtNombre.Value);
            nombre = regexprep(nombre, '[\\/:*?"<>|]', '_');
            if isempty(nombre)
                uialert(app.UIFigure, 'Escribe el nombre del archivo.', 'Nombre requerido'); return
            end
            ext = app.DDFormato.Value;
            if isempty(app.ArchivoPrueba)
                [f, p] = uiputfile(['*' ext], 'Guardar resultados como', [nombre ext]);
                figure(app.UIFigure);
                if isequal(f, 0), return; end
            else
                p = app.ArchivoPrueba; f = [nombre ext];
            end
            archivo = fullfile(p, f);
            [~, base] = fileparts(f);
            app.EdtNombre.Value = base;

            % Tabla de datos del segmento
            yOrigMalla = R.y; yOrigMalla(R.esFaltante) = NaN;
            T = table(R.t(idx), yOrigMalla(idx), R.y(idx), R.esFaltante(idx), R.dy(idx), ...
                R.Iacum(idx), R.v(idx), R.x(idx), R.yTend(idx), ...
                'VariableNames', {'t_s', 'a_original', 'a_reconstruida', 'interpolado', ...
                'jerk_m_s3', 'integral_acum', 'v_m_s', 'x_m', 'tendencia_MC'});
            Res = app.tablaResumen(idx);
            try
                switch ext
                    case '.csv'
                        writetable(T, archivo);
                        writetable(Res, fullfile(p, [base '_resumen.csv']));
                    case '.xlsx'
                        if exist(archivo, 'file'), delete(archivo); end
                        writetable(T, archivo, 'Sheet', 'Datos');
                        writetable(Res, archivo, 'Sheet', 'Resumen');
                        if ~isempty(app.C)
                            writecell([{'Proceso','Metodo','Resultado','Error_analitico','Dif_MATLAB'}; app.C], ...
                                archivo, 'Sheet', 'Comparacion');
                        end
                    case '.mat'
                        resultados = R; segmento = T; resumen = Res; comparacion = app.C; %#ok<NASGU>
                        save(archivo, 'resultados', 'segmento', 'resumen', 'comparacion');
                end
                if app.ChkPNG.Value
                    app.exportarGraficas(p, base);
                end
                app.estado(sprintf('Exportado: %s  (%d muestras, t = %.3f–%.3f s)', ...
                    archivo, numel(idx), R.t(idx(1)), R.t(idx(end))));
                if isempty(app.ArchivoPrueba)
                    uialert(app.UIFigure, sprintf('Resultados guardados en:\n%s', archivo), ...
                        'Exportación completa', 'Icon', 'success');
                end
            catch ME
                if ~isempty(app.ArchivoPrueba), rethrow(ME); end
                uialert(app.UIFigure, ME.message, 'Error al exportar');
            end
        end

        function exportarGraficas(app, p, base)
            % Guarda las gráficas en PNG en tema claro y oscuro.
            % Cada gráfica se COPIA a una ventana invisible con el tema
            % deseado y se exporta ahí: la app nunca cambia de tema.
            % (Temas: MATLAB R2025a o posterior; antes solo se exporta en claro.)
            ejes = {app.AxOriginal, 'original'; app.AxProcesada, 'procesada'};
            if ~isempty(app.idxIniGrab)
                ejes(end+1,:) = {app.AxRTa, 'tiempo_real_a'};
                ejes(end+1,:) = {app.AxRTv, 'tiempo_real_v'};
            end
            if ~isempty(app.C)
                ejes(end+1,:) = {app.AxErrores, 'validacion'};
            end
            conTemas = isprop(app.UIFigure, 'Theme') && exist('theme', 'file') > 0;
            if conTemas
                temas = {'light', 'claro'; 'dark', 'oscuro'};
            else
                temas = {'', 'claro'};
            end
            for k = 1:size(temas, 1)
                fx = uifigure('Visible', 'off', 'Position', [100 100 1200 520]);
                limpiar = onCleanup(@() delete(fx));
                if conTemas, theme(fx, temas{k, 1}); end
                for j = 1:size(ejes, 1)
                    original = ejes{j, 1};
                    archivo = fullfile(p, sprintf('%s_%s_%s.png', base, ejes{j, 2}, temas{k, 2}));
                    try
                        copia = copyobj(original, fx);
                        copia.Units = 'pixels';
                        copia.Position = [10 10 1180 500];
                        if ~isempty(original.Legend) && isvalid(original.Legend) && ...
                                strcmp(char(original.Legend.Visible), 'on')
                            legend(copia, 'Location', original.Legend.Location);
                        end
                        exportgraphics(copia, archivo, 'Resolution', 200);
                        delete(copia);
                    catch
                        % Respaldo: exportar la gráfica tal como se ve en la app
                        if k == 1
                            exportgraphics(original, archivo, 'Resolution', 200);
                        end
                    end
                end
                clear limpiar
            end
        end

        function cambiarTema(app)
            % Tema de la interfaz: automático (igual que MATLAB), claro u oscuro
            if ~(isprop(app.UIFigure, 'Theme') && exist('theme', 'file') > 0), return; end
            theme(app.UIFigure, app.DDTema.Value);
        end

        function Res = tablaResumen(app, idx)
            R = app.R; op = R.op;
            seg = R.y(idx);
            Iseg = 0;
            if numel(idx) > 1, Iseg = nm_integral(R.yInt(idx), R.h, op.metodoIntegral); end
            nombres = {'Archivo'; 'Señal'; 'Duración total [s]'; 'Muestras'; 'fs [Hz]'; ...
                'NaN'; 'Huecos'; 'Atípicos'; 'Puntos interpolados'; ...
                'Método interpolación'; 'Método derivada'; 'Método integral'; 'Método EDO'; ...
                'Grado tendencia'; 'Corrección drift'; 'Ecuación tendencia'; 'R2'; ...
                'Pérdida simulada [%]'; 'RMSE interpolación (datos eliminados)'; ...
                'Integral señal completa'; 'v final [m/s]'; 'x final [m]'; 'Jerk máx [m/s3]'; ...
                'Frecuencia dominante [Hz]'; 'Segmento inicio [s]'; 'Segmento fin [s]'; ...
                'Duración segmento [s]'; 'Integral del segmento'; 'Pico segmento [m/s2]'; 'RMS segmento'};
            valores = {app.D.archivo; app.DDSenal.Items{app.DDSenal.ItemsData == app.DDSenal.Value}; ...
                R.duracion.T; R.duracion.N; R.duracion.fs; R.falt.nNaN; R.falt.nHuecos; ...
                R.falt.nAtipicos; R.falt.nFaltantes; op.metodoInterp; op.metodoDerivada; ...
                op.metodoIntegral; op.metodoEDO; op.gradoTendencia; op.metodoDrift; ...
                app.ecuacion(R.tend.p); R.tend.R2; op.pPerdida; R.perdida.rmse; R.I; R.vFinal; R.xFinal; R.dyMax; R.fDom; ...
                R.t(idx(1)); R.t(idx(end)); R.t(idx(end)) - R.t(idx(1)); Iseg; ...
                max(abs(seg)); sqrt(mean(seg.^2))};
            valores = cellfun(@app.aTexto, valores, 'UniformOutput', false);
            Res = table(nombres, valores, 'VariableNames', {'Parametro', 'Valor'});
        end

        function s = aTexto(~, v)
            if ischar(v), s = v;
            elseif islogical(v), s = char(string(v));
            else, s = sprintf('%.10g', v);
            end
        end

        % ---------------- Utilidades ----------------
        function estado(app, msg)
            app.LblEstado.Text = ['  ' msg];
        end

        function habilitar(app, on)
            comps = {app.DDSenal, app.DDInterp, app.SpnFactorHueco, app.ChkAtipicos, ...
                app.DDDerivada, app.DDIntegral, app.DDEDO, app.DDGradoLS, app.SpnPerdida, ...
                app.DDVista, app.DDDrift, app.SpnCilindros, app.SpnFMin, app.BtnProcesar, app.BtnExportar, app.BtnIniciar, app.BtnComparar, ...
                app.EdtNombre, app.DDFormato, app.ChkPNG, app.SpnGradoLagrange};
            for k = 1:numel(comps)
                comps{k}.Enable = app.onoff(on);
            end
            app.SpnReposo.Enable = 'off';
            if on
                app.SpnGradoLagrange.Enable = app.onoff(strcmp(app.DDInterp.Value, 'lagrange'));
                app.SpnReposo.Enable = app.onoff(strcmp(app.DDDrift.Value, 'reposo'));
            end
        end

        function lim = rango(~, y)
            % Límites de eje con 10 % de margen (nunca de ancho cero)
            lo = min(y); hi = max(y); m = 0.1 * (hi - lo);
            if m <= 0, m = max(abs(hi), 1) * 0.1; end
            lim = [lo - m, hi + m];
        end

        function s = onoff(~, tf)
            if tf, s = 'on'; else, s = 'off'; end
        end

        function fijarItems(app, nombres)
            % Cambia las opciones del menú de señales de forma segura
            app.DDSenal.ItemsData = [];
            app.DDSenal.Items = nombres;
            app.DDSenal.ItemsData = 1:numel(nombres);
        end

        function cerrar(app)
            app.detenerRT();
            if ~isempty(app.Tmr) && isvalid(app.Tmr), delete(app.Tmr); end
            delete(app);
        end
    end

    %% ===================== Construcción de la interfaz =====================
    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off', 'Name', ...
                'Analizador numérico de vibraciones — Métodos Numéricos', ...
                'Position', [60 40 1440 860], 'CloseRequestFcn', @(~,~) app.cerrar());

            app.GridPrincipal = uigridlayout(app.UIFigure, [2 2], ...
                'ColumnWidth', {330, '1x'}, 'RowHeight', {'1x', 22}, ...
                'Padding', [6 6 6 2], 'RowSpacing', 2);

            % ---------- Panel de control (izquierda) ----------
            app.PanelControl = uipanel(app.GridPrincipal, 'Title', 'Panel de control', ...
                'FontWeight', 'bold', 'Scrollable', 'on');
            app.PanelControl.Layout.Row = 1; app.PanelControl.Layout.Column = 1;
            filas = repmat({24}, 1, 30);
            app.GridControl = uigridlayout(app.PanelControl, [30 2], ...
                'ColumnWidth', {125, '1x'}, 'RowHeight', filas, 'RowSpacing', 5, 'Padding', [8 8 8 8]);
            g = app.GridControl; r = 0;

            r = r + 1; app.seccion(g, r, '1. Datos');
            r = r + 1;
            app.BtnCargar = uibutton(g, 'Text', '📂 Cargar datos', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) app.cargarDatos());
            app.BtnCargar.Layout.Row = r; app.BtnCargar.Layout.Column = 1;
            app.BtnPrueba = uibutton(g, 'Text', '🧪 Señal de prueba', ...
                'Tooltip', 'Señal sintética con solución analítica para validar los métodos', ...
                'ButtonPushedFcn', @(~,~) app.senalPrueba());
            app.BtnPrueba.Layout.Row = r; app.BtnPrueba.Layout.Column = 2;
            r = r + 1;
            app.LblArchivo = uilabel(g, 'Text', 'Sin archivo', 'FontAngle', 'italic');
            app.LblArchivo.Layout.Row = r; app.LblArchivo.Layout.Column = [1 2];
            r = r + 1; app.etiqueta(g, r, 'Señal / eje:');
            app.DDSenal = uidropdown(g, 'Items', {'—'}, 'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.DDSenal, r);

            r = r + 1; app.seccion(g, r, '2. Datos faltantes');
            r = r + 1; app.etiqueta(g, r, 'Interpolación:');
            app.DDInterp = uidropdown(g, ...
                'Items', {'Lineal', 'Newton/Lagrange local', 'Spline cúbico natural'}, ...
                'ItemsData', {'lineal', 'lagrange', 'spline'}, 'Value', 'spline', ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.DDInterp, r);
            r = r + 1; app.etiqueta(g, r, 'Grado Lagrange:');
            app.SpnGradoLagrange = uispinner(g, 'Limits', [1 6], 'Value', 3, 'Step', 1, ...
                'RoundFractionalValues', 'on', 'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.SpnGradoLagrange, r);
            r = r + 1; app.etiqueta(g, r, 'Factor de hueco:');
            app.SpnFactorHueco = uispinner(g, 'Limits', [1.1 10], 'Value', 1.5, 'Step', 0.1, ...
                'Tooltip', 'Hueco si Δt > factor × mediana(Δt)', ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.SpnFactorHueco, r);
            r = r + 1; app.etiqueta(g, r, 'Simular pérdida [%]:');
            app.SpnPerdida = uispinner(g, 'Limits', [0 30], 'Value', 0, 'Step', 1, ...
                'Tooltip', ['Elimina a propósito ese % de muestras reales (en ráfagas) ' ...
                'para medir el error de interpolación contra el valor verdadero'], ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.SpnPerdida, r);
            r = r + 1;
            app.ChkAtipicos = uicheckbox(g, 'Text', 'Atípicos como faltantes (filtro de Hampel)', ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ChkAtipicos.Layout.Row = r; app.ChkAtipicos.Layout.Column = [1 2];

            r = r + 1; app.seccion(g, r, '3. Algoritmos');
            r = r + 1; app.etiqueta(g, r, 'Derivada:');
            app.DDDerivada = uidropdown(g, ...
                'Items', {'Adelante O(h)', 'Atrás O(h)', 'Centrada O(h²)', '5 puntos O(h⁴)'}, ...
                'ItemsData', {'adelante', 'atras', 'centrada', 'cinco'}, 'Value', 'centrada', ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.DDDerivada, r);
            r = r + 1; app.etiqueta(g, r, 'Integral:');
            app.DDIntegral = uidropdown(g, ...
                'Items', {'Trapecio O(h²)', 'Simpson 1/3 O(h⁴)', 'Simpson 3/8 O(h⁴)'}, ...
                'ItemsData', {'trapecio', 'simpson13', 'simpson38'}, 'Value', 'simpson13', ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.DDIntegral, r);
            r = r + 1; app.etiqueta(g, r, 'EDO (v, x):');
            app.DDEDO = uidropdown(g, ...
                'Items', {'Euler O(h)', 'Heun / RK2 O(h²)', 'Runge-Kutta 4 O(h⁴)'}, ...
                'ItemsData', {'euler', 'heun', 'rk4'}, 'Value', 'rk4', ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.DDEDO, r);
            r = r + 1; app.etiqueta(g, r, 'Tendencia (MC):');
            app.DDGradoLS = uidropdown(g, ...
                'Items', {'Grado 1 (lineal)', 'Grado 2', 'Grado 3', 'Grado 4', 'Grado 5', 'Grado 6'}, ...
                'ItemsData', {1, 2, 3, 4, 5, 6}, 'Value', 1, ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.DDGradoLS, r);
            r = r + 1; app.etiqueta(g, r, 'Corrección drift:');
            app.DDDrift = uidropdown(g, ...
                'Items', {'Ninguna', 'Sesgo constante (MC grado 0)', 'Tendencia MC (grado elegido)', 'Reposo inicial'}, ...
                'ItemsData', {'ninguna', 'sesgo', 'tendencia', 'reposo'}, 'Value', 'sesgo', ...
                'Tooltip', 'Se resta a la aceleración antes de integrar (velocidad y posición)', ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.DDDrift, r);
            r = r + 1; app.etiqueta(g, r, 'Reposo inicial [s]:');
            app.SpnReposo = uispinner(g, 'Limits', [0.1 30], 'Value', 2, 'Step', 0.5, ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.SpnReposo, r);
            r = r + 1; app.etiqueta(g, r, 'Cilindros motor:');
            app.SpnCilindros = uispinner(g, 'Limits', [1 12], 'Value', 4, 'Step', 1, ...
                'RoundFractionalValues', 'on', 'Tooltip', 'rpm ≈ 120·f / cilindros (motor 4 tiempos)', ...
                'ValueChangedFcn', @(~,~) app.mostrarResultados());
            app.ubicar(app.SpnCilindros, r);
            r = r + 1; app.etiqueta(g, r, 'f mín. espectro [Hz]:');
            app.SpnFMin = uispinner(g, 'Limits', [0 49], 'Value', 5, 'Step', 0.5, ...
                'Tooltip', 'La frecuencia dominante se busca por encima de este valor (separa la vibración del movimiento lento)', ...
                'ValueChangedFcn', @(~,~) app.procesar());
            app.ubicar(app.SpnFMin, r);
            r = r + 1; app.etiqueta(g, r, 'Gráfica procesada:');
            app.DDVista = uidropdown(g, ...
                'Items', {'Señal + tendencia', 'Derivada (jerk)', 'Integral (velocidad)', 'EDO: v(t) y x(t)', 'Espectro (FFT)'}, ...
                'ItemsData', {'senal', 'derivada', 'integral', 'edo', 'espectro'}, 'Value', 'senal', ...
                'ValueChangedFcn', @(~,~) app.graficarProcesada());
            app.ubicar(app.DDVista, r);
            r = r + 1;
            app.BtnProcesar = uibutton(g, 'Text', '⚙ Procesar', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) app.procesar());
            app.BtnProcesar.Layout.Row = r; app.BtnProcesar.Layout.Column = [1 2];

            r = r + 1; app.seccion(g, r, '4. Guardar / exportar');
            r = r + 1; app.etiqueta(g, r, 'Nombre archivo:');
            app.EdtNombre = uieditfield(g, 'text', 'Value', 'resultados', ...
                'Placeholder', 'nombre del archivo');
            app.ubicar(app.EdtNombre, r);
            r = r + 1; app.etiqueta(g, r, 'Formato:');
            app.DDFormato = uidropdown(g, 'Items', {'Excel (.xlsx)', 'CSV (.csv)', 'MATLAB (.mat)'}, ...
                'ItemsData', {'.xlsx', '.csv', '.mat'}, 'Value', '.xlsx');
            app.ubicar(app.DDFormato, r);
            r = r + 1;
            app.ChkPNG = uicheckbox(g, 'Text', 'Incluir gráficas (PNG)', 'Value', true);
            app.ChkPNG.Layout.Row = r; app.ChkPNG.Layout.Column = [1 2];
            r = r + 1;
            app.BtnExportar = uibutton(g, 'Text', '💾 Exportar resultados', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) app.exportar());
            app.BtnExportar.Layout.Row = r; app.BtnExportar.Layout.Column = [1 2];

            r = r + 1; app.seccion(g, r, '5. Apariencia');
            r = r + 1; app.etiqueta(g, r, 'Tema:');
            app.DDTema = uidropdown(g, 'Items', {'Automático (MATLAB)', 'Claro', 'Oscuro'}, ...
                'ItemsData', {'auto', 'light', 'dark'}, 'Value', 'auto', ...
                'Tooltip', 'Requiere MATLAB R2025a o posterior', ...
                'ValueChangedFcn', @(~,~) app.cambiarTema());
            app.ubicar(app.DDTema, r);
            if ~(isprop(app.UIFigure, 'Theme') && exist('theme', 'file') > 0)
                app.DDTema.Enable = 'off';
            end
            app.GridControl.RowHeight = repmat({24}, 1, r);

            % ---------- Área derecha ----------
            app.GridDerecha = uigridlayout(app.GridPrincipal, [3 1], ...
                'RowHeight', {'1x', '1.25x', 150}, 'Padding', [0 0 0 0], 'RowSpacing', 6);
            app.GridDerecha.Layout.Row = 1; app.GridDerecha.Layout.Column = 2;

            app.AxOriginal = uiaxes(app.GridDerecha);
            title(app.AxOriginal, 'Señal original'); xlabel(app.AxOriginal, 't [s]');
            ylabel(app.AxOriginal, 'a [m/s^2]');

            app.Tabs = uitabgroup(app.GridDerecha);
            app.TabProcesada = uitab(app.Tabs, 'Title', 'Señal procesada');
            gp = uigridlayout(app.TabProcesada, [1 1], 'Padding', [2 2 2 2]);
            app.AxProcesada = uiaxes(gp);

            app.TabTiempoReal = uitab(app.Tabs, 'Title', 'Tiempo real / grabación');
            gt = uigridlayout(app.TabTiempoReal, [3 9], ...
                'RowHeight', {26, '1x', '1x'}, ...
                'ColumnWidth', {70, 80, 90, 55, 100, 110, 140, 22, '1x'}, 'Padding', [4 4 4 4]);
            l = uilabel(gt, 'Text', 'Velocidad:', 'HorizontalAlignment', 'right'); l.Layout.Row = 1; l.Layout.Column = 1;
            app.DDVelocidad = uidropdown(gt, 'Items', {'0.5x', '1x', '2x', '5x', '10x'}, ...
                'ItemsData', {0.5, 1, 2, 5, 10}, 'Value', 1);
            app.DDVelocidad.Layout.Row = 1; app.DDVelocidad.Layout.Column = 2;
            l = uilabel(gt, 'Text', 'Ventana [s]:', 'HorizontalAlignment', 'right'); l.Layout.Row = 1; l.Layout.Column = 3;
            app.SpnVentana = uispinner(gt, 'Limits', [1 60], 'Value', 5);
            app.SpnVentana.Layout.Row = 1; app.SpnVentana.Layout.Column = 4;
            app.BtnIniciar = uibutton(gt, 'Text', '▶ Iniciar', 'ButtonPushedFcn', @(~,~) app.iniciarPausarRT());
            app.BtnIniciar.Layout.Row = 1; app.BtnIniciar.Layout.Column = 5;
            app.BtnGrabar = uibutton(gt, 'Text', '● Iniciar grabación', 'FontColor', [0.85 0.20 0.20], ...
                'Enable', 'off', 'ButtonPushedFcn', @(~,~) app.iniciarGrabacion());
            app.BtnGrabar.Layout.Row = 1; app.BtnGrabar.Layout.Column = 6;
            app.BtnDetenerGrab = uibutton(gt, 'Text', '■ Terminar grabación', ...
                'Enable', 'off', 'ButtonPushedFcn', @(~,~) app.detenerGrabacion());
            app.BtnDetenerGrab.Layout.Row = 1; app.BtnDetenerGrab.Layout.Column = 7;
            app.LampGrabando = uilamp(gt, 'Color', [0.6 0.6 0.6]); app.LampGrabando.Layout.Row = 1; app.LampGrabando.Layout.Column = 8;
            app.LblRT = uilabel(gt, 'Text', 'Detenido', 'FontName', 'Consolas');
            app.LblRT.Layout.Row = 1; app.LblRT.Layout.Column = 9;
            app.AxRTa = uiaxes(gt); app.AxRTa.Layout.Row = 2; app.AxRTa.Layout.Column = [1 9];
            app.AxRTv = uiaxes(gt); app.AxRTv.Layout.Row = 3; app.AxRTv.Layout.Column = [1 9];

            app.TabValidacion = uitab(app.Tabs, 'Title', 'Validación de métodos');
            gv = uigridlayout(app.TabValidacion, [2 2], 'RowHeight', {28, '1x'}, ...
                'ColumnWidth', {'1.2x', '1x'}, 'Padding', [4 4 4 4]);
            app.BtnComparar = uibutton(gv, 'Text', '📊 Comparar todos los métodos', ...
                'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) app.comparar());
            app.BtnComparar.Layout.Row = 1; app.BtnComparar.Layout.Column = 1;
            l = uilabel(gv, 'Text', 'Error analítico solo con la señal de prueba; "Dif MATLAB" compara contra interp1, gradient, trapz, cumtrapz y polyfit.', ...
                'WordWrap', 'on', 'FontSize', 10);
            l.Layout.Row = 1; l.Layout.Column = 2;
            app.TblComparacion = uitable(gv, 'ColumnName', ...
                {'Proceso', 'Método', 'Resultado', 'Error vs analítica', 'Dif vs MATLAB'}, ...
                'ColumnWidth', {110, 160, 120, 110, 100}, 'RowName', {});
            app.TblComparacion.Layout.Row = 2; app.TblComparacion.Layout.Column = 1;
            app.AxErrores = uiaxes(gv);
            app.AxErrores.Layout.Row = 2; app.AxErrores.Layout.Column = 2;

            % ---------- Resultados ----------
            app.PanelResultados = uipanel(app.GridDerecha, 'Title', 'Resultados', 'FontWeight', 'bold');
            app.GridResultados = uigridlayout(app.PanelResultados, [5 6], ...
                'ColumnWidth', {125, '1x', 120, '1x', 120, '1x'}, 'RowHeight', repmat({20}, 1, 5), ...
                'RowSpacing', 3, 'Padding', [8 4 8 4]);
            campos = { ...
                'T',    'Duración total:';   'I',    '∫ a dt (integral):'; 'eq',  'Tendencia:'; ...
                'N',    'Muestras:';         'v',    'v final (EDO):';    'R2',  'R² / error est.:'; ...
                'fs',   'Muestreo:';         'x',    'x final (EDO):';    'f',   'Frec. dominante:'; ...
                'falt', 'Faltantes:';        'dy',   '|da/dt| máx:';      'pico','Pico |a|:'; ...
                'interp','Interpolados:';    'drift','Corrección drift:'; 'perd', 'Error interp. real:'};
            V = struct();
            for k = 1:size(campos, 1)
                fila = ceil(k / 3); col = 2*mod(k-1, 3) + 1;
                l = uilabel(app.GridResultados, 'Text', campos{k, 2}, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'right');
                l.Layout.Row = fila; l.Layout.Column = col;
                V.(campos{k, 1}) = uilabel(app.GridResultados, 'Text', '—');
                V.(campos{k, 1}).Layout.Row = fila; V.(campos{k, 1}).Layout.Column = col + 1;
            end
            app.Val = V;

            % ---------- Barra de estado ----------
            app.LblEstado = uilabel(app.GridPrincipal, 'Text', '', 'FontSize', 11);
            app.LblEstado.Layout.Row = 2; app.LblEstado.Layout.Column = [1 2];

            app.UIFigure.Visible = 'on';
        end

        function seccion(~, g, r, txt)
            l = uilabel(g, 'Text', txt, 'FontWeight', 'bold', 'FontColor', [0.20 0.50 0.85], ...
                'VerticalAlignment', 'bottom');
            l.Layout.Row = r; l.Layout.Column = [1 2];
        end

        function etiqueta(~, g, r, txt)
            l = uilabel(g, 'Text', txt, 'HorizontalAlignment', 'right');
            l.Layout.Row = r; l.Layout.Column = 1;
        end

        function ubicar(~, c, r)
            c.Layout.Row = r; c.Layout.Column = 2;
        end
    end

    %% ===================== Creación y eliminación =====================
    methods (Access = public)
        function app = AnalizadorVibracionesApp
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startupFcn);
            if nargout == 0, clear app; end
        end

        function delete(app)
            if ~isempty(app.Tmr) && isvalid(app.Tmr)
                stop(app.Tmr); delete(app.Tmr);
            end
            if isvalid(app.UIFigure), delete(app.UIFigure); end
        end
    end
end
