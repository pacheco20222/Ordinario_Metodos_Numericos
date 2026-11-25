function esAtip = nm_hampel(y, k, nsig)
% NM_HAMPEL  Detecta valores atípicos con el filtro de Hampel.
%   Para cada muestra i se toma la ventana y(i-k : i+k) (sin NaN) y se
%   calcula la mediana m_i y la desviación absoluta mediana MAD_i.
%   La muestra es atípica si  |y_i - m_i| > nsig * 1.4826 * MAD_i
%   (1.4826*MAD estima la desviación estándar de una distribución normal
%   y, a diferencia de ella, no se contamina con el propio valor atípico).
if nargin < 2 || isempty(k), k = 25; end
if nargin < 3 || isempty(nsig), nsig = 5; end
y = y(:); n = numel(y);
esAtip = false(n, 1);
for i = 1:n
    if isnan(y(i)), continue; end
    w = y(max(1, i-k):min(n, i+k));
    w = w(~isnan(w));
    m = median(w);
    s = 1.4826 * median(abs(w - m));
    if s > 0 && abs(y(i) - m) > nsig * s
        esAtip(i) = true;
    end
end
end
