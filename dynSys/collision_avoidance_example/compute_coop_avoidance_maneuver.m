function [trajA, trajB] = compute_coop_avoidance_maneuver(safety_set, ...
  goal_sat_set, planeA, planeB)

if nargin < 3
  %% Vehicle parameters
  xA = [-30; 0; 0];
  wMaxA = 1; % Maximum turn rate (rad/s)
  vRangeA = [5 5]; % Speed range (m/s)
  dMaxA = [0 0]; % Disturbance (see PlaneCAvoid class)
  
  thetaB = 3*pi/4*rand;
  xB = [30*cos(thetaB); 30*sin(thetaB); thetaB+pi];
  wMaxB = 1;
  vRangeB = [5 5];
  dMaxB = [0 0];
  

else
  xA = planeA.x;
  wMaxA = planeA.wMax;
  vRangeA = planeA.vrange;
  dMaxA = planeA.dMax;
  
  xB = planeB.x;
  wMaxB = planeB.wMax;
  vRangeB = planeB.vrange;
  dMaxB = planeB.dMax;
end

planes = {Plane(xA, wMaxA, vRangeA, dMaxA); Plane(xB, wMaxB, vRangeB, dMaxB)};
planeRel = PlaneCAvoid(planes);


init_headings = {xA(3); xB(3)};

%% Simulate to obtain trajectories
dt = 0.1;
t = 0:dt:200;

ti_min = 10; % Minimum number of steps to simulate

evader_ind = nan; % nan ~= any number is true
avoidance_started = false;
extraArgs.ArrowLength = 2;

figure
for ti = 1:length(t)
  [u, avoidance_started, evader_ind] = control_logic(planes, planeRel, ...
    init_headings, avoidance_started, evader_ind, safety_set, goal_sat_set);
  for veh = 1:length(planes)
    
    % Update state
    planes{veh}.updateState(u{veh}, dt);
    planes{veh}.plotPosition(extraArgs);
  end
  
  if ti == 1
    xlim([-30 30])
    ylim([-30 30])
    axis square
    grid on
  end
  drawnow
  %   % Break if all vehicles have gotten to target
  %   if avoidance_started &&
  %     break
  %   end
end

trajA = planes{1}.xhist;
trajB = planes{2}.xhist;
end

function [u, avoidance_started, evader_ind] = control_logic(planes, ...
  planeRel, init_headings, avoidance_started, evader_ind, safety_set, ...
  goal_sat_set)

small = 1e-2;

% Compute safety value
rel_x = PlaneDubins_relState(planes{1}.x, planes{2}.x);
if any(rel_x' < safety_set.g.min) || any(rel_x' > safety_set.g.max)
  safe = true;
else
  safety_val = eval_u(safety_set.g, safety_set.data, rel_x);
  if safety_val > small
    safe = true;
  else
    safe = false;
    if ~avoidance_started
      avoidance_started = true;
    end
  end
end

u = cell(2,1);
if safe
  for veh = 1:2
    if avoidance_started
      
      % If safe, use goal satisfaction controller
      x = rotate_to_goal_sat_frame(planes{veh}.x, init_headings{veh});
      tEarliest = find_earliest_BRS_ind(goal_sat_set.g, goal_sat_set.data, x);
      Deriv = {goal_sat_set.deriv{1}(:,:,:,tEarliest); ...
        goal_sat_set.deriv{2}(:,:,:,tEarliest); ...
        goal_sat_set.deriv{2}(:,:,:,tEarliest)};
      p = eval_u(goal_sat_set.g, Deriv, x);
      u{veh} = planes{veh}.optCtrl([], x, p, 'min');
      
    else
      u{veh} = [planes{veh}.vrange(1); 0];
    end
  end
else
  % If not safe, use safety controller
  p = eval_u(safety_set.g, safety_set.deriv, rel_x);
  u{1} = planeRel.optCtrl([], rel_x, p, 'max');
  d = planeRel.optDstb([], rel_x, p, 'max');
  u{2} = d(1:2);
end


end

function xOut = rotate_to_goal_sat_frame(xIn, init_heading)

xOut = zeros(3,1);
xOut(1:2) = rotate2D(xIn(1:2), -init_heading);
xOut(3) = xIn(3) - init_heading;

end