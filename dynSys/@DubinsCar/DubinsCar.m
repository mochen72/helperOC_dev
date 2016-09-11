classdef DubinsCar < DynSys
  properties
    % Angular control bounds
    wMax
    
    speed % Constant speed
    
    % Disturbance
    dMax
    
    % Dimensions that are active
    dims
  end
  
  methods
    function obj = DubinsCar(x, wMax, speed, dMax, dims)
      % obj = DubinsCar(x, wMax, speed, dMax, dims)
      %
      % Constructor. Creates a plane object with a unique ID,
      % state x, and reachable set information reachInfo
      %
      % Dynamics:
      %    \dot{x}_1 = v * cos(x_3) + d1
      %    \dot{x}_2 = v * sin(x_3) + d2
      %    \dot{x}_3 = u
      %         v \in [vrange(1), vrange(2)]
      %         u \in [-wMax, wMax]
      %         d \in [-dMax, dMax]
      %
      % Inputs:
      %   x      - state: [xpos; ypos; theta]
      %   wMax   - maximum turn rate
      %   vrange - speed range
      %   dMax   - disturbance bounds
      %
      % Output:
      %   obj       - a DubinsCar object
      %
      % Mahesh Vashishtha, 2015-10-26
      % Modified, Mo Chen, 2016-05-22

     
      if numel(x) ~= obj.nx
        error('Initial state does not have right dimension!');
      end
      
      if ~iscolumn(x)
        x = x';
      end
      
      if nargin < 2
        wMax = 1;
      end
      
      if nargin < 3
        speed = 5;
      end
      
      if nargin < 4
        dMax = [0; 0];
      end
      
      if nargin < 5
        dims = 1:3;
      end
        
      % Basic vehicle properties
      obj.pdim = 1:2; % Position dimensions
      obj.hdim = 3;   % Heading dimensions
      obj.nx = length(dims);
      obj.nu = 1;
      obj.nd = 2;      
      
      obj.x = x;
      obj.xhist = obj.x;
      
      obj.wMax = wMax;
      obj.speed = speed;
      obj.dMax = dMax;
      obj.dims = dims;
    end
    
  end % end methods
end % end classdef
