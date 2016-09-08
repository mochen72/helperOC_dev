function uOpt = optCtrl(obj, ~, ~, deriv, uMode, dims)
% uOpt = optCtrl(obj, t, y, deriv, uMode, dims)
%     Dynamics of the Plane4D
%         \dot{x}_1 = x_4 * cos(x_3) + d_1
%         \dot{x}_2 = x_4 * sin(x_3) + d_2
%         \dot{x}_3 = u_1 = u_1
%         \dot{x}_4 = u_2 = u_2

%% Input processing
if nargin < 5
  uMode = 'min';
end

if nargin < 6
  dims = 1:obj.nx;
end

if ~iscell(deriv)
  deriv = num2cell(deriv);
end

uOpt = cell(obj.nu, 1);

%% Optimal control
if strcmp(uMode, 'max')
  if any(dims == 3)
    uOpt{1} = (deriv{dims==3}>=0)*obj.wMax + (deriv{dims==3}<0)*(-obj.wMax);
  end
  
  if any(dims == 4)
    uOpt{2} = (deriv{dims==4}>=0)*obj.aRange(2) + ...
      (deriv{dims==4}<0)*obj.aRange(1);
  end

elseif strcmp(uMode, 'min')
  if any(dims == 3)
    uOpt{1} = (deriv{dims==3}>=0)*(-obj.wMax) + (deriv{dims==3}<0)*obj.wMax;
  end
  
  if any(dims == 4)
    uOpt{2} = (deriv{dims==4}>=0)*obj.aRange(1) + ...
      (deriv{dims==4}<0)*obj.aRange(2);
  end
else
  error('Unknown uMode!')
end

end