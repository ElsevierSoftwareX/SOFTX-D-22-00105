function [pde, mesh] = pdeparams(pde,mesh)

%% User defined parameters
%Planet
planet = "Earth";
%Set species 
nspecies = 4;

%start of simulation
date = [2002, 3, 18];       %% year month day
hour = [00, 00, 00];        %% HH MM SS (24h format)

%Length of simulation (days)
tSimulation = 5;
%timeStep (s)
tstep = [1,2,5];
tpoints = [1,6];    %in hours
%frequency of data (minutes)
freq = 5;
%Restart at given time step
tRestart = 0;

%Polynomial order
porder = 2;
%Stabilization parameter
tauA = 5;

%EUV parameters
EUVeff = 0.21;
F10p7 = 150;
F10p7a = 150;

%Domain of interest
L = 500e3;
hbot = 100e3;     %height inner surface (km)
htop = hbot+L;     %height outer surface (km)
lambda0 = 1e-9;   %reference wavelength (1nm=1e-9m)

%Calculations
year = date(1);
doy = day(datetime(date),'dayofyear');
sec = hour(3) + 60*(hour(2) + 60*hour(1));
Nday = doy + sec/86400;

%Define species
species = ["O"; "N2"; "O2"; "He"];
indicesMSIS = [2;3;4;1];
species = species(1:nspecies);
indicesMSIS = indicesMSIS(1:nspecies);

%% Read input csv files
addpath('inputs');
load('inputCSV.mat','orbits','neutrals','EUV');

%Planet information
iPlanet = strcmp(string(table2array(orbits(:,1))),planet);
periodDay = table2array(orbits(iPlanet,14))*3600;
radius = table2array(orbits(iPlanet,18))*1e3;
radiusIn = radius+hbot;
radiusOut= radius+htop;
planetMass = table2array(orbits(iPlanet,17));
declinationSun = table2array(orbits(iPlanet,20));
clear orbits

%Species information
iSpecies = zeros(nspecies,1);
iSpeciesEUV = zeros(nspecies,1);
for isp = 1:nspecies
    iSpecies(isp) = find(strcmp(string(table2array(neutrals(:,1))),species(isp)));
    iSpeciesEUV(isp) = find(strcmp(table2array(EUV(:,2)),species(isp)));
end

amu = 1.66e-27;
mass = table2array(neutrals(iSpecies,2))*amu;
ckappa0 = table2array(neutrals(iSpecies,4));% + 2e-4;
expKappa = table2array(neutrals(iSpecies(1),5));
expKappa = 0.75;

lambda_d = (0.5*(table2array(EUV(1,6:42))+table2array(EUV(2,6:42))))*1e-10;    % initially in Armstrongs
AFAC = table2array(EUV(4,6:42));
F74113_d = table2array(EUV(3,6:42))*table2array(EUV(3,4))*1e4;    %1/(m2*s)
crossSections_d = table2array(EUV(iSpeciesEUV,6:42)).*table2array(EUV(iSpeciesEUV,4));     %m2

clear neutrals
clear EUV

%% Reference values
m = mass(1);
gam = 5/3;
%MSIS reference values
[rho0,T0,chi,cchi] = MSIS_referenceValues(indicesMSIS,mass,hbot,htop,year,doy,sec,F10p7,F10p7a);

%% Physical quantities
kBoltzmann = 1.38e-23;
hPlanck = 6.0626e-34;
c = 3e8;
gravitationalConstant = 6.674e-11;
R = kBoltzmann/m;
g = gravitationalConstant*planetMass/radiusIn^2;
omega = 2*pi/periodDay;
cp = gam*R/(gam-1);
H = R*T0/g;

%Reference quantities
v0 = sqrt(gam*R*T0);
t0 = H/v0;
R0 = radiusIn/H;
R1 = radiusOut/H;

%Viscosity and conductivity
cmu0 = 1.3e-4;
expMu = 0.5;
ckappai = ckappa0/(chi(1,:)*ckappa0);
kappa0 = chi(1,:)*ckappa0*T0^expKappa;
alpha0 = 0.45*kappa0/(rho0*cp);
mu0 = cmu0*(T0/R)^expMu;
nu0 = mu0/rho0;

