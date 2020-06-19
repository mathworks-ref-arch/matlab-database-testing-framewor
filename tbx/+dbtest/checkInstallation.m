classdef checkInstallation < dbtest.WithMsSqlServer2019
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    methods (Test)
        
        function tInstallation(tc)
            
            % Write some data
            expected = table("Batman",35,"Male",200,"Gotham",'VariableNames',...
                        {'LastName' 'Age' 'Gender' 'Height' 'Location'});
            tc.DatabaseConnection.sqlwrite("Characters",expected);
            
            % Read it back
            opts = databaseImportOptions(tc.DatabaseConnection,"Characters");
            opts = opts.setoptions('Type',{'string' 'double' 'string' 'double' 'string'});
            actual = tc.DatabaseConnection.sqlread("Characters",opts);
            
            % Check that they match
            tc.verifyEqual(actual,expected)
            
        end
        
    end
    
end