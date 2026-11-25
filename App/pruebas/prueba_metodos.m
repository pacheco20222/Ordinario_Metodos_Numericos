% PRUEBA_METODOS  Valida cada método contra solución analítica y contra
% las funciones internas de MATLAB/Octave. Calcula órdenes de convergencia.
clear; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'metodos'));

%% 1. Duración
s = nm_senal_prueba(10, 100, 0.03);
d = nm_duracion(s.t);
fprintf('1) Duración: T=%.4f s, N=%d, fs=%.2f Hz\n', d.T, d.N, d.fs);
chk(abs(d.T-10)<1e-12 && abs(d.fs-100)<1e-9, 'duración y fs correctas');

%% 2. Faltantes + interpolación
fprintf('2) Faltantes e interpolación\n');
r0 = nm_detectar_faltantes(s.t, s.a);
fprintf('   NaN=%d, huecos=%d, faltantes en malla=%d (malla N=%d)\n', r0.nNaN, r0.nHuecos, r0.nFaltantes, numel(r0.malla));
chk(numel(r0.malla)==1001, 'malla uniforme reconstruida 1001 puntos');
met = {'lineal','lagrange','spline'};
for i=1:3
  [yu, r] = nm_interpolar(s.t, s.a, met{i});
  e = max(abs(yu - s.aRef)); ef = max(abs(yu(r.esFaltante) - s.aRef(r.esFaltante)));
  fprintf('   %-9s error máx global=%.2e | en faltantes=%.2e\n', met{i}, e, ef);
end
ys = nm_spline_natural(r0.tValido, r0.yValido, r0.malla);
ym = interp1(r0.tValido, r0.yValido, r0.malla, 'spline');
fprintf('   spline propio vs interp1(spline) (not-a-knot): dif máx=%.2e\n', max(abs(ys-ym)));
yl = nm_interpolar(s.t, s.a, 'lineal');
chk(max(abs(yl - interp1(r0.tValido, r0.yValido, r0.malla)))<1e-12, 'lineal propia == interp1 lineal');

%% 3. Derivada: orden de convergencia con f = sin(t)
fprintf('3) Derivada (f=sin t en [0,2pi]) — error máx y orden observado\n');
mets = {'adelante','atras','centrada','cinco'}; esper=[1 1 2 4];
hs = [0.1 0.05 0.025 0.0125];
for i=1:4
  E = zeros(size(hs));
  for j=1:numel(hs)
    x = (0:hs(j):2*pi)'; E(j) = max(abs(nm_derivada(sin(x), hs(j), mets{i}) - cos(x)));
  end
  p = polyfit(log(hs), log(E), 1);
  fprintf('   %-9s E(h=0.1)=%.2e  orden≈%.2f (teórico %d)\n', mets{i}, E(1), p(1), esper(i));
  chk(abs(p(1)-esper(i))<0.3, sprintf('orden %s', mets{i}));
end
x=(0:0.01:1)'; y=x.^3;
dc = nm_derivada(y,0.01,'centrada'); gg = gradient(y,0.01);
chk(max(abs(dc(2:end-1) - gg(2:end-1)))<1e-12, 'centrada == gradient (interior)');

%% 4. Integral: orden y exactitud polinomial
fprintf('4) Integral (∫_0^pi sin = 2)\n');
mets = {'trapecio','simpson13','simpson38'}; esper=[2 4 4];
ns = [12 24 48 96];  % intervalos, múltiplos de 6
for i=1:3
  E=zeros(size(ns)); H=pi./ns;
  for j=1:numel(ns)
    x=linspace(0,pi,ns(j)+1)'; E(j)=abs(nm_integral(sin(x), H(j), mets{i}) - 2);
  end
  p=polyfit(log(H),log(E),1);
  fprintf('   %-9s E(n=12)=%.2e  orden≈%.2f (teórico %d)\n', mets{i}, E(1), p(1), esper(i));
  chk(abs(p(1)-esper(i))<0.3, sprintf('orden %s', mets{i}));
end
x=linspace(0,1,8)'; h=x(2)-x(1);   % 7 intervalos (impar y no múltiplo de 3)
chk(abs(nm_integral(x.^3,h,'simpson13')-0.25)<1e-13, 'Simpson 1/3 (+3/8) exacto para cúbica con n impar');
chk(abs(nm_integral(x.^3,h,'simpson38')-0.25)<1e-13, 'Simpson 3/8 (+1/3) exacto para cúbica n=7');
for nn=4:12, x=linspace(0,1,nn)'; h=x(2)-x(1); e38(nn)=abs(nm_integral(x.^3,h,'simpson38')-0.25); e13(nn)=abs(nm_integral(x.^3,h,'simpson13')-0.25); end
chk(max(e38)<1e-13 && max(e13)<1e-13, 'ambas Simpson exactas para cúbicas con 3..11 intervalos');
x=linspace(0,1,101)'; h=0.01; y=exp(x);
[I,Ia]=nm_integral(y,h,'trapecio'); chk(abs(I-trapz(x,y))<1e-12 && max(abs(Ia-cumtrapz(x,y)))<1e-12, 'trapecio == trapz/cumtrapz');
[I,Ia]=nm_integral(y,h,'simpson13'); chk(abs(Ia(end)-I)<1e-12 && max(abs(Ia-(exp(x)-1)))<1e-8, 'Simpson acumulada consistente');

%% 5. Mínimos cuadrados
fprintf('5) Mínimos cuadrados\n');
t=(0:0.1:10)'; y = 3 - 0.5*t + 0.2*t.^2;
for g=1:4
  r = nm_minimos_cuadrados(t, y, g); pp = polyfit(t,y,g);
  fprintf('   grado %d: R2=%.6f, |p - polyfit|max=%.2e, cond(N)=%.1f\n', g, r.R2, max(abs(r.p-pp)), r.cond);
end
r = nm_minimos_cuadrados(t,y,2); chk(abs(r.R2-1)<1e-12 && max(abs(r.p-[0.2 -0.5 3]))<1e-10, 'recupera coeficientes exactos grado 2');
chk(max(abs(nm_evaluar_tendencia(r,t)-y))<1e-10, 'evaluación de tendencia');
A=rand(5); b=rand(5,1); chk(norm(nm_gauss_pivoteo(A,b)-A\b)<1e-10, 'Gauss con pivoteo == A\\b');

%% 6. EDO: velocidad y posición desde aceleración
fprintf('6) EDO dx/dt=v, dv/dt=a (señal analítica, fs=100)\n');
t=s.tRef; a=s.aRef;
for m = {'euler','heun','rk4'}
  [v,xx] = nm_edo_movimiento(t,a,m{1});
  fprintf('   %-6s err máx v=%.2e  err máx x=%.2e\n', m{1}, max(abs(v-s.vRef)), max(abs(xx-s.xRef)));
end
fprintf('   orden observado (error máx en x(t)):\n');
for m = {'euler','heun','rk4'}
  E=[]; H=[0.02 0.01 0.005];
  for h=H
    tt=(0:h:10)'; aa=s.A*sin(s.w*tt)+s.b0+s.b1*tt; [~,xx]=nm_edo_movimiento(tt,aa,m{1});
    xr=s.A/s.w*(tt-sin(s.w*tt)/s.w)+s.b0*tt.^2/2+s.b1*tt.^3/6;
    E(end+1)=max(abs(xx-xr));
  end
  p=polyfit(log(H),log(E),1); fprintf('     %-6s orden≈%.2f\n', m{1}, p(1));
end
fprintf('\nFin de pruebas.\n');

