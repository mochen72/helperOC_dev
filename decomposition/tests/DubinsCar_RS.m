function DubinsCar_RS(gN, whichComputation)
% DubinsCar_RS()
%     Compares reachable set/tube computation using direct and decomposition
%     methods
%
% Inputs:
%     gN - Number of grid points per dimension 

%% Default parameters
if nargin < 1
  gN = 25;
end

if nargin < 2
  whichComputation = 'intersect_set';
end

%% Problem parameters common to both subsystems
small = 0.01;
targetLower = [-0.5; -0.5; -inf];
targetUpper = [0.5; 0.5; inf];   
    
% 3D Grid
gMin = [-1.25; -1.25; 0];
gMax = [1.25; 1.25; 2*pi];
tube = false;
uMode = 'max';
dMode = 'min';
gN = gN*ones(3,1);

% Time
tMax = 0.5;
dt = 0.01;

% Vehicle
wMax = 1;
speed = 1;
dMax = [0; 0; 0];

%% Dynamical system and subsystem dimensions
XTdims = [1 3]; % (x, \theta) dimensions
YTdims = [2 3]; % (y, \theta) dimensions

% Set to true to specify the target set to be between targetLower and 
% targetUpper
target_inside = true; 

% Reconstruction type: set to 'max' to take intersection of back projections,
% 'min' to take the union of back projections
constrType = 'max';

%% Computing the reachable set
switch whichComputation
  case 'intersect_set'

  case 'union_set'
    uMode = 'min';
    dMode = 'max';
    target_inside = false;
    constrType = 'min';
    targetLower = [-inf; -inf; -inf];
    targetUpper = [0.5; 0.5; inf];       
    
  case 'intersect_tube'
    tube = true;
    dt = 0.005;
    
  case 'dstb_uncoupled'
    dMax = [1; 1; 0];
    tube = true;
    dt = 0.005;
    gMin = [-1.75; -1.75; 0];
    gMax = [1.75; 1.75; 2*pi];
    
  case 'dstb_coupled'
    dMax = [1; 1; 5];
    tube = true;
    dt = 0.005;
    gMin = [-1.75; -1.75; 0];
    gMax = [1.75; 1.75; 2*pi];  
    
  otherwise
    error('Unknown computation!')
end

tau = 0:dt:tMax; % Times at which to obtain the solution

%% Grids and initial conditions
g = createGrid(gMin, gMax, gN, 3);
gXT = createGrid(gMin(XTdims), gMax(XTdims), gN(XTdims), 2);
gYT = createGrid(gMin(YTdims), gMax(YTdims), gN(YTdims), 2);

data0 = shapeRectangleByCorners(g, targetLower, targetUpper);
dataXT0 = shapeRectangleByCorners(gXT, targetLower(XTdims), ...
  targetUpper(XTdims));
dataYT0 = shapeRectangleByCorners(gYT, targetLower(YTdims), ...
  targetUpper(YTdims));

if ~target_inside
  data0 = -data0;
  dataXT0 = -dataXT0;
  dataYT0 = -dataYT0;
end

%% Additional solver parameters
sD_full.grid = g; % 3D grid
sD_XT.grid = gXT; % (x, \theta) grid
sD_YT.grid = gYT; % (y, \theta) grid

% Dynamical systems
sD_full.dynSys = DubinsCar([0;0;0], wMax, speed, dMax); % 3D system
sD_XT.dynSys = DubinsCar([0;0;0], wMax, speed, dMax, XTdims); % (x, \theta)
sD_YT.dynSys = DubinsCar([0;0;0], wMax, speed, dMax, YTdims); % (y, \theta)

sD_full.uMode = uMode;
sD_XT.uMode = uMode;
sD_YT.uMode = uMode;
sD_full.dMode = dMode;
sD_XT.dMode = dMode;
sD_YT.dMode = dMode;
extraArgs.visualize = true;
extraArgs.deleteLastPlot = true;

dataXT = HJIPDE_solve(dataXT0, tau, sD_XT, 'none', extraArgs);
dataYT = HJIPDE_solve(dataYT0, tau, sD_YT, 'none', extraArgs);

if tube
  data = HJIPDE_solve(data0, tau, sD_full, 'zero', extraArgs);
else
  data = HJIPDE_solve(data0, tau, sD_full, 'none', extraArgs);
end

%% Reconstruct lower-dimensional solutions
vfs.gs = {sD_XT.grid; sD_YT.grid};
vfs.datas = {dataXT; dataYT};
vfs.tau = tau;
vfs.dims = {XTdims; YTdims};
vf = reconSC(vfs, gMin-small, gMax+small, 'end', constrType);

if tube
  dataCon = vf.dataMin;
else
  dataCon = vf.data(:,:,:,end);
end

system(sprintf('mkdir %s', mfilename));
save(sprintf('%s/%s', mfilename, whichComputation), 'g', 'gXT', 'gYT', ...
  'data', 'dataXT', 'dataYT', 'dataCon', 'whichComputation', 'tau', '-v7.3')
end