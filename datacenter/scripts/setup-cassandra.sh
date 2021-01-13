#!/usr/bin/env bash
set -euo pipefail

CASSANDRA_CONF=/etc/cassandra/cassandra.yaml
RACKDC_CONF=/etc/cassandra/cassandra-rackdc.properties

sudo systemctl stop cassandra

# parameters: cluster_name seeds node_private_ip dc
sudo cp /tmp/cassandra.yaml ${CASSANDRA_CONF}
sudo sed -i "s/cluster_name: 'Test Cluster'/cluster_name: '$1'/g" ${CASSANDRA_CONF}
sudo sed -i "s/seeds: .*/seeds: '$2'/g" ${CASSANDRA_CONF}
sudo sed -i "s/listen_address: localhost/# listen_address: localhost/g" ${CASSANDRA_CONF}
sudo sed -i "s/# listen_interface: eth0/listen_interface: eth0/g" ${CASSANDRA_CONF}
sudo sed -i "s/start_rpc: false/start_rpc: true/g" ${CASSANDRA_CONF}
sudo sed -i "s/rpc_address: localhost/# rpc_address: localhost/g" ${CASSANDRA_CONF}
sudo sed -i "s/# rpc_interface: eth1/rpc_interface: eth0/g" ${CASSANDRA_CONF}
sudo sed -i "s/# broadcast_rpc_address: 1.2.3.4/broadcast_rpc_address: $3/g" ${CASSANDRA_CONF}
sudo sed -i "s/endpoint_snitch: SimpleSnitch/endpoint_snitch: GossipingPropertyFileSnitch/g" ${CASSANDRA_CONF}

sudo cp /tmp/cassandra-rackdc.properties ${RACKDC_CONF}
sudo sed -i "s/dc=dc1/dc=$4/g" ${RACKDC_CONF}

# setup prometheus. From https://github.com/criteo/cassandra_exporter
CASSANDRA_ENV=/etc/cassandra/cassandra-env.sh
sudo cp /tmp/cassandra-env.sh ${CASSANDRA_ENV}

CASS_EXPORTER_VERSION=2.3.5
CASS_EXPORTER=/usr/share/cassandra/lib/cassandra_exporter-${CASS_EXPORTER_VERSION}.jar
sudo curl -sSL -o ${CASS_EXPORTER} \
    https://github.com/criteo/cassandra_exporter/releases/download/${CASS_EXPORTER_VERSION}/cassandra_exporter-${CASS_EXPORTER_VERSION}.jar
# TODO: fetch from config repo
CASS_EXPORTER_CONF=config.yaml
sudo curl -sSL -o ${CASS_EXPORTER_CONF} https://raw.githubusercontent.com/criteo/cassandra_exporter/${CASS_EXPORTER_VERSION}/config.yml
sed -i "s/listenPort: 8080/listenPort: 7070/g" ${CASS_EXPORTER_CONF}

sudo rm -rf /var/lib/cassandra/system/*
sudo rm -rf /var/lib/cassandra/data/*

sudo systemctl start cassandra
sudo systemctl status cassandra

java -jar $CASS_EXPORTER config.yaml &
