#!/bin/bash

cat > /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

HADOOP_EXEC=`cat /etc/rc.local | grep hadoop | wc -l`
if [ "$HADOOP_EXEC" -eq "0" ]; then
  echo "/bin/bash /var/hadoop/provsioning/run.root > /var/log/rc.local.log 2> /var/log/rc.local.err &" >> /etc/rc.local
  sed -i -e "s,^\(exit\),#\1,g" /etc/rc.local
fi

chmod +x hadoop-conf-setter
mv hadoop-conf-setter /usr/bin

mkdir -p /var/hadoop/provsioning
mv *.py /var/hadoop/provsioning/
mv run.* /var/hadoop/provsioning/

OS_DIST=`cat /etc/issue | head -n 1 | awk '{print $1}'`
cd /var/hadoop/provsioning/run.onprovisioning/
echo "${OS_DIST}"
bash ./${OS_DIST}_init.sh
cd ..
rm -rf /var/hadoop/provsioning/run.onprovisioning/

rm -f /tmp/*
rm -f /var/log/*
rm -f /root/*
#reboot
