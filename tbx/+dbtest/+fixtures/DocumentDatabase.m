classdef (Abstract) DocumentDatabase <  dbtest.fixtures.Database & matlab.unittest.fixtures.Fixture
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties (SetAccess = private)
        DatabaseConnection
    end    
    
    properties (Access = private)
        TemporaryFolderFixture (1,:) matlab.unittest.fixtures.Fixture
        TemporaryFolder = string.empty(0,1)
        RepoCheckpointNames = string.empty(0,1)
        RepoCheckpointLocations = string.empty(0,1)
        RepoWorkingFolderName = "working"
        SetupFcn (1,1) function_handle = @(x) []
    end
    
    properties (Dependent, SetAccess = private)        
        IsValid
        CheckpointNames
        TableNames
    end
    
    properties (Dependent, Access = protected)
        WorkingRepoRoot
    end
    
    properties (Access = protected)
        TestingDatabase = 'DatabaseTesting'  % Database Name
    end
    
    methods
        
        function this = DocumentDatabase(setupFcn)
            
            if(nargin > 0)
                this.SetupFcn = setupFcn;
            end
            
        end
        
        function setup(this)
            
            this.SetupDescription    = 'Creating Temporary Folder';
            this.TeardownDescription = 'Deleting Temporary Folder';
            
            % Set up the TemporaryFolderFixture
            fx = matlab.unittest.fixtures.TemporaryFolderFixture();
            this.TemporaryFolderFixture = this.applyFixture(fx);
            
            % Root folder which will contain the repo and all checkpoints
            this.TemporaryFolder = this.TemporaryFolderFixture.Folder;
            
            this.createEmptyWorkingDataRepo();
            this.initializeDatabaseConnection();
            
            % Run setup function
            if(~isempty(this.SetupFcn))
                
                fprintf('Running Setup function ...\n');
                ti = dbtest.fixtures.SetupInterface(this);
                this.SetupFcn( ti );
                fprintf('Finished setting up database\n');
                
            end
            
        end
        
        function createCheckpoint(this,checkpointName)
            
            % Find the checkpoint by name
            idx = this.RepoCheckpointNames == checkpointName;
            assert(sum(idx) == 0, ...
                "dbtest:fixtures:DocumentDatabase:CheckpointAlreadyExists", ...
                "Checkpoint " + checkpointName + " already exists")
            
            % Make a new folder
            loc = tempname(this.TemporaryFolder);
            mkdir(loc)
            
            % Copy files from the working repo to this new location
            copyfile(this.WorkingRepoRoot,loc)
            
            % Register the name and location of the checkpoint
            this.RepoCheckpointNames(end+1) = string(checkpointName);
            this.RepoCheckpointLocations(end+1) = string(loc);
            
        end
        
        function restoreCheckpoint(this,checkpointName)
            
            % Find the checkpoint by name
            idx = this.RepoCheckpointNames == checkpointName;
            assert(sum(idx) == 1,"Checkpoint " + checkpointName + " not found")
            p = this.RepoCheckpointLocations(idx);
            
            this.disconnect();
            
            % Remove existing files from the working repo
            ok = this.clearWorkingRepo();
            errid = "dbtest:fixtures:RepoDeleteFailed";
            errmsg = "Working repo could not be cleared";
            assert(ok,errid,errmsg)
            
            % Copy files from checkpoint
            copyfile(p,this.WorkingRepoRoot)
            
            this.reconnect()
            
        end
        
        function importBackupFile(this,filePath)
            
            % loadExternalCheckpoint(this) Opens an explorer dialog and
            % allows the user to select any database file fromt the system
            % which is subsequently loaded into the database.
            %
            % loadExternalCheckpoint(this, filename) loads the file
            % specified by the variable filename into the testing database.
            
            % If no file has been passed as an argument, open uigetfile.
            if nargin < 2
                [file, path] = uigetfile('*.*');
                filePath = fullfile(path,file);
            end
            
            % Get full path to file so that it works with files on the
            % MATLAB path
            filePath = which(filePath);
            
            this.disconnect();
            
            % Clear the current working DB
            ok = this.clearWorkingRepo();
            errid = "dbtest:fixtures:RepoDeleteFailed";
            errmsg = "Working repo could not be cleared";
            assert(ok,errid,errmsg)
            
            % Copy files from the working repo to this new location
            copyfile(filePath,this.WorkingRepoRoot)
            
            % Rename the database so it has the same name as our working
            % database.
            [~,dbname,ext] = fileparts(filePath);
            curName = fullfile(this.WorkingRepoRoot,[dbname ext]);
            newName = fullfile(this.WorkingRepoRoot,[this.TestingDatabase,'.db']);
            movefile(curName,newName)
            
            this.reconnect();
            
        end
        
        function deleteCheckpoint(this,checkpointId)
            
            % Find the checkpoint by name
            idx = this.RepoCheckpointNames == checkpointId;
            assert(sum(idx) == 1,"Checkpoint " + checkpointId + " not found")
            p = this.RepoCheckpointLocations(idx);
            
            ok = rmdir(p,'s');
            
            this.RepoCheckpointNames(idx) = [];
            this.RepoCheckpointLocations(idx) = [];
            
            errid = "dbtest:fixtures:RepoDeleteFailed";
            errmsg = "Checkpoint could not be deleted";
            assert(ok,errid,errmsg)
        end        

    end    
    
    methods
                
        function checkpoints = get.CheckpointNames(this)
            
            checkpoints = this.RepoCheckpointNames;
            
        end
        
        function checkpoints = get.TableNames(this)
            
            checkpoints = this.getAllTableNames();
            
        end

        function folder = get.WorkingRepoRoot(this)
            
            folder = fullfile(this.TemporaryFolder,this.RepoWorkingFolderName);
            
        end
        
        function value = get.IsValid(this)
            
            value = logical(this.DatabaseConnection.IsOpen);
            
        end
        
    end
    
    methods (Access = private)
        
        function initializeDatabaseConnection( this )
            
            conn = getDatabaseConnection( this );
            
            this.DatabaseConnection = conn;
            this.addTeardown( @() this.disconnect );
            
        end
        
        function disconnect(this)
            
            this.DatabaseConnection.close();
            
        end
        
        function reconnect(this)
            
            % Close existing connection.
            if (this.IsValid)
                this.disconnect();
            end
            
            % Reconnect
            this.initializeDatabaseConnection();
            
        end
        
        function ok = clearWorkingRepo(this)
            
            % Get list of all files and folders in the working repo folder
            d = dir(this.WorkingRepoRoot);
            t = struct2table(d);
            t = t(:,{'name' 'isdir'});
            t.name = string(t.name);
            t = t(t.name ~= ".",:);
            t = t(t.name ~= "..",:);
            
            % Remove folders
            folderNames = t.name(t.isdir);
            nFolders = numel(folderNames);
            ok = false(1,nFolders);
            for k = 1:nFolders
                ok(k) = rmdir(fullfile(this.WorkingRepoRoot,folderNames(k)),'s');
            end
            ok = all(ok);
            
            % Remove files
            fileNames = t.name(~t.isdir);
            delete(fullfile(this.WorkingRepoRoot,fileNames))
            
        end

    end
    
    methods (Access = protected)
        
        function bool = isCompatible(fixture,other)
            
            % Default
            bool = false;
            
            % Same classes
            sameFixture = strcmp(class(fixture),class(other));
            if(~sameFixture)
                return
            end
            
            % Same setup function
            sameSetup = isequal(fixture.SetupFcn,other.SetupFcn);
            if(~sameSetup)
                return
            end
            
            % If we've got to this point, everything's ok
            bool = true;
            
        end
        
    end
    
    methods (Abstract,Access = protected)
        
       tableNames = getAllTableNames(this)
       conn = getDatabaseConnection(this)
       createEmptyWorkingDataRepo(this)
       
    end
    
end