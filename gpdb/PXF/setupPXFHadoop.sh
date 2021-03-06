#!/bin/bash
set -e

export GPDB_HOSTS=/tmp/gpdb-hosts
source /usr/local/greenplum-db/greenplum_path.sh

# TAR.GZ settings
export CLOUDERA_HADOOP_TAR_GZ=hadoop-2.6.0-cdh5.10.2.tar.gz
export CLOUDERA_URL=http://archive.cloudera.com/cdh5/cdh/7/

# RPM settings
export CLOUDERA_RPM_REPO=https://archive.cloudera.com/cdh5/redhat/7/x86_64/cdh/cloudera-cdh5.repo
export HORTONWORKS_RPM_REPO=http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/2.6.2.0/hdp.repo

# Change to temporary directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Including files
. "${DIR}"/util.sh

###############################################################################
function InstallJDK_ALLSEGMENTS()
{
  echo "Install Java on each Greenplum Database segment host"
  # Fix this issue "Rpmdb checksum is invalid: dCDPT(pkg checksums)"
  gpssh -e -v -f ${GPDB_HOSTS} -u root rpm --rebuilddb
  gpssh -e -v -f ${GPDB_HOSTS} -u root yum -y update
  #;  yum clean all
  gpssh -e -v -f ${GPDB_HOSTS} -u root yum -y install wget

  gpssh -e -v -f ${GPDB_HOSTS} -u root yum -y install java-1.8.0-openjdk
  # sudo yum install java-1.8.0-openjdk
  # sudo yum install java-1.7.0-openjdk
  # sudo yum install java-1.6.0-openjdk

  echo "Update the gpadmin user’s .bash_profile file on each segment host to include this $JAVA_HOME setting"

  export JRE_HOME=$(pwd /usr/lib/jvm/java-1.8.0-openjdk-*/jre_)

  echo "JRE_HOME : ${JRE_HOME}"
  echo "Add Java home to gpadmin bashrc"
  gpssh -e -v -f ${GPDB_HOSTS} -u gpadmin "echo 'export JAVA_HOME=/usr/lib/jvm/jre-openjdk/' >> /home/gpadmin/.bash_profile"

  #yum clean all \
  #&& rm -rf /var/cache/yum
}
###############################################################################
function InstallJDK()
{
  echo "Install Java on this host"
  # Fix this issue "Rpmdb checksum is invalid: dCDPT(pkg checksums)"
  rpm --rebuilddb
  #;  yum clean all
  yum -y install wget
  yum -y install java-1.8.0-openjdk
  yum clean all
  # sudo yum install java-1.8.0-openjdk
  # sudo yum install java-1.7.0-openjdk
  # sudo yum install java-1.6.0-openjdk

  echo "Update the gpadmin user’s .bash_profile file on each segment host to include this $JAVA_HOME setting"
  export JRE_HOME=$(pwd /usr/lib/jvm/java-1.8.0-openjdk-*/jre_)

  echo "JRE_HOME : ${JRE_HOME}"
  echo "Add Java home to gpadmin bashrc"
  echo 'export JAVA_HOME=/usr/lib/jvm/jre-openjdk/' >> /home/gpadmin/.bash_profile

  #yum clean all \
  #&& rm -rf /var/cache/yum
}
###############################################################################
function InstallCDH_RPM()
{
  echo "Download Cloudera REPO : $CLOUDERA_RPM_REPO"
  gpssh -v -f ${GPDB_HOSTS}  -u gpadmin  wget $CLOUDERA_RPM_REPO -O /tmp/cloudera-cdh5.repo

  echo "Run 'sudo yum -y install hadoop-client' to all segments"
  # yes is required for copy prompt
  gpssh -e -v -f ${GPDB_HOSTS} -u root   "echo yes | cp -f /tmp/cloudera-cdh5.repo  /etc/yum.repos.d"

  echo "Run 'sudo yum -y install hadoop-client' to all segments"
  gpssh -f ${GPDB_HOSTS}  -u gpadmin  "sudo yum -y install hadoop-client"

  echo "Run 'sudo yum list installed hadoop-client"
  gpssh -e -v -f ${GPDB_HOSTS} -u root yum list installed hadoop-client
}
###############################################################################
function InstallCDH_TAR()
{
  cd /tmp

  echo "Download Cloudera 2.6-cdh5"
  wget $CLOUDERA_URL$CLOUDERA_HADOOP_TAR_GZ -O /tmp/$CLOUDERA_HADOOP_TAR_GZ

  echo "Copy Cloudera 2.6 to all segments"
  gpscp -v -f ${GPDB_HOSTS} -u gpadmin  /tmp/hadoop-2.6.0-cdh5.10.2.tar.gz =:/home/gpadmin
  echo "Extract Cloudera 2.6 to all segments"
  gpssh -e -v -f ${GPDB_HOSTS} -u gpadmin "tar zxf /home/gpadmin/hadoop-2.6.0-cdh5.10.2.tar.gz"

  gpssh -e -v -f ${GPDB_HOSTS}  -u gpadmin "chmod -R 755 /home/gpadmin/hadoop-2.6.0-cdh5.10.2"

  echo "export PXF_HADOOP_HOME"
  gpssh -e -v -f ${GPDB_HOSTS}  -u gpadmin "echo 'export PXF_HADOOP_HOME=/home/gpadmin/hadoop-2.6.0-cdh5.10.2' >> /home/gpadmin/.bash_profile"

  echo "export HADOOP_HOME"
  gpssh -e -v -f ${GPDB_HOSTS}  -u gpadmin "echo 'export HADOOP_HOME=/home/gpadmin/hadoop-2.6.0-cdh5.10.2' >> /home/gpadmin/.bash_profile"

  echo "rm /home/gpadmin/hadoop-2.6.0-cdh5.10.2.tar.gz"
  gpssh -e -v -f ${GPDB_HOSTS} -u gpadmin "rm /home/gpadmin/hadoop-2.6.0-cdh5.10.2.tar.gz"

  rm /tmp/$CLOUDERA_HADOOP_TAR_GZ
  # Install AVRO JAR file
  wget "http://central.maven.org/maven2/org/apache/avro/avro-mapred/1.7.1/avro-mapred-1.7.1.jar"

  echo "Copy avro-mapred-*.jar"
  gpscp -v -f ${GPDB_HOSTS} -u gpadmin avro-mapred-*.jar =:/home/gpadmin/hadoop-2.6.0-cdh5.10.2/share/hadoop/common/lib
  rm avro-mapred-1.7.1.jar
}
###############################################################################

# Main
startSSH
InstallJDK_ALLSEGMENTS

#InstallJDK
InstallCDH_RPM

#InstallCDH_TAR
