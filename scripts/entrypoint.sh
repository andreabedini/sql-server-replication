#!/bin/bash

# Enable job control
set -m

/opt/mssql/bin/mssql-conf set sqlagent.enabled true
/opt/mssql/bin/mssql-conf set hadr.hadrenabled 1
/opt/mssql/bin/mssql-conf set memory.memorylimitmb 2048

/opt/mssql/bin/sqlservr --accept-eula &

export SQLCMDUSER=sa
export SQLCMDPASSWORD=$SA_PASSWORD
export SQLCMDSERVER=localhost

# Connect to server and get the version:
counter=1
errstatus=1
while [ $counter -le 10 ] && [ $errstatus = 1 ]
do
  echo Waiting for SQL Server to start...
  sleep 3s
  /opt/mssql-tools/bin/sqlcmd -Q "SELECT @@VERSION" 2>/dev/null
  errstatus=$?
  ((counter++))
done

# Display error if connection failed:
if [ $errstatus = 1 ]
then
  echo Cannot connect to SQL Server, installation aborted
  exit $errstatus
fi

if [ "$HOSTNAME" = "master" ]; then
  # run the setup script to create the DB and the schema in the DB
  # if this is the primary node, remove the certificate files.
  # if docker containers are stopped, but volumes are not removed, this certificate will be persisted
  rm -f /var/opt/mssql/shared/aoag_certificate.key
  rm -f /var/opt/mssql/shared/aoag_certificate.cert

  /opt/mssql-tools/bin/sqlcmd -i ./create_sample_database.sql
  /opt/mssql-tools/bin/sqlcmd -i ./master.sql
else
  # Wait an extra 10 seconds to give the master time to set up.
  sleep 10
  /opt/mssql-tools/bin/sqlcmd -i ./replica.sql
fi

echo "Initialisation done, returning control to SQLServer"

fg
