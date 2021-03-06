CASSANDRA_VERSION=311x

if [ -x "$(command -v cassandra)" ]; then
    echo "Cassandra already installed"
    exit
fi

apt-get update
apt-get install -y openjdk-8-jdk

echo "deb http://www.apache.org/dist/cassandra/debian $CASSANDRA_VERSION main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list

wget --no-check-certificate -qO - https://www.apache.org/dist/cassandra/KEYS | apt-key add -

apt-get update
apt-get -y install cassandra

CASSANDRA_CONF=/etc/cassandra/cassandra.yaml
RACKDC_CONF=/etc/cassandra/cassandra-rackdc.properties
CASSANDRA_ENV=/etc/cassandra/cassandra-env.sh

cp ${CASSANDRA_CONF} /tmp/cassandra.yaml
cp ${RACKDC_CONF} /tmp/cassandra-rackdc.properties
cp ${CASSANDRA_ENV} /tmp/cassandra-env.sh

sudo systemctl enable cassandra

# Install prometheus exporter
CASS_EXPORTER_VERSION=2.3.5
CASS_EXPORTER=/usr/share/cassandra/lib/cassandra_exporter-${CASS_EXPORTER_VERSION}.jar
sudo curl -sSL -o ${CASS_EXPORTER} \
    https://github.com/criteo/cassandra_exporter/releases/download/${CASS_EXPORTER_VERSION}/cassandra_exporter-${CASS_EXPORTER_VERSION}.jar

