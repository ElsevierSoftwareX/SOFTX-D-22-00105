function pde = pdemodel
pde.mass = @mass;
pde.flux = @flux;
pde.source = @source;
pde.fbou = @fbou;
pde.ubou = @ubou;
pde.initu = @initu;
pde.stab = @stab;
end

function m = mass(u, q, w, v, x, t, mu, eta)
 m = sym([1.0; 1.0; 1.0]); 
end

function f = flux(u, q, w, v, x, t, mu, eta)
    fi = fluxInviscid(u,mu);
    fv = fluxViscous(u,q,x,mu);
      
    f = fi+fv;
end

function f = fluxWall(u, q, w, v, x, t, mu, eta)
    fi = fluxInviscidWall(u,mu);
    fv = fluxViscousWall(u,q,x,mu);
      
    f = fi+fv;
end

function s = source(u, q, w, v, x, t, mu, eta)
    x1 = x(1);
    c0 = mu(14);

    gam = mu(1);
    gam1 = gam-1;
    Gr = mu(2);
    Pr = mu(3);
    c23 = 2.0/3.0;
    
    r = u(1);
    vx = u(2);
    T = u(3);
    
    rho = exp(r);
    sr = sqrt(rho);
    r1 = 1/rho;
    r_1 = r-1;
    
    p = T/gam;
    
    drdx  = -q(1);
    dvxdx = -q(2);
    dTdx = -q(3);
    
    % Viscosity
    mustar = sqrt(T);
    kstar = T^0.75;
    nu = mustar*r1/sqrt(gam*Gr);
    fc = kstar*r1*sqrt(gam/Gr)/Pr;
    
    trr = nu*c23*2*dvxdx - c23*c0*vx/x1;
    trd = nu*2*c0*(dvxdx-vx/x1)/x1;
    
    R0 = mu(10);
    gravity0 = 1/gam;
    gravity = gravity0*R0^2/(x1^2);
    Fr = mu(4);
    ar = -gravity + x1*Fr^2/gam;
    
    trp = 2*c23*nu*(dvxdx^2 - c0*vx*dvxdx/x1 + 0.5*c0*(3-c0)*vx^2/x1^2);
    SigmadV = gam*gam1*trp;
    
    q_EUV = EUVsource1D(u, x, t, mu, eta);
    
    s = [r_1*dvxdx - c0*vx/x1; ...
        ar + dvxdx*vx - p*drdx + trr*drdx + trd; ...
        q_EUV + (2-gam)*T*dvxdx + c0*(1-gam)*T*vx/x1 + fc*dTdx*(c0/x1 + drdx) + SigmadV];
end

function fb = fbou(u, q, w, v, x, t, mu, eta, uhat, n, tau)
    tau = gettau(uhat, mu, eta, n);

    f = fluxWall(u, q, w, v, x, t, mu, eta);
    fw = f*n; % numerical flux at freestream boundary
    fw(1) = fw(1) + tau(1)*(u(1)-uhat(1));
    fw(2) = fw(2) + tau(2)*(u(2)-uhat(2));
    fw(3) = fw(3) + tau(3)*(u(3)-uhat(3));
    
    % Inviscid outer boundary
    fi2 = fluxInviscid(u,mu);
    ft = fi2*n;    
    ft(1) = ft(1) + tau(1)*(u(1)-uhat(1));
    ft(2) = ft(2) + tau(2)*(u(2)-uhat(2));
    ft(3) = ft(3) + tau(3)*(u(3)-uhat(3));
    
    fb = [fw ft];
end

function ub = ubou(u, q, w, v, x, t, mu, eta, uhat, n, tau)
    Tbot = mu(8);

    % Isothermal Wall
    r = u(1);
    utw1 = u;
    utw1(2) = 0.0;
    utw1(3) = Tbot;

    % Inviscid wall
    utw2 = u;
        
    ub = [utw1 utw2];
end


function u0 = initu(x, mu, eta)
    x1 = x(1);
    
    Fr = mu(4);

    Tbot = mu(8);
    Ttop = mu(9);
    R0 = mu(10);
    Ldim = mu(12);
    h0 = 35000/Ldim;

    a0 = (-1 + Fr^2*R0);
    
    T = Ttop - (Ttop-Tbot)*exp(-(x1-R0)/h0);
    logp_p0 = a0*h0/Ttop*log(1+Ttop/Tbot*(exp((x1-R0)/h0)-1));
    rtilde = logp_p0 - log(T);
    
    u0 = sym([rtilde; 0.0; T]);
end


function ftau = stab(u1, q1, w1, v1, x, t, mu, eta, uhat, n, tau, u2, q2, w2, v2) 
    uhat = 0.5*(u1+u2);
    tau = gettau(uhat, mu, eta, n);
    
    ftau(1) = tau(1)*(u1(1) - u2(1));
    ftau(2) = tau(2)*(u1(2) - u2(2));
    ftau(3) = tau(3)*(u1(3) - u2(3));
end


function fi = fluxInviscid(u,mu)
    gam = mu(1);    
    r = u(1);
    vx = u(2);
    T = u(3);
    p = T/gam;

    fi = [r*vx; vx*vx+p; T*vx];
end

function fi = fluxInviscidWall(u,mu)
    gam = mu(1);

    Tbot = mu(8);
    p = Tbot/gam;

    fi = [0; p; 0];
end


function fv = fluxViscous(u,q,x,mu)
    x1 = x(1);
    c0 = mu(14);
    
    gam = mu(1);
    Gr = mu(2);
    Pr = mu(3);
    c23 = 2.0/3.0;
    
    r = u(1);
    vx = u(2);
    T = u(3);
    
    rho = exp(r);
    r1 = 1/rho;
        
    dvxdx = -q(2);
    dTdx = -q(3);

    % Viscosity
    mustar = sqrt(T);
    kstar = T^0.75;
    nu = mustar*r1/sqrt(gam*Gr);
    fc = kstar*r1*sqrt(gam/Gr)/Pr;
    
    trr = nu*c23*2*dvxdx - c23*c0*vx/x1;
    
    fv = [0; -trr; -fc*dTdx];
end

function fv = fluxViscousWall(u,q,x,mu)
    x1 = x(1);
    c0 = mu(14);
    
    gam = mu(1);
    Gr = mu(2);
    Pr = mu(3);
    c23 = 2.0/3.0;
    
    r = u(1);    
    rho = exp(r);
    r1 = 1/rho;
    vx = 0.0;
    T = mu(8);
        
    dvxdx = -q(2);
    dTdx = -q(3);

    % Viscosity
    mustar = sqrt(T);
    kstar = T^0.75;
    nu = mustar*r1/sqrt(gam*Gr);
    fc = kstar*r1*sqrt(gam/Gr)/Pr;
    
    trr = nu*c23*2*dvxdx - c23*c0*vx/x1;
    
    fv = [0; -trr; -fc*dTdx];
end

function   tau = gettau(uhat, mu, eta, n)
    gam = mu(1);
    Gr = mu(2);
    Pr = mu(3);
    
    r = uhat(1);
    vx = uhat(2);
    T = uhat(3);
    
    rho = exp(r);
    r1 = 1/rho;

    c = sqrt(T);
    
%     tauA = sqrt(vx*vx) + c;
    tauA = mu(18);
    
    % Viscosity
    mustar = sqrt(T);
    kstar = T^0.75;
    tauDv = mustar*r1/sqrt(gam*Gr);
    tauDT = kstar*r1*sqrt(gam/Gr)/Pr;
    
    tau(1) = tauA;
    tau(2) = tauA + tauDv;
    tau(3) = tauA + tauDT; 
end