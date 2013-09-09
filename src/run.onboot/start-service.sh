#!/bin/bash

CURRENT_DIR=`pwd`
# ubuntu /var/lib/dhcp/dhclient.eth0.leases
OS_DIST=`cat /etc/issue | head -n 1 | awk '{print $1}'`
if [[ "$OS_DIST" == "Ubuntu" ]]; then
  DHCP_LOG_PATH="/var/lib/dhcp/dhclient.eth0.leases"
elif [[ "$OS_DIST" == "CentOS" ]]; then
  DHCP_LOG_PATH="/var/lib/dhclient/dhclient-eth0.leases"
else
  echo "doesn't support."
  exit 1
fi
META_IP=`cat ${DHCP_LOG_PATH} | grep dhcp-server-identifier | awk '{print $3}' | sed -e 's/;//' | tail -n 1`
CURRENT_IP=`ifconfig eth0 | grep -m 1 'inet addr:' | cut -d: -f2 | awk '{print $1}'`
USER_DATA="user_data.env"
SLAVE_DATA="slave_data.env"
CPU_COUNT=`awk -F: '/^physical/ && !ID[$2] { P++; ID[$2]=1 }; /^cpu cores/ { CORES=$2 };  END { print CORES*P }' /proc/cpuinfo`

# Target Memory Usage Percentage
USAGE_PERCENT=95
TOTAL_MEM_KB=$(awk '/MemTotal:/ { print $2 }' /proc/meminfo)
# heap size in KB
let TARGET_HEAP_MB=(${TOTAL_MEM_KB}*${USAGE_PERCENT}/100)/1024

if [[ -f "${USER_DATA}" ]]; then
  rm -f ${USER_DATA}.org
fi
wget -O ${USER_DATA}.org http://${META_IP}/latest/user-data
grep -v "hadoop-conf-setter" ${USER_DATA}.org > ${USER_DATA}
grep "hadoop-conf-setter" ${USER_DATA}.org > ${USER_DATA}.conf
source ${USER_DATA} || (echo "FATAL: ${USER_DATA} failed"; exit 1)

DISK_COUNT=0

# 슬레이브가 마스터의 유저 정보를 받아옴.
MASTER_IP=${MASTER_IP:-"none"}
if [[ "${MASTER_IP}" == "none" ]]; then
  grep -v "MASTER_IP" ${USER_DATA} > ${SLAVE_DATA}
else
  if [[ ! -f "${SLAVE_DATA}" ]]; then
    while :
    do
      wget -O ${SLAVE_DATA} http://${MASTER_IP}:7777/meta-data/
      if [[ "$?" -eq "0" ]]; then
        break
      fi
      sleep 5
    done
  fi
  source ${SLAVE_DATA} || (echo "FATAL: ${SLAVE_DATA} failed"; exit 1)
fi

#MASTER_IP=${MASTER_IP:-"none"}
LVM_EXPAND=${LVM_EXPAND:-"yes"}
MOUNT_ATTACH=${MOUNT_ATTACH:-"yes"}
DFS_REPLICATION=${DFS_REPLICATION:-"3"}
DFS_BLOCKSIZE=${DFS_BLOCKSIZE:-"64m"}
JVM_XMX=${JVM_XMX:-"1g"}
JVM_XMS=${JVM_XMS:-"1g"}
MR_SYSTEM_SUFFIX=${MR_SYSTEM_SUFFIX:-"/mapred/system"}
MR_SYSTEM_DIR=${MR_SYSTEM_DIR:-"/var/log/hadoop"}
MR_LOCAL_SUFFIX=${MR_LOCAL_SUFFIX:-"/mapred/local"}
MR_LOCAL_DIR=${MR_LOCAL_DIR:-"/var/log/hadoop"}
DFS_NAME_SUFFIX=${DFS_NAME_SUFFIX:-"/hdfs/namenode"}
DFS_NAME_DIR=${DFS_NAME_DIR:-"/var/lib/hadoop"}
DFS_DATA_SUFFIX=${DFS_DATA_SUFFIX:-"/hdfs/datanode"}
DFS_DATA_DIR=${DFS_DATA_DIR:-"/var/lib/hadoop"}
REMOVE_HOSTNAME=${REMOVE_HOSTNAME:-"no"}
EMAIL=${EMAIL:-"noname@localhost"}

if [[ ! "${REMOVE_HOSTNAME}" == "no" ]]; then
  hostname ${CURRENT_IP}
  OS_DIST=`cat /etc/issue | head -n 1 | awk '{print $1}'`
  if [[ "${OS_DIST}" == "CentOS" ]]; then
    sed -i -e "s,\(HOSTNAME\)=.*,\1=${CURRENT_IP},g" /etc/sysconfig/network
    /etc/init.d/network restart
  elif [[ "${OS_DIST}" == "Ubuntu" ]]; then
    service networking restart
  fi
fi


LVM_ON_ROOT=`mount | grep " / " | grep "/dev/mapper" | wc -l`
# Attached Disk Expand
if [[ "${LVM_EXPAND}" == "yes" ]]; then
  # Disk Expand
  if [[ $LVM_ON_ROOT -gt 0 ]]; then
    bash ${CURRENT_DIR}/expand_lvm
  fi
fi

# Append Disk
if [[ "${MOUNT_ATTACH}" == "yes" ]]; then
  # Disk Attach
  bash ${CURRENT_DIR}/vol_attach
  DISK_COUNT=$?
fi

