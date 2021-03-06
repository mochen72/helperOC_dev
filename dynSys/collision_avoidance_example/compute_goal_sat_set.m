function compute_goal_sat_set(gN)
% Plane_test()
%   Tests the Plane class by computing a reachable set and then computing the
%   optimal trajectory from the reachable set.

if nargin < 1
  gN = 41;
end

%% Plane parameters
initState = [-25; -25; -45*pi/180];
wMax = 1;
vrange = [5 5];
dMax = [0; 0];
pl = Plane(initState, wMax, vrange, dMax);

%% Target and obstacles
g = createGrid([-30; -30; -pi], [30; 30; pi], [gN; gN; gN], 3);
target = shapeRectangleByCorners(g, [-inf; -g.dx(2:3)], [inf; g.dx(2:3)]);

%% Compute reachable set
tau = 0:0.1:20;

schemeData.dynSys = pl;
schemeData.grid = g;
schemeData.uMode = 'min';
schemeData.dMode = 'max';

extraArgs.targets = target;
extraArgs.stopInit = pl.x;
extraArgs.visualize = true;
extraArgs.deleteLastPlot = true;

[goal_sat_set.data, tau] = HJIPDE_solve(target, tau, schemeData, 'zero', ...
  extraArgs);

goal_sat_set.g = g;
goal_sat_set.deriv = computeGradients(g, goal_sat_set.data);
goal_sat_set.TTR = TD2TTR(g, goal_sat_set.data, tau);
goal_sat_set.TTRderiv = computeGradients(g, goal_sat_set.TTR);

save('goal_sat_set.mat', 'goal_sat_set', '-v7.3');

%% Test by computing optimal trajectory
extraArgs.projDim = [1 1 0];
extraArgs.fig_filename = 'Plane_test2/optTraj';
[traj, traj_tau] = computeOptTraj(g, flip(goal_sat_set.data,4), tau, pl, ...
  extraArgs);

hold on;

plot(traj(1,:), traj(2,:), '.')

end