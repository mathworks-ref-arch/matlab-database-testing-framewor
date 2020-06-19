classdef (Abstract) Database < handle
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties (Abstract,SetAccess = private)
        DatabaseConnection
    end
    
    properties (Abstract,Dependent,SetAccess = private)
        CheckpointNames
        TableNames
    end
    
    methods (Abstract)
        createCheckpoint(this,checkpointName)
        restoreCheckpoint(this,checkpointName)
        deleteCheckpoint(this,checkpointName)
        importBackupFile(this,checkpointName)
    end
    
end