check_dir()
{
  DISKS=$1 # comma seperated directory
  #$2 # Suffix
  #$3 # permissions

  RES=""

  if [[ $DISK_COUNT -gt 0 ]]; then
    for i in $(seq 1 ${DISK_COUNT}); do
      DISKS="${DISKS},/data${i}"
    done
  fi

  #(
  IFS=','
  for prefix in $DISKS; do
    if [[ ! -d "${prefix}$2" ]]; then
      mkdir -p ${prefix}$2
      if [ $3 ]; then
        chown -R $3 ${prefix}$2
      fi
    fi
    RES="${RES},${prefix}$2"
  done
  #)
  RES=${RES:1:9999}
  echo "PATH: ${RES}"
}

# if new directories added, append this to DIRS.
#check_dir 

# Make Directory
check_dir "${DFS_NAME_DIR}" "${DFS_NAME_SUFFIX}" hdfs:hadoop
DFS_NAME_PATHS="${RES}"

check_dir "${DFS_DATA_DIR}" "${DFS_DATA_SUFFIX}" hdfs:hadoop
DFS_DATA_PATHS="${RES}"

check_dir "${MR_SYSTEM_DIR}" "${MR_SYSTEM_SUFFIX}" 
MR_SYSTEM_PATHS="${RES}"

check_dir "${MR_LOCAL_DIR}" "${MR_LOCAL_SUFFIX}"
MR_LOCAL_PATHS="${RES}"


# Role Based Actions.
if [[ "${MASTER_IP}" == "none" ]]; then
  # Do as Master.
  RSA_KEY_LEN=${RSA_KEY_LEN:-"2048"}
  HADOOP_REPLICATION=${HADOOP_REPLICATION:-"3"}
  
  if [[ ! -f "/root/.ssh/id_rsa" ]]; then
    # no key
    ssh-keygen -t rsa -q -f key -N "" -P "" -b ${RSA_KEY_LEN} -C "${EMAIL}"
    mkdir /root/.ssh
    mv key /root/.ssh/id_rsa
    mv key.pub /root/.ssh/authorized_keys
    cat > /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

    chmod  700 /root/.ssh
    chmod  600 /root/.ssh/*
    restorecon -R -v /root/.ssh
  fi

  # Generatet Config.
  if [[ ! -f "hd_configured" ]]; then
    # Set Master IP
    cat > /etc/hadoop/core-site.xml << EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
  <name>fs.default.name</name>
  <value>hdfs://${CURRENT_IP}:9000</value>
 </property>
</configuration>
EOF

    # http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml
    cat > /etc/hadoop/hdfs-site.xml << EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
<property>
  <name>hadoop.tmp.dir</name>
  <value>/tmp/hadoop-\${user.name}</value>
</property>
<property>
  <name>fs.default.name</name>
  <value>hdfs://${CURRENT_IP}:9000</value>
</property>
<property>
  <name>dfs.http.address</name>
  <value>${CURRENT_IP}:50070</value>
</property>
<property>
  <name>dfs.name.dir</name>
  <value>${DFS_NAME_PATHS}</value>
</property>
<property>
  <name>dfs.data.dir</name>
  <value>${DFS_DATA_PATHS}</value>
</property>
<property>
  <name>dfs.replication</name>
  <value>${DFS_REPLICATION}</value>
</property>
<property>
  <name>dfs.blocksize</name>
  <value>${DFS_BLOCKSIZE}</value>
</property>
<property>
  <name>dfs.safemode.threshold.pct</name>
  <value>1.0f</value>
</property>
</configuration>
EOF

    cat > /etc/hadoop/mapred-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
     <name>mapred.system.dir</name>
     <value>${MR_SYSTEM_PATHS}</value>
  </property>
  <property>
     <name>mapred.local.dir</name>
     <value>${MR_LOCAL_PATHS}</value>
  </property>
  <property>
     <name>mapred.job.tracker</name>
     <value>${CURRENT_IP}:9001</value>
  </property>
  <property>
     <name>mapred.child.jvm.opts</name>
     <value>-Xmx${JVM_XMX} -Xms${JVM_XMS}</value>
  </property>
</configuration>
EOF

    truncate --size 0 /etc/hadoop/slaves
    
    # Execute hadoop-conf-setter
    bash ${USER_DATA}.conf
    
    echo "${CURRENT_IP}" > /etc/hadoop/masters
    tar -czvf /var/hadoop/provsioning/conf.tgz /etc/hadoop
    md5sum -b /var/hadoop/provsioning/conf.tgz  | awk '{print $1}' > /var/hadoop/provsioning/conf.md5
    touch hd_configured
  fi

  # Formating
  if [[ ! -f "hdfs_formated" ]]; then
    hadoop namenode -format -force
    touch hdfs_formated
  fi

  python /var/hadoop/provsioning/mst_dm.py > /var/log/mst_dm.log 2> /var/log/mst_dm.err &

else
  # Do as Slave.
  while :
  do
    curl http://${MASTER_IP}:7777/
    if [[ "$?" -eq "0" ]]; then
      break
    fi
    sleep 5
  done

  # Key Copy
  mkdir /root/.ssh
  rm -f /root/.ssh/authorized_keys
  wget -O /root/.ssh/authorized_keys http://${MASTER_IP}:7777/pubkey/
  chmod  700 /root/.ssh
  chmod  600 /root/.ssh/*
  if [[ "${OS_DIST}" == "CentOS" ]]; then
    # CentOS bug fix.
    restorecon -R -v /root/.ssh
    /etc/init.d/sshd restart
  fi

  # Configuration Update
  ${CURRENT_DIR}/conf_updater ${MASTER_IP} > /dev/null 2> /dev/null &

fi


