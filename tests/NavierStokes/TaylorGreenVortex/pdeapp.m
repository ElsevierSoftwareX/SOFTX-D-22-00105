% Add Exasim to Matlab search path
cdir = pwd(); ii = strfind(cdir, "Exasim");
run(cdir(1:(ii+5)) + "/Installation/setpath.m");

% initialize pde structure and mesh structure
[pde,mesh] = initializeexasim();

% Define a PDE model: governing equations, initial solutions, and boundary conditions
pde.model = "ModelD";          % ModelC, ModelD, ModelW
pde.modelfile = "pdemodel";    % name of a file defining the PDE model

% Choose computing platform and set number of processors
%pde.platform = "gpu";         % choose this option if NVIDIA GPUs are available
pde.mpiprocs = 4;              % number of MPI processors

% Set discretization parameters, physical parameters, and solver parameters
pde.porder = 3;          % polynomial degree
pde.torder = 2;          % time-stepping order of accuracy
pde.nstage = 2;          % time-stepping number of stages
pde.dt = 0.05*ones(1,50);   % time step sizes
pde.soltime = 10:10:50; % steps at which solution are collected
pde.visdt = 0.05; % visualization timestep size

gam = 1.4;                      % specific heat ratio
Re = 1600;                      % Reynolds number
Pr = 0.71;                      % Prandtl number    
Minf = 0.2;                     % Mach number
pde.physicsparam = [gam Re Pr Minf];
pde.tau = 2.0;                  % DG stabilization parameter
pde.GMRESrestart=40;
pde.linearsolvertol=0.0001;
pde.linearsolveriter=41;
pde.precMatrixType=2;
pde.NLiter=2;

% create a grid of 10 by 10 on the unit square
[mesh.p,mesh.t] = cubemesh(16,16,16,1);
mesh.p = 2*pi*mesh.p;
% expressions for domain boundaries
mesh.boundaryexpr = {@(p) abs(p(2,:))<1e-8, @(p) abs(p(1,:)-2*pi)<1e-8, @(p) abs(p(2,:)-2*pi)<1e-8, @(p) abs(p(1,:))<1e-8, @(p) abs(p(3,:))<1e-8, @(p) abs(p(3,:)-2*pi)<1e-8};
mesh.boundarycondition = [1;1;1;1;1;1];
% Set periodic boundary conditions
mesh.periodicexpr = {2, @(p) p([2 3],:), 4, @(p) p([2 3],:); 1, @(p) p([1 3],:), 3, @(p) p([1 3],:); 5, @(p) p([1 2],:), 6, @(p) p([1 2],:)};

% call exasim to generate and run C++ code to solve the PDE model
[sol,pde,mesh] = exasim(pde,mesh);

