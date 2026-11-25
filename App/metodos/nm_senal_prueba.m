function s = nm_senal_prueba(T, fs, pFaltantes, ruido, semilla)
% NM_SENAL_PRUEBA  Señal sintética de aceleración con solución analítica,
% para validar todos los métodos:
%   a(t) = A sin(w t) + b0 + b1 t          (oscilación + drift lineal)
%   v(t) = A/w (1 - cos w t) + b0 t + b1 t^2/2         (v(0)=0)
%   x(t) = A/w (t - sin(w t)/w) + b0 t^2/2 + b1 t^3/6  (x(0)=0)
%   a'(t)= A w cos(w t) + b1
%   Se eliminan aleatoriamente pFaltantes (fracción) de las muestras en
%   forma de NaN y de huecos temporales.
if nargin < 1 || isempty(T), T = 10; end
if nargin < 2 || isempty(fs), fs = 100; end
if nargin < 3 || isempty(pFaltantes), pFaltantes = 0.03; end
if nargin < 4 || isempty(ruido), ruido = 0; end
if nargin < 5 || isempty(semilla), semilla = 7; end
rng(semilla);
A = 2.0; f = 1.37;   % 13.7 ciclos en 10 s (no entero, ver bitácora)
w = 2*pi*f; b0 = 0.05; b1 = 0.01;
t = (0:1/fs:T)';
s.A = A; s.w = w; s.b0 = b0; s.b1 = b1;
s.tRef = t;
s.aRef = A*sin(w*t) + b0 + b1*t;
s.vRef = A/w*(1 - cos(w*t)) + b0*t + b1*t.^2/2;
s.xRef = A/w*(t - sin(w*t)/w) + b0*t.^2/2 + b1*t.^3/6;
s.daRef = A*w*cos(w*t) + b1;
s.integralRef = s.vRef(end);
a = s.aRef + ruido*randn(size(t));
n = numel(t);
nF = round(pFaltantes * n);
% mitad como NaN, mitad como hueco temporal (muestras eliminadas)
idx = randperm(n-2, nF) + 1;
iNaN = idx(1:floor(nF/2));
iHueco = idx(floor(nF/2)+1:end);
a(iNaN) = NaN;
mantener = true(n,1); mantener(iHueco) = false;
s.t = t(mantener);
s.a = a(mantener);
end
