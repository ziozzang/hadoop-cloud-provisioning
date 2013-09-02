#/bin/bash
[[ "$(id -u)" -eq 0 ]] || (echo "FATAL: Root privilege is required."; exit 1)

FLAG_X86_64=`uname -a | grep x86_64 | wc -l`
CURRENT_IP=`ifconfig eth0 | grep -m 1 'inet addr:' | cut -d: -f2 | awk '{print $1}'`
UBUNTU_VERSION=`cat /etc/lsb-release | grep "DISTRIB_RELEASE" | awk '{split($0,a,"="); print a[2]}'`

if [[ "${UBUNTU_VERSION}" == "10.04" ]]; then
  echo "Ubuntu Lucid/10.04"
else
  echo "Ubuntu Precise/12.04"
fi

# Ubuntu Network ReConfigure // =============================================================


# Ubuntu TurnOff FireWall  // =============================================================
ufw disable

# Ubuntu SSH ReConfigure // =============================================================
#sed -i -e "s,#\(RSAAuthentication\).*,\1 yes,g" /etc/ssh/sshd_config
#sed -i -e "s,#\(PubkeyAuthentication\).*,\1 yes,g" /etc/ssh/sshd_config
sed -i -e "s,#\(AuthorizedKeysFile\).*,\1 %h/.ssh/authorized_keys,g" /etc/ssh/sshd_config
service ssh restart

# Ubuntu Pre-Provisioning. // =============================================================
sed -i -e "s,kr\.archive\.ubuntu\.com,ftp\.daum\.net,g" /etc/apt/sources.list

apt-get update -fy
apt-get upgrade -fy
apt-get install -fy curl python-pip python-flask

sed -i -e "s,ftp\.daum\.net,kr\.archive\.ubuntu\.com,g" /etc/apt/sources.list


# Setup Environment // =============================================================
sed -i -e "s,\(TMOUT\)=.*,\1=0,g" /etc/bash.bashrc

# Python PIP // =============================================================

# Sun/Oracle JAVA Install // =============================================================
if [[ "${FLAG_X86_64}" -eq "0" ]]; then
  # x86
  wget http://home.jioh.net/jdk/jdk-7u25-linux-i586.gz
else
  #x86_64
  wget http://home.jioh.net/jdk/jdk-7u25-linux-x64.gz
fi
tar -xzvf jdk-7u25-linux-*.gz
rm -f jdk-7u25-linux-*.gz
mkdir /usr/java
mv jdk1.7.0_25 /usr/java/


update-alternatives --install /usr/bin/java java /usr/java/jdk1.7.0_25/bin/java 1
update-alternatives --install /usr/bin/javac javac /usr/java/jdk1.7.0_25/bin/javac 1
update-alternatives --install /usr/bin/jar jar /usr/java/jdk1.7.0_25/bin/jar 1

update-alternatives --set java /usr/java/jdk1.7.0_25/bin/java
update-alternatives --set javac /usr/java/jdk1.7.0_25/bin/javac
update-alternatives --set jar /usr/java/jdk1.7.0_25/bin/jar

cat >> /etc/bash.bashrc << EOF
export JAVA_HOME="/usr/java/jdk1.7.0_25"
export JAVA_PATH="$JAVA_HOME"
export PATH="$PATH:$JAVA_HOME"
EOF


# Hadoop apache Install // =============================================================
if [[ "${FLAG_X86_64}" -eq "0" ]]; then
  # x86
  wget http://apache.mirror.cdnetworks.com/hadoop/common/stable/hadoop_1.2.1-1_i386.deb
  dpkg -i hadoop_1.2.1-1_i386.deb
else
  # x86_64
  wget http://apache.mirror.cdnetworks.com/hadoop/common/stable/hadoop_1.2.1-1_x86_64.deb 
  dpkg -i hadoop_1.2.1-1_x86_64.deb
fi

sed -i -e "s,\(JAVA_HOME\).*,\1=/usr/java/jdk1.7.0_25,g" /etc/hadoop/hadoop-env.sh

chmod +x /usr/sbin/slaves.sh /usr/sbin/start-* /usr/sbin/stop-*

sed -i -r -e 's/-Xmx[0-9]+m//g' /usr/bin/hadoop
sed -i -r -e 's/-Xmx[0-9]+m//g' /usr/sbin/rcc
sed -i -r -e 's/-Xmx[0-9]+m//g' /etc/hadoop/hadoop-env.sh
sed -i -r -e 's/-Xmx[0-9]+m//g' /usr/etc/hadoop/hadoop-env.sh
sed -i -r -e 's/-Xmx[0-9]+m//g' /usr/share/hadoop/templates/conf/hadoop-env.sh

rm -f /root/.ssh/authorized_keys
