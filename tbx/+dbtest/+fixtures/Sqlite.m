classdef Sqlite < dbtest.fixtures.DocumentDatabase
    
    % Copyright 2019-2020 The MathWorks, Inc.
            
    methods (Access = protected)
        
        function conn = getDatabaseConnection( this )
            
            dbpath = fullfile(this.WorkingRepoRoot, [this.TestingDatabase,'.db']);
            conn = sqlite(dbpath);
            
        end        
        
        function createEmptyWorkingDataRepo(this)
            
            % Create working location
            mkdir(this.WorkingRepoRoot);
            
            % Create Connection for the first time.
            dbpath = fullfile(this.WorkingRepoRoot, [this.TestingDatabase,'.db']);
            
            conn = sqlite(dbpath, 'create');
            conn.close()

        end
        
        function tableNames = getAllTableNames(this)
            
            sql = "SELECT * FROM sqlite_master WHERE type='table';";

            tbls = this.DatabaseConnection.fetch(sql);
            tableNames = string(tbls(:,2));
            
        end
        
    end
    
end