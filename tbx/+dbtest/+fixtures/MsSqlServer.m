classdef (Abstract) MsSqlServer < dbtest.fixtures.DockerDatabase
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties (Abstract,Constant,Access = protected)
        ServerVersion
    end
    
    properties (Constant, Access = protected)
        DefaultUsername = 'sa'
        TestingDatabase = 'DatabaseTesting'
    end
    
    properties (Constant)
        EULALink = 'https://hub.docker.com/_/microsoft-mssql-server';
    end
    
    methods (Access = protected)
        
        function createOdbcDataSource(this)
            % Update the data source
            this.updateOdbcDataSource( ...
                "SQL Server", ...
                "DSN", this.SqlDataSource, ...
                "Server", sprintf( "localhost,%d", this.Port ) );
        end
        
        function cmdLine = getDockerImageInitCall(this)
            
            cmdLine = sprintf( ...
                'docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=%s" -p %d:1433 -d mcr.microsoft.com/mssql/server:%s', ...
                this.SAPassword, ...
                this.Port, ...
                this.ServerVersion ...
                );
            
        end
        
        function createEmptyDatabaseAndUser(this)
            
            % Create new database and a user to go with it.
            db = database( this.SqlDataSource, this.DefaultUsername, this.SAPassword );
            
            db.execute(['CREATE DATABASE ' this.TestingDatabase]);
            db.execute(['CREATE LOGIN ' this.TestingUser ...
                ' WITH PASSWORD = ''' this.TestingPassword ....
                ''', DEFAULT_DATABASE = ' this.TestingDatabase]);
            db.execute(['USE ' this.TestingDatabase]);
            db.execute(['CREATE USER ' this.TestingUser ' FROM LOGIN ' this.TestingUser]);
            db.execute(['EXEC sp_addrolemember ''db_owner'', ''' this.TestingUser ''';']);
            
            db.close()
            
        end
        
        function makeBackupAndRestore( this, sourceDb, destinationDb, bakFile )
            
            sqlBak  = sprintf('BACKUP DATABASE %s TO DISK=''%s''; ',sourceDb, bakFile);
            
            sqlRest = getRestoreQuery(this, destinationDb, bakFile);
            
            this.executeSqlOnContainer([sqlBak, sqlRest]);
            
        end
        
        function importDatabase( this, bakFile )
            
            sqlRest = getRestoreQuery(this, this.TestingDatabase, bakFile);
            
            this.executeSqlOnContainer(sqlRest);
            
            db = database( this.SqlDataSource, this.DefaultUsername, this.SAPassword );
            
            db.execute("USE " + this.TestingDatabase);
            db.execute("ALTER LOGIN " + this.TestingUser + " WITH DEFAULT_DATABASE = " + this.TestingDatabase)
            db.execute("ALTER USER " + this.TestingUser + " WITH LOGIN = " + this.TestingUser);
            
            db.close()
            
        end
        
        function dropDatabase( this, databaseName )
            
            this.executeSqlOnContainer( sprintf('DROP DATABASE %s', databaseName) );
            
        end
        
        function executeSqlOnContainer( this, sql )
            
            sqlCmd = sprintf( 'docker exec %s /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P %s -Q "%s"', ...
                this.ContainerId, this.SAPassword, sql );
            [status, cmdout] = system( sqlCmd );  %#ok<ASGLU>
            
            % Check the output to see if anything's gone wrong. Most
            % frequent case is when there's still a connection handle to
            % the database stopping the DROP command from running.
            if(~isempty(cmdout) && contains(cmdout,'Cannot drop database'))
                errid = 'dbtest:MsSqlServer:ConnectionToDatabaseNotDeleted';
                errmsg = 'An open connection to the database is stopping it from being modified';
                error(errid,errmsg)
            end
            
        end % executeSqlOnContainer
        
        function checkpoints = getCheckpointNames(this)
            
            % Need to connect as SA for some reason
            conn = database(this.SqlDataSource,this.DefaultUsername,this.SAPassword);
            checkpoints = conn.Catalogs;
            
            % Remove default databases plus main working database from the
            % checkpoint list.
            toRemove = {this.TestingDatabase 'master' 'msdb' 'tempdb'};
            [~,idx] = intersect(checkpoints,toRemove);
            checkpoints(idx) = [];
            
            % Convert to string
            checkpoints = string(checkpoints);
            
        end
        
        function tableNames = getAllTableNames(this)
            
            sql = 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES';
            
            tbls = this.DatabaseConnection.select(sql);
            tableNames = string(table2cell(tbls));

        end
        
        function ok = doesSchemaExist(this,schemaName)
            
            db = this.DatabaseConnection;
            
            sql = "SELECT COUNT(*) AS SchemaCount FROM sys.schemas " + ...
                "WHERE name = '" + schemaName + "';";
            
            res = db.select(sql);
            
            ok = res.SchemaCount > 0;
            
        end
        
    end
    
end

function sqlRest = getRestoreQuery(this, destinationDb, bakFile)

sqlRest = sprintf('RESTORE DATABASE %s FROM DISK=''%s'' WITH MOVE ''%s'' TO ''/var/opt/mssql/data/%s.mdf'', MOVE ''%s_log'' TO ''/var/opt/mssql/data/%s_log.ldf''', ...
    destinationDb, bakFile, this.TestingDatabase, ...
    destinationDb, this.TestingDatabase, destinationDb);

end