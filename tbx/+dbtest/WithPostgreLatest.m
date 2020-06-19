classdef (SharedTestFixtures = {dbtest.WithDatabase.getFixtureFromClassName(mfilename)}) ...
        WithPostgreLatest < dbtest.WithDatabase
    % WithPostgreSQL unit test base class for testing with ephemeral
    % PostgreSQL database using Docker
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    methods (Access = protected)
        
        function fx = getDbServerSharedFixture(this)
            
            c = class(dbtest.WithDatabase.getFixtureFromClassName(mfilename));
            fx = this.getSharedTestFixtures(c);
            
        end
        
    end
    
    methods ( Static )
        
        function tc = forInteractiveUseWithAutoSetup()
            
            tc = dbtest.WithDatabase.forInteractiveUseGeneric(mfilename);
            
        end
        
    end
    
end