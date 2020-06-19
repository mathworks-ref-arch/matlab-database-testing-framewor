classdef PostgreLatest < dbtest.fixtures.Postgre
    
    properties (Constant,Access = protected)
        ServerVersion = 'postgres'
    end
    
end