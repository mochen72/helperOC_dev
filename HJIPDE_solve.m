function [data, tau, extraOuts] = HJIPDE_solve( ...
  data0, tau, schemeData, minWith, extraArgs)
% [data, tau] = HJIPDE_solve( ...
%   data0, tau, schemeData, minWith, extraargs)
%
% Solves HJIPDE with initial conditions data0, at times tau, and with
% parameters schemeData and obstacles
%
% Inputs:
%   data0      - initial value function
%   tau        - list of computation times
%   schemeData - problem parameters passed into the Hamiltonian function
%                  .grid: grid (required!)
%   minWith    - set to 'zero' to do min with zero
%              - set to 'none' to compute reachable set (not tube)
%              - set to 'data0' to do min with data0 (for variational
%                inequality)
%   extraArgs  - this structure can be used to leverage other additional
%                functionalities within this function. Its subfields are:
%     .obstacles:  a single obstacle or a list of obstacles with time
%                  stamps tau (obstacles must have same time stamp as the
%                  solution)
%     .compRegion: unused for now (meant to limit computation region)
%     .visualize:  set to true to visualize reachable set
%     .plotData:   information required to plot the data (need to fill in)
%     .stopInit:   stop the computation once the reachable set includes the
%                  initial state
%
% Outputs:
%   data - solution corresponding to grid g and time vector tau
%   tau  - list of computation times (redundant)
%   extraOuts - This structure can be used to pass on extra outputs, for
%               example:
%      .stoptau: time at which the reachable set contains the initial
%                state; tau and data vectors only contain the data till
%                stoptau time.
%      .hT:      figure handle
%

%% Default parameters
if numel(tau) < 2
  error('Time vector must have at least two elements!')
end

if nargin < 4
  minWith = 'zero';
end

if nargin < 5
  extraArgs = [];
end

extraOuts = [];
small = 1e-4;

%% Extract the information from extraargs
% Extract the information about obstacles
if isfield(extraArgs, 'obstacles')
  obstacles = extraArgs.obstacles;
end

if isfield(extraArgs, 'visualize') && extraArgs.visualize
  % Extract the information about plotData
  if isfield(extraArgs, 'plotData')
    % Dimensions to visualize
    % It will be an array of 1s and 0s with 1s means that dimension should
    % be plotted.
    plotDims = extraArgs.plotData.plotDims;
    % Points to project other dimensions at. There should be an entry point
    % corresponding to each 0 in plotDims.
    projpt = extraArgs.plotData.projpt;
    % Initialize the figure for visualization
  else
    plotDims = ones(schemeData.grid.dim, 1);
    projpt = [];
  end
  
  f = figure;
  need_light = true;
end

% Extract the information about stopInit
if isfield(extraArgs, 'stopInit')
  initState = extraArgs.stopInit.initState;
end

%% SchemeFunc and SchemeData
schemeFunc = @termLaxFriedrichs;
g = schemeData.grid;
% Extract accuracy parameter o/w set default accuracy
accuracy = 'veryHigh';
if isfield(schemeData, 'accuracy')
  accuracy = schemeData.accuracy;
end

%% Numerical approximation functions
dissType = 'global';
[schemeData.dissFunc, integratorFunc, schemeData.derivFunc] = ...
  getNumericalFuncs(dissType, accuracy);

%% Time integration
integratorOptions = odeCFLset('factorCFL', 0.8, 'stats', 'on', ...
  'singleStep', 'on');

startTime = cputime;

if g.dim == 1
  data = zeros(length(data0), length(tau));
else
  data = zeros([size(data0) length(tau)]);
end

eval(updateData_cmd(g.dim, '1'));