nuEddy = 1000;
alphaEddy = 30;

%Parameters for EUV
lambda = lambda_d/lambda0;
crossSections = crossSections_d/H^2;
F74113 = F74113_d*(H^2*t0);
mass = mass/m;

%Nondimensional quantities
Gr = g*H^3/nu0^2;
Pr = nu0/alpha0;
Fr = sqrt(omega^2*H/g);

Keuv = (gam*kBoltzmann*T0)/(hPlanck*c/lambda0);
M = rho0*H^3/m;

%% Time parameters;
tstepStar = tstep/t0;

tend = tSimulation*periodDay;
tpoints = [0,tpoints*3600,tend];
tintervals = tpoints(2:end)-tpoints(1:end-1);
nTimeStepsI = ceil(tintervals./tstep);
nTimeSteps = sum(nTimeStepsI);
dt = [];
soltime = [];
soltime0 = 0;
freqTimeSteps = ceil(freq*60./tstep);
for it = 1:length(tintervals)
    dt = [dt; tstep(it)/t0*ones(nTimeStepsI(it),1)];
    soltime = [soltime, soltime0 + freqTimeSteps(it):freqTimeSteps(it):nTimeStepsI(it)];
    soltime0 = soltime(end);
end

% Set discretization parameters, physical parameters, and solver parameters
pde.porder = porder;          % polynomial degree
pde.torder = 2;          % time-stepping order of accuracy
pde.nstage = 2;          % time-stepping number of stages
pde.dt = dt;   % time step sizes
pde.visdt = freq*60;         % visualization timestep size
pde.saveSolFreq = min(freqTimeSteps);          % solution is saved every 100 time steps
pde.soltime = soltime; % steps at which solution are collected
pde.timestepOffset = tRestart;


%% Vectors of physical and external parameters
pde.physicsparam = [gam Gr Pr Fr Keuv  M EUVeff declinationSun F10p7 F10p7a Nday expMu expKappa nuEddy alphaEddy R0 R1 H T0 rho0 t0, tauA, year];
                   
% External params (EUV)
pde.externalparam = [lambda,AFAC,F74113,reshape(crossSections',[37*nspecies,1])',reshape(cchi',[4*(nspecies-1),1])',mass',ckappai'];
        

%% Solver parameters
pde.extStab = 1;
pde.tau = 0.0;                  % DG stabilization parameter
pde.GMRESrestart=19;            % number of GMRES restarts
pde.linearsolvertol=1e-16;      % GMRES tolerance
pde.linearsolveriter=20;        % number of GMRES iterations
pde.precMatrixType=2;           % preconditioning type
pde.NLtol = 1e-10;              % Newton tolerance
pde.NLiter = 4;                 % Newton iterations
pde.matvectol = 1e-4;
pde.RBdim = 10;
pde.matvecorder = 2;

%% Grid
addpath('meshes');
[mesh.p,mesh.t, mesh.dgnodes] = sphereCubeAdapted(pde.porder, R0, R1);
% [mesh.p,mesh.t, mesh.dgnodes] = sphereCube_LES(pde.porder, R0, R1);
% expressions for domain boundaries
mesh.boundaryexpr = {@(p) abs(p(1,:).^2+p(2,:).^2+p(3,:).^2-R0^2)<1e-6, @(p) abs(p(1,:).^2+p(2,:).^2+p(3,:).^2-R1^2)<1e-6};
mesh.boundarycondition = [1 2];  % Inner, Outer

%% Initial condition
[npoint,ndim,nelem] = size(mesh.dgnodes);
ndg = npoint*nelem;
ncu = 5;
nc = ncu*(ndim+1);
xdg = reshape(pagetranspose(mesh.dgnodes),[ndim,ndg])';

paramsMSIS = [R0,R1,year,doy,sec,F10p7,F10p7a,hbot,H,T0,rho0,Fr,m];
u0 = MSIS_initialCondition3D_pressure(xdg,paramsMSIS,indicesMSIS,mass);
u0 = pagetranspose(reshape(u0',[nc,npoint,nelem]));
mesh.udg = u0;

