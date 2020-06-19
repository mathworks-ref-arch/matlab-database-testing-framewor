classdef (SharedTestFixtures = {dbtest.WithDatabase.getFixtureFromClassName(mfilename)}) ...
        WithMsSqlServer2019 < dbtest.WithDatabase
    % WithMsSqlServer2019 unit test base class for testing with ephemeral
    % MS-SQL database using Docker
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    methods (Access = protected)
        
        function fx = getDbServerSharedFixture(this)
            
            c = class(dbtest.WithDatabase.getFixtureFromClassName(mfilename));
            fx = this.getSharedTestFixtures(c);
            
        end
        
    end
    
    methods (Static)
        
        function tc = forInteractiveUseWithAutoSetup()
            
            tc = dbtest.WithDatabase.forInteractiveUseGeneric(mfilename);
            
        end
        
    end
    
end