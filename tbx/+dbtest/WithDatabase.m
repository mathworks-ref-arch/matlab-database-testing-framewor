classdef (Abstract) WithDatabase < matlab.unittest.TestCase
    % WithDatabase unit test base class for testing with ephemeral
    % database using Docker
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties (Dependent,SetAccess = private)
        DatabaseConnection
        CheckpointNames
        TableNames
    end
    
    properties (Access = protected)
        Fixture
    end
    
    methods
        
        function createCheckpoint(this,checkpointName)
            
            this.getDbServerFixture().createCheckpoint(checkpointName);
            
        end
        
        function restoreCheckpoint(this,checkpointName)

            this.getDbServerFixture().restoreCheckpoint(checkpointName);

        end
        
        function deleteCheckpoint(this,checkpointName)
            
            this.getDbServerFixture().deleteCheckpoint(checkpointName);
            
        end
        
        function importBackupFile(this,varargin)
            
            this.getDbServerFixture().importBackupFile(varargin{:});
            
        end
        
    end
    
    methods
        
        function conn = get.DatabaseConnection(this)
            
            conn = this.getDbServerFixture().DatabaseConnection;

        end
        
        function checkpoints = get.CheckpointNames(this)
            
            checkpoints = this.getDbServerFixture().CheckpointNames;
            
        end
        
        function tableNames = get.TableNames(this)
            
            tableNames = this.getDbServerFixture().TableNames;
            
        end
        
    end
    
    methods (Access = private)
        
        function fx = getDbServerFixture(this)
            
            fx = this.getDbServerSharedFixture();
            
            % When running in interactive mode, fixture is not applied and
            % fx will be empty.
            if(isempty(fx) && ~isempty(this.Fixture))
                fx = this.Fixture;
            end
            
        end
        
    end
    
    methods (Static, Access = protected)
        
        function tc = forInteractiveUseGeneric(className)
            
            tc = dbtest.(className).forInteractiveUse();
            fx = dbtest.WithDatabase.getFixtureFromClassName(className);
            tc.Fixture = tc.applyFixture(fx);
            
        end
        
    end
    
    methods (Static,Hidden)
        
        function fx = getFixtureFromClassName(className)
            
            % Get the fixture name
            fixtureName = strrep(className, "With", "");
            
            % Check the expected fixture exists
            fullFixtureName = "dbtest.fixtures." + fixtureName;
            fixtureExists = exist(fullFixtureName, 'class') == 8;
            errid = "dbtest:WithDatabase:MissingFixture";
            errmsg = "Cannot find fixture with name '" + fullFixtureName + "'";
            assert(fixtureExists,errid,errmsg);
            
            % Create the fixture
            fx = dbtest.fixtures.(fixtureName);
            
        end
        
    end
    
    methods (Abstract,Access = protected)
        
        fx = getDbServerSharedFixture(this)
        
    end
    
    methods (Abstract,Static)
        
        tc = forInteractiveUseWithAutoSetup()
        
    end
    
end