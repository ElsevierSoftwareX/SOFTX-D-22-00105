function [p,t] = templateTL2ref4(x0, y0, z0, x1, y1, z1)


xa = (x0 + x1)/2;
za = (z0 + z1)/2;
ya = (3*y0 + y1)/4;
yb = (y0 + y1)/2;


xp = [x0 x1 x0 x1 x0 xa x1 x1 x0 xa x0 xa x0 xa x0 xa x1 x0 xa x1 x0 xa x1];
yp = [y1 y1 y1 y1 yb yb yb yb yb yb ya ya ya ya y0 y0 y0 y0 y0 y0 y0 y0 y0];
zp = [z0 z0 z1 z1 z0 z0 za z1 z1 z1 za za z1 z1 z0 z0 z0 za za za z1 z1 z1];
zp = z1-zp;

p = [xp' yp' zp'];
t = [3 9 10 4 1 5 6 2;...
    12 19 20 7 6 16 17 2;
    10 14 8 4 6 12 7 2;
    14 22 23 8 12 19 20 7;
    9 13 14 10 5 11 12 6;
    11 18 19 12 5 15 16 6;
    13 21 22 14 11 18 19 12];


%ptplot(p,t);