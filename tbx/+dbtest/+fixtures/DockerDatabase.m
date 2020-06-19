classdef (Abstract) DockerDatabase < dbtest.fixtures.Database & matlab.unittest.fixtures.Fixture
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties (SetAccess = private)
        DatabaseConnection
    end
    
    properties (Abstract,Constant)
        EULALink 
    end
    
    properties (Abstract,Constant,Access = protected)
        DefaultUsername
        TestingDatabase
    end
    
    properties (Access = protected)
        ContainerId (1,1) string           % Docker container ID
        Port (1,1) double                  % DB port
        SqlDataSource = 'DatabaseTesting'  % ODBC data source
    end
    
    properties (Constant,Access = protected)
        TestingUser = 'testing'            % Username for DB
        TestingPassword = 'Testing123'     % Password for DB
        Timeout = 200                      % Timeout when launching container (s)
        SAPassword = "matlabSQL2019"       % Sys admin password for SQL Server
    end
    
    properties (Dependent,SetAccess = private)
        IsValid (1,1) logical
        CheckpointNames
        TableNames
    end
    
    properties (Access = private)
        SetupFcn (1,1) function_handle = @(x) []
        AcceptEula (1,1) string {mustBeMember(AcceptEula,["yes" "no" "prompt"])} = "no"
    end
    
    % Public
    methods
        
        function this = DockerDatabase(varargin)
            
            % Parse inputs
            p = inputParser;
            defalutSetupFcn = @(x) [];
            addOptional(p, 'setupFcn', defalutSetupFcn);
            addParameter(p, 'AcceptServerEULA', 'prompt')
            parse(p,varargin{:})
            
            % Assign values
            this.SetupFcn = p.Results.setupFcn;
            this.AcceptEula = p.Results.AcceptServerEULA;
            
            % Check that docker is running
            this.checkForDocker();
            
            % Check that the database toolbox is installed:
            this.checkForDbToolbox();
            
        end
        
        function setup(this)
            
            % Make sure user has accepted EULA
            this.mustHaveAcceptedEula();
            
            this.SetupDescription    = 'Spinning up Docker container';
            this.TeardownDescription = 'Shutting down Docker container';
            this.initialiseDataSources();
            
            % Make sure we're connected
            id = 'executeScheme:IsConnected';
            msg = 'You are not connected to the default database. Please connect to the default database.';
            assert(this.IsValid,id,msg);
            
            % Add setup function
            if(~isempty(this.SetupFcn))
                ti = dbtest.fixtures.SetupInterface(this);
                
                fprintf('Running Setup Fcn ...\n');
                this.SetupFcn( ti );
                fprintf('Finished setting up database\n');
            end
            
        end
        
        function createCheckpoint(this,checkpointName)
            
            % Make sure that checkpoint does not exist.
            this.checkpointMustNotExist(checkpointName)
            
            this.copyDatabase(this.TestingDatabase,checkpointName);
            
        end
        
        function restoreCheckpoint(this,checkpointName)
            
            % Check if we have a valid connection
            errid = "DockerDatabase:loadCheckpoint:InvalidSourceDb";
            errmsg = "Not a valid Database Connection";
            assert(this.IsValid,errid,errmsg)
            
            % Make sure that checkpoint exists.
            this.checkpointMustExist(checkpointName)
            
            % Disconnect from the database so that working can be dropped.
            this.disconnect();
            
            % Drop working database
            this.dropDatabase(this.TestingDatabase)
            
            % Copy Database
            this.copyDatabase(checkpointName,this.TestingDatabase)
            
            % Some databases do no reconnect after droping.
            this.reconnect()
            
        end
        
        function deleteCheckpoint(this,checkpointName)
            
            % Make sure that checkpoint exsits.
            this.checkpointMustExist(checkpointName)
            
            % Disconnect from the database so that drop can happen.
            this.disconnect();
            
            % Drop Database
            this.dropDatabase(checkpointName);
            
            % Reconnect to Database because droping needs to disconnect.
            this.reconnect();
            
        end
        
        function importBackupFile(this,filepath)
            % loadExternalCheckpoint(this) Opens an explorer dialog and
            % allows the user to select any database file fromt the system
            % which is subsequently loaded into the database.
            %
            % loadExternalCheckpoint(this, filename) loads the file
            % specified by the variable filename into the testing database.
            
            % If no file has been passed as an argument, open uigetfile.
            if nargin < 2
                [file, path] = uigetfile('*.*');
                filepath = fullfile(path,file);
            else
                [~,file,ext] = fileparts(string(filepath));
                file = file + ext;
            end
            
            % Get full path to file so that it works with files on the
            % MATLAB path
            filepath = which(filepath);

            % Copy the external file into the docker container
            cmd = sprintf('docker cp "%s" %s:/tmp',filepath,this.ContainerId);
            [status, cmdout] = system(cmd);
            
            if status ~= 0
                id = "DockerDatabase:UnableToImportFile";
                error(id, ['Error loading external file: ' strrep(cmdout,'\','\\')])
            end
            
            % Empty the main database.
            this.disconnect();
            this.dropDatabase(this.TestingDatabase)
            
            % Do the import
            this.importDatabase("/tmp/" + file);
            
            this.reconnect();
            
        end
        
    end
    
    % Accessors
    methods
        
        function checkpoints = get.CheckpointNames(this)
            
            checkpoints = this.getCheckpointNames();
            
        end
        
        function value = get.IsValid(this)
            
            value = logical(this.DatabaseConnection.isopen);
            
        end
        
        function names = get.TableNames(this)
           
            names = this.getAllTableNames();
            
        end
        
    end
    
    % High level
    methods (Access = private)
        
        function initialiseDataSources( this )
            
            % Get a free port and random DSN name
            this.Port = this.getFreePort();
            
            % Create a data source (this is equivalent to
            % configureODBCDataSource )
            this.SqlDataSource = this.createDataSourceName();
            
            % Create Docker container
            this.createSqlContainer();
            
            % Create connection with an empty database.
            this.createEmptyDatabaseAndUser();
            
            % Store database connection with user credentials.
            this.initializeDatabaseConnection();
            
        end
        
        function copyDatabase(this,sourceDb,destinationDb)
            
            % Name for backup file
            bakFile = "/tmp/" + sourceDb + ".bak";
            
            % Make sure bak file doesn't already exist in the container
            cmd = "docker exec " + string(this.ContainerId) + " rm """ + bakFile + """";
            [status, cmdout] = system(cmd);  %#ok<ASGLU>
            
            % Do the backup
            this.makeBackupAndRestore(sourceDb,destinationDb,bakFile);
            
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
        
    end
    
    % Helpers
    methods (Access = private)
        
        function checkpointMustExist(this,checkpointID)
            
            dbExists = any(strcmp(checkpointID,this.CheckpointNames));
            errid = "SqlDatabase:checkpointMustExist:InvalidCheckpointID";
            errmsg = "Checkpoint " + checkpointID + " does not exist.";
            assert(dbExists,errid,errmsg);
            
        end
        
        function checkpointMustNotExist(this,checkpointID)
            
            dbExists = any(strcmp(checkpointID,this.CheckpointNames));
            errid = "SqlDatabase:checkpointMustNotExist:InvalidCheckpointID";
            errmsg = "Checkpoint " + checkpointID + " already exists.";
            assert(~dbExists,errid,errmsg);
            
        end
        
        function mustHaveAcceptedEula(this)
            
            if(ispref('DatabaseTesting','AutoAcceptServerEula') && ...
              getpref('DatabaseTesting','AutoAcceptServerEula'))
                return
            end

            % Prompt for user to accept EULA
            acceptEula = this.promptForUserAgreement();

            if ~acceptEula
                id = 'dbtest:fixtures:DockerDatabase';
                msg = ['The user agreement for the Docker ',...
                    'image needs to be accepted prior to continue. ',...
                    'The argument of License must be either '...
                    '''yes'' or ''prompt'' in order to continue.'];
                error(id,msg)
            end
            
        end
        
        function checkForDocker(~)
            
            [status, msg] = system("docker ps");
            if status ~= 0
                error( ...
                    'DockerDatabase:DockerNotRunning', ...
                    'Docker connection failed with the following error message:\n%s', ...
                    msg );
            end
            
        end
        
        function checkForDbToolbox(~)
            
            db_toolbox_info = ver('database');
            if isempty(db_toolbox_info)
                errid = 'DockerDatabase:DatabaseToolboxNotInstalled';
                errmsg = ['The database toolbox is not installed. This '...
                          'toolbox is required in order to use this '...
                          'testing framework'];
                error(errid,errmsg)
            end
            
        end
        
        function ok = promptForUserAgreement(this)
            
            fig = uifigure('NumberTitle','off',...
                           'Name','EULA Agreement',...
                           'Position',[100, 600 450 170],...
                           'Visible','on'); % Need to be explicit for Live Scripts
            c = onCleanup(@() delete(fig));
                       
            web(this.EULALink)
            disp("EULA: <a href=""" + this.EULALink + """>" + this.EULALink + "</a>")
            
            title = "EULA Agreement";
            msg = "Running this Docker image may be subject to an End " + ....
                  "User Licence Agreement, the link to which has been " + ...
                  "opened in a web browser, and displayed in the Command " + ...
                  "Window. Do you accept this agreement?";
            
            sel = uiconfirm(fig,msg,title,...
                            'Options',{'Accept','Decline'},...
                            'DefaultOption',1);

            if strcmp(sel,'Accept')
                ok = true;
            else
                ok = false;
            end
            
        end
        
    end
    
    % Docker container creation and initialisation
    methods (Access = private)
        
        function createSqlContainer( this )
            
            fprintf('[%s] Attempting to create container: Source=%s, Port=%d\n', datestr(now), this.SqlDataSource, this.Port );
            
            % Update the data source
            this.createOdbcDataSource();
            this.addTeardown( @() this.deleteOdbcSource( this.SqlDataSource ) );
            
            this.ContainerId = this.spinUpContainer();
            this.addTeardown( @() this.teardownContainer( this.ContainerId ) );
            
            this.waitForContainerToBeReady();
            
        end
        
        function containerId = spinUpContainer( this )
            
            cmdLine = this.getDockerImageInitCall;
            
            [status, msg] = system( cmdLine );
            if status ~= 0
                error( ...
                    'Database:FailedToStartContainer', ...
                    'Failed to start docker container:\n%s', ...
                    msg );
            end
            
            % If the docker image is not installed, msg will contain
            % additional information in addition to the containerId.
            % Hence, we only need to extract the last line of the message.
            msg = strtrim( msg ); %Trim empty lines.
            Id  = splitlines(msg);
            
            containerId = Id{end};
            
        end
        
        function waitForContainerToBeReady( this )
            startTime       = tic;
            attemptCount    = 1;
            while toc( startTime ) < this.Timeout
                % Try to open a connection
                fprintf('[%s] Attempt [%02d] ', datestr(now), ...
                    attemptCount);
                connection = database( this.SqlDataSource, this.DefaultUsername, this.SAPassword );
                % Check if message is empty (meaning, connection is open)
                if isempty( connection.message )
                    fprintf('Connected: took %1.1fsec \n', toc( startTime ) );
                    connection.close()
                    return;
                else
                    % Give it a second
                    fprintf('%s \n', "Waiting for container to be initialized" );
                    pause( 5 );
                end %end if
                attemptCount = attemptCount + 1;
            end
            error( ...
                'SqlDatabase:ContainerTimeout', ...
                'Timed out waiting for container to be initialized:\n\n%s', ...
                connection.message );
        end
        
        function teardownContainer( this, containerId )
            
            fprintf('[%s] Attempting to tear down container: Source=%s, Port=%d\n', datestr(now), this.SqlDataSource, this.Port );
            
            [status, msg] = system( sprintf( 'docker stop %s', containerId ) );
            if status ~= 0
                error( ...
                    'Database:FailedToStopContainer', ...
                    'Failed to stop docker container [%s]:\n%s', ...
                    containerId, msg );
            end
            [status, msg] = system( sprintf( 'docker rm %s', containerId ) );
            if status ~= 0
                error( ...
                    'Database:FailedToDeleteContainer', ...
                    'Failed to delete docker container [%s]:\n%s', ...
                    containerId, msg );
            end
        end
        
        function source = createDataSourceName( this )
            
            %to create a unique source name we use the format:
            % lh:PortNumber_timeStamp
            timeStamp = datestr(now, 'dd-mm_HH:MM:SS.FFF');
            source = sprintf( 'lh:%d_%s', this.Port, timeStamp);
            
        end
        
    end
    
    methods (Access = protected)
        
        function bool = isCompatible(fixture,other)
            sameSetup = isequal(fixture.SetupFcn, other.SetupFcn);
            sameFixture = strcmp(class(fixture), class(other));
            bool = sameSetup && sameFixture;
        end
        
        function initializeDatabaseConnection( this )
            
            src = this.SqlDataSource;
            u = this.TestingUser;
            p = this.TestingPassword;
            conn = database(src,u,p);
            
            this.DatabaseConnection = conn;
            this.addTeardown( @() this.disconnect );
            
        end
        
    end
    
    % ODBC Data Source creating
    methods (Static,Access = private)
        
        function deleteOdbcSource( name )
            
            systemCommand = sprintf( 'powershell -Command "& {Remove-OdbcDsn -Name "%s" -DsnType "User"}"', ...
                name );
            system( systemCommand );
            
        end
        
        function port = getFreePort
            
            % Returns an available port number.
            socket = java.net.ServerSocket(0);
            port = socket.getLocalPort();
            socket.close();
            
        end
        
    end
    
    methods (Static,Access = protected)
        
        function updateOdbcDataSource( type, varargin )
            
            assert( mod( numel( varargin ), 2 ) == 0, ...
                'dockerDBTestTool:InvalidArguments', ...
                'Arguments must be type, followed by name-value pair.' );
            arguments = varargin(1:2:end) + "=" + varargin(2:2:end);
            arguments = strjoin( arguments, '|' );
            systemCommand = sprintf( ...
                'ODBCConf /A {CONFIGDSN "%s" "%s"}', ...
                type, arguments );
            system( systemCommand );
            
        end
        
    end
    
    % Server specific
    methods (Abstract,Access = protected)
        
        createOdbcDataSource(this)
        containerId = getDockerImageInitCall(this)
        createEmptyDatabaseAndUser(this)
        ok = doesSchemaExist(this,schemaName)
        executeSqlOnContainer(this,varargin)
        makeBackupAndRestore(this,sourceDb,destinationDb,bakFile)
        dropDatabase(this,databaseName)
        importDatabase(this,filename);
        checkpoints = getCheckpointNames(this)
        tableNames = getAllTableNames(this)
        
    end
    
end