for i = 2:length(tau)
  y0 = eval(get_dataStr(g.dim, 'i-1'));
  y = y0(:);
  
  tNow = tau(i-1);
  while tNow < tau(i) - small
    % Save previous data if needed
    if strcmp(minWith, 'zero')
      yLast = y;
    end
    
    [tNow, y] = feval(integratorFunc, schemeFunc, [tNow tau(i)], y, ...
      integratorOptions, schemeData);
    
    % Min with zero
    if strcmp(minWith, 'zero')
      y = min(y, yLast);
    end
    
    % Min with data0
    if strcmp(minWith, 'data0')
      y = min(y, data0(:));
    end
    
    % "Mask" using obstacles
    if isfield(extraArgs, 'obstacles')
      if numDims(obstacles) == g.dim
        y = max(y, -obstacles(:));
      else
        % obstacle = obstacles(:,:,:,i)
        obstacle_i = eval(get_dataStr(g.dim, 'i', 'obstacles'));
        y = max(y, -obstacle_i(:));
      end
    end
  end
  
  % Reshape value function
  % data(:,:,:,i) = reshape(y, schemeData.grid.shape);
  eval(updateData_cmd(g.dim, 'i'));
  
  % If commanded, stop the reachable set computation once it contains
  % the initial state.
  if isfield(extraArgs, 'stopInit')
    if iscolumn(initState)
      initState = initState';
    end
    reachSet = eval(get_dataStr(g.dim, 'i'));
    initValue = eval_u(g, reachSet, initState);
    if ~isnan(initValue) && initValue <= 0
      extraOuts.stoptau = tau(i);
      otherdims = repmat({':'},1,g.dim);
      data(otherdims{:}, i+1:size(data,g.dim+1)) = [];
      tau(i+1:end) = [];
      break
    end
  end
  
  %% If commanded, visualize the level set.
  if isfield(extraArgs, 'visualize') && extraArgs.visualize
    % Number of dimensions to be plotted and to be projected
    pDims = nnz(plotDims);
    projDims = length(projpt);
    
    % Basic Checks
    if(length(plotDims) ~= g.dim || projDims ~= (g.dim - pDims))
      error('Mismatch between plot and grid dimesnions!');
    end
    
    if (pDims >= 4 || g.dim > 4)
      error('Currently only 3D plotting upto 3D is supported!');
    end
    
    % Visualize the reachable set
    figure(f)
    reachSet = eval(get_dataStr(g.dim, 'i'));
    
    if projDims == 0
      extraOuts.hT = visSetIm(g, reachSet, 'r', 0, [], false);
      
      if need_light && g.dim == 3
        camlight left
        camlight right
        need_light = false;
      end
    else
      str = sprintf('%d',[g.dim pDims]) ;
      switch str
        case '43'
          [g3D, y3D] = proj3D(g, reachSet, 1-plotDims, projpt);
          extraOuts.hT = visSetIm(g3D, y3D, 'r', 0, [], false);
          if need_light
            camlight left
            camlight right
            need_light = false;
          end
        case {'42' , '32'}
          [g2D, y2D] = proj2D(g, reachSet, 1-plotDims, projpt);
          extraOuts.hT = visSetIm(g2D, y2D);
        otherwise
          error('Projection on 1D is not implemented yet!')
      end
    end
    drawnow;
  end
end

endTime = cputime;
fprintf('Total execution time %g seconds\n', endTime - startTime);
end

function cmdStr = updateData_cmd(dims, indStr)
%% Generate command for updating data
% data(:,:,:,i)
cmdStr = get_dataStr(dims, indStr);

% data(:,:,:,i) =
cmdStr = cat(2, cmdStr, ' = ');

if strcmp(indStr, '1')
  % data(:,:,:,i) = data0;
  cmdStr = cat(2, cmdStr, 'data0;');
else
  % data(:,:,:,i) = reshape(y, schemeData.grid.shape);
  cmdStr = cat(2, cmdStr, 'reshape(y, schemeData.grid.shape);');
end
end

function [dissFunc, integratorFunc, derivFunc] = ...
  getNumericalFuncs(dissType, accuracy)
% Dissipation
switch(dissType)
  case 'global'
    dissFunc = @artificialDissipationGLF;
  case 'local'
    dissFunc = @artificialDissipationLLF;
  case 'locallocal'
    dissFunc = @artificialDissipationLLLF;
  otherwise
    error('Unknown dissipation function %s', dissFunc);
end

% Accuracy
switch(accuracy)
  case 'low'
    derivFunc = @upwindFirstFirst;
    integratorFunc = @odeCFL1;
  case 'medium'
    derivFunc = @upwindFirstENO2;
    integratorFunc = @odeCFL2;
  case 'high'
    derivFunc = @upwindFirstENO3;
    integratorFunc = @odeCFL3;
  case 'veryHigh'
    derivFunc = @upwindFirstWENO5;
    integratorFunc = @odeCFL3;
  otherwise
    error('Unknown accuracy level %s', accuracy);
end
end