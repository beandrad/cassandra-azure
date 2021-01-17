#!/usr/bin/env bash
set -euo pipefail

CASSANDRA_CONF=/etc/cassandra/cassandra.yaml
RACKDC_CONF=/etc/cassandra/cassandra-rackdc.properties
CASS_EXPORTER_VERSION=2.3.5
CASS_EXPORTER=/usr/share/cassandra/lib/cassandra_exporter-${CASS_EXPORTER_VERSION}.jar

java -jar $CASS_EXPORTER stop &>/dev/null

nodetool drain
nodetool status

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

sudo rm -rf /var/lib/cassandra/system/*
sudo rm -rf /var/lib/cassandra/data/*
