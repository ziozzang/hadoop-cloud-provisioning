#!/bin/bash
[[ "$(id -u)" -eq 0 ]] || (echo "FATAL: Root privilege is required."; exit 1)

FLAG_X86_64=`uname -a | grep x86_64 | wc -l`
CURRENT_IP=`ifconfig eth0 | grep -m 1 'inet addr:' | cut -d: -f2 | awk '{print $1}'`

# Centos Network ReConfigure // =============================================================
rm -f /etc/udev/rules.d/70-persistent-net.rules
sed -i -e "s,\(HWADDR.*\),#\1,g" /etc/sysconfig/network-scripts/ifcfg-eth0
/etc/init.d/network restart


# Centos TurnOff FireWall  // =============================================================
service iptables stop
chkconfig iptables off
service ip6tables stop
chkconfig ip6tables off

# Centos SSH ReConfigure // =============================================================
sed -i -e "s,#\(RSAAuthentication\).*,\1 yes,g" /etc/ssh/sshd_config
sed -i -e "s,#\(PubkeyAuthentication\).*,\1 yes,g" /etc/ssh/sshd_config
sed -i -e "s,#\(AuthorizedKeysFile\).*,\1 .ssh/authorized_keys,g" /etc/ssh/sshd_config
/etc/init.d/sshd restart

# Centos Pre-Provisioning. // =============================================================

yum -y update
yum -y install gcc openssh-clients

# Python PIP // =============================================================
wget http://peak.telecommunity.com/dist/ez_setup.py
python ez_setup.py
easy_install pip
pip install flask
yum install -y git

# Sun/Oracle JAVA Install // =============================================================
if [[ "${FLAG_X86_64}" -eq "0" ]]; then
  # x86
  wget http://home.jioh.net/jdk/jdk-7u25-linux-i586.rpm
  rpm -Uvh jdk-7u25-linux-i586.rpm

else
  #x86_64
  wget http://home.jioh.net/jdk/jdk-7u25-linux-x64.rpm
  rpm -Uvh jdk-7u25-linux-x64.rpm
fi

lternatives --auto jar
alternatives --install /usr/bin/java java /usr/java/jdk1.7.0_25/bin/java 1
alternatives --install /usr/bin/javac javac /usr/java/jdk1.7.0_25/bin/javac 1
alternatives --install /usr/bin/jar jar /usr/java/jdk1.7.0_25/bin/jar 1

alternatives --set java /usr/java/jdk1.7.0_25/bin/java
alternatives --set javac /usr/java/jdk1.7.0_25/bin/javac
alternatives --set jar /usr/java/jdk1.7.0_25/bin/jar

cat >> /etc/bashrc << EOF
export JAVA_HOME="/usr/java/jdk1.7.0_25"
export JAVA_PATH="$JAVA_HOME"
export PATH="$PATH:$JAVA_HOME"
EOF


# Hadoop apache rpm Install // =============================================================
if [[ "${FLAG_X86_64}" -eq "0" ]]; then
  # x86
  wget http://apache.mirror.cdnetworks.com/hadoop/common/stable/hadoop-1.2.1-1.i386.rpm
  rpm -Uvh hadoop-1.2.1-1.i386.rpm
else
  # x86_64
  wget http://apache.mirror.cdnetworks.com/hadoop/common/stable/hadoop-1.2.1-1.x86_64.rpm 
  rpm -Uvh hadoop-1.2.1-1.x86_64.rpm
fi

sed -i -e "s,\(export JAVA_HOME\).*,\1=/usr/java/jdk1.7.0_25,g" /etc/hadoop/hadoop-env.sh

chmod +x /usr/sbin/slaves.sh /usr/sbin/start-* /usr/sbin/stop-*

sed -i -r -e 's/-Xmx[0-9]+m//g' /usr/bin/hadoop
sed -i -r -e 's/-Xmx[0-9]+m//g' /usr/sbin/rcc
sed -i -r -e 's/-Xmx[0-9]+m//g' /etc/hadoop/hadoop-env.sh
sed -i -r -e 's/-Xmx[0-9]+m//g' /usr/etc/hadoop/hadoop-env.sh
sed -i -r -e 's/-Xmx[0-9]+m//g' /usr/share/hadoop/templates/conf/hadoop-env.sh

rm -f /root/.ssh/authorized_keys
