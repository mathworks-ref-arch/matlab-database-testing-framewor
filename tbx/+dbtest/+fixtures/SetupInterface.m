classdef SetupInterface < dbtest.fixtures.Database
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties (Access = private)
        Fixture
    end
    
    properties (SetAccess = private)
       DatabaseConnection 
    end
    
    properties (Dependent,SetAccess = private)
        CheckpointNames
        TableNames
    end
            
    methods
        
        function obj = SetupInterface(fx)
            
            if ~isa(fx,"matlab.unittest.fixtures.Fixture")
                errid = "SetupInterface:InputIsNotAFixture";
                errmsg = "The argument of SetupInterface must be an " ...
                         + "object subclassing matlab.unittest.fixtures.Fixture";
                error(errid,errmsg)
            end
            
            obj.Fixture = fx;
            
        end
        
    end
    
    methods
        
        function conn = get.DatabaseConnection(this)
            
           conn = this.Fixture.DatabaseConnection; 
           
        end
        
        function checkpoints = get.CheckpointNames(this)
            
            checkpoints = this.Fixture.CheckpointNames;
            
        end
        
        function tableNames = get.TableNames(this)
            
            tableNames = this.Fixture.TableNames;
            
        end
        
        
    end
    
    methods
        
        function createCheckpoint(this,checkpointName)
            
            this.Fixture.createCheckpoint(checkpointName)
            
        end
        
        function restoreCheckpoint(this,checkpointName)
            
            this.Fixture.restoreCheckpoint(checkpointName)
            
        end
        
        function deleteCheckpoint(this,checkpointName)
            
            this.Fixture.deleteCheckpoint(checkpointName)
            
        end
        
        function importBackupFile(this,filepath)
            
            this.Fixture.importBackupFile(filepath)
            
        end
        
    end
    
end