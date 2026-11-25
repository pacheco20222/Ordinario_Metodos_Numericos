function D = nm_cargar_datos(archivo)
% NM_CARGAR_DATOS  Lee datos de aceleración de distintos formatos:
%   * CSV/XLSX de phyphox ("Time (s)", "Acceleration x (m/s^2)", ...)
%   * .mat de MATLAB Mobile (timetable "Acceleration" con X, Y, Z)
%   * CSV/XLSX genérico: 1a columna = tiempo [s], siguientes = señales
%   D.t (s), D.Y (matriz N x k), D.nombres (cell 1 x k), D.archivo
[~, nombre, ext] = fileparts(archivo);
D.archivo = [nombre ext];
switch lower(ext)
    case '.mat'
        S = load(archivo);
        if isfield(S, 'Acceleration')
            TT = S.Acceleration;
            if istimetable(TT)
                tt = TT.Properties.RowTimes;
                if isdatetime(tt), t = seconds(tt - tt(1)); else, t = seconds(tt); end
                D.t = t(:);
                D.Y = [TT.X TT.Y TT.Z];
            else
                D.t = TT(:,1); D.Y = TT(:,2:end);
            end
            D.nombres = {'a_x','a_y','a_z'};
        else
            f = fieldnames(S); M = S.(f{1});
            D.t = M(:,1); D.Y = M(:,2:end);
            D.nombres = arrayfun(@(k) sprintf('Señal %d',k), 1:size(D.Y,2), 'UniformOutput', false);
        end
    case {'.csv', '.txt', '.xlsx', '.xls'}
        if exist('readtable', 'file') || exist('readtable', 'builtin')
            T = readtable(archivo, 'VariableNamingRule', 'preserve');
            M = table2array(T(:, varfun(@isnumeric, T, 'OutputFormat', 'uniform')));
            nombresVar = T.Properties.VariableNames(varfun(@isnumeric, T, 'OutputFormat', 'uniform'));
        else    % respaldo (Octave): CSV numérico con encabezado
            fid = fopen(archivo); enc = fgetl(fid); fclose(fid);
            nombresVar = strtrim(strsplit(strrep(enc, '"', ''), ','));
            M = dlmread(archivo, ',', 1, 0, 'emptyvalue', NaN);
        end
        D.t = M(:,1);
        D.Y = M(:,2:end);
        D.nombres = nombresVar(2:end);
    otherwise
        error('nm_cargar_datos:formato', 'Formato no soportado: %s', ext);
end
D.t = D.t(:) - D.t(1);          % el tiempo inicia en 0
% Agregar magnitud |a| si hay 3 ejes de aceleración
if size(D.Y,2) >= 3 && ~any(contains_mag(D.nombres))
    D.Y(:, end+1) = sqrt(sum(D.Y(:,1:3).^2, 2));
    D.nombres{end+1} = '|a| (magnitud)';
end
end

function tf = contains_mag(nombres)
tf = false(size(nombres));
for i = 1:numel(nombres)
    n = lower(nombres{i});
    tf(i) = ~isempty(strfind(n, 'absolute')) || ~isempty(strfind(n, 'magnitud'));
end
end
