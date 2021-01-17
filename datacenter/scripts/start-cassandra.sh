#!/usr/bin/env bash

CASS_EXPORTER_VERSION=2.3.5
CASS_EXPORTER=/usr/share/cassandra/lib/cassandra_exporter-${CASS_EXPORTER_VERSION}.jar

sudo systemctl stop cassandra
sudo systemctl start cassandra
sudo systemctl status cassandra

CASS_EXPORTER_CONF=config.yaml
sudo curl -sSL -o ${CASS_EXPORTER_CONF} https://raw.githubusercontent.com/criteo/cassandra_exporter/${CASS_EXPORTER_VERSION}/config.yml
sed -i "s/listenPort: 8080/listenPort: 7070/g" ${CASS_EXPORTER_CONF}
java -jar $CASS_EXPORTER $CASS_EXPORTER_CONF &
