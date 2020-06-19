classdef (Abstract) Postgre < dbtest.fixtures.DockerDatabase
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    properties (Constant,Access = protected)
        DefaultUsername = 'postgres'
        TestingDatabase = 'testing'
    end
    
    properties (Constant)
        EULALink = 'https://hub.docker.com/_/postgres';
    end
    
    properties (Abstract,Constant,Access = protected)
        ServerVersion
    end
    
    methods (Access = protected)
        
        function createOdbcDataSource(this)
            % Update the data source
            this.updateOdbcDataSource( ...
                "PostGreSQL ANSI(x64)",...
                "DSN", this.SqlDataSource, ...
                "Server", "localhost", ...
                "Port", this.Port );
        end
        
        function cmdLine = getDockerImageInitCall(this)
            
            cmdLine = sprintf('docker run -e POSTGRES_PASSWORD=%s -p %d:5432 -d %s', ...
                this.SAPassword, ...
                this.Port, ...
                this.ServerVersion);
            
        end
        
        function createEmptyDatabaseAndUser(this)
            
            % Create new database and a user to go with it.
            db = database( this.SqlDataSource, this.DefaultUsername, this.SAPassword );
            
            db.execute("CREATE ROLE " + this.TestingUser ...
                + " SUPERUSER INHERIT CREATEROLE CREATEDB " ...
                + "LOGIN REPLICATION " ...
                + "PASSWORD '" + this.TestingPassword + "'");
            
            % I need to set the database name to the same as the
            % user.
            db.execute("CREATE DATABASE " + this.TestingUser + ...
                " OWNER '" + this.TestingUser + "'");
            
            db.close()
            
        end
        
        function makeBackupAndRestore(this,sourceDb,destinationDb,bakFile)
            
            sqlBak  = sprintf('pg_dump -U %s -Fc %s > %s;', this.TestingUser, sourceDb, bakFile );
            sqlCrDB = sprintf('createdb %s -U %s;', destinationDb, this.TestingUser);
            sqlRest = getRestoreQuery(this, destinationDb, bakFile);
            
            this.executeSqlOnContainer( [sqlBak, sqlCrDB, sqlRest] );
            
        end
        
        function importDatabase( this, bakFile )
            
            % Import the file into docker.
            sqlRest = getRestoreQuery(this, this.TestingDatabase, bakFile);
            this.executeSqlOnContainer(sqlRest);
            
        end
        
        function dropDatabase(this,databaseName)
            % check that user is not attempting to drop postgre TODO
            
            % Log in as default postgre
            db = database( this.SqlDataSource, this.DefaultUsername, this.SAPassword );
            
            db.execute( sprintf('DROP DATABASE "%s"', databaseName) );
            
            %If I am dropping the main database, I need to remake it:
            if strcmp(databaseName, this.TestingDatabase)
                db.execute("CREATE DATABASE " + this.TestingUser + ...
                    " OWNER '" + this.TestingUser + "'");
            end
            
            db.close()
        end
        
        function executeSqlOnContainer(this,sql)
            
            sqlCmd = sprintf( 'docker exec -i %s sh -c "%s"', ...
                this.ContainerId, sql );
            [status, cmdout] = system( sqlCmd );  %#ok<ASGLU>
            
            % Check the output to see if anything's gone wrong. Most
            % frequent case is when there's still a connection handle to
            % the database stopping the DROP command from running.
            if(~isempty(cmdout) && contains(cmdout,'Cannot drop database'))
                errid = 'dbtest:PostgreSqlServer:ConnectionToDatabaseNotDeleted';
                errmsg = 'An open connection to the database is stopping it from being modified';
                error(errid,errmsg)
            end
            
        end
        
        function checkpoints = getCheckpointNames(this)
            
            % Get all catalogs (databases) from the connection
            conn = database(this.SqlDataSource,this.DefaultUsername,this.SAPassword);
            db = conn.select('SELECT datname FROM pg_database');
            checkpoints = db.datname;
            
            % Remove default databases plus main working database from the
            % checkpoint list.
            toRemove = {this.TestingDatabase 'postgres' 'template1' 'template0'};
            [~,idx] = intersect(checkpoints,toRemove);
            checkpoints(idx) = [];
            
            % Convert to string
            checkpoints = string(checkpoints);
            
        end
        
        function tableNames = getAllTableNames(this)
            
            sql = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE table_schema NOT IN ('pg_catalog', 'information_schema');";
            
            tbls = this.DatabaseConnection.select(sql);
            tableNames = string(table2cell(tbls));
            
        end
        
        function ok = doesSchemaExist(this,schemaName)
            
            db = this.DatabaseConnection;
            
            sql = "SELECT COUNT(*) AS SchemaCount " + ...
                "FROM information_schema.schemata " + ...
                "WHERE schema_name = '" + schemaName + "';";
            
            res = db.select(sql);
            
            ok = res.schemacount > 0;
            
        end
        
    end
    
end

function sqlRest = getRestoreQuery(this, destinationDb, bakFile)

sqlRest = sprintf('pg_restore -U %s -c -d %s < %s;',...
    this.TestingUser, destinationDb, bakFile);

end