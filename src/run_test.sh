#!/bin/bash
hadoop fs -rmr dft
hadoop fs -rmr dft-out

rm -f 4300.zip
rm -f 4300.txt
wget http://www.gutenberg.org/files/4300/4300.zip
unzip 4300.zip

cat 4300.txt > tmp
cat 4300.txt >> tmp
cat 4300.txt >> tmp
cat 4300.txt >> tmp
cat 4300.txt >> tmp

cat tmp > large.txt
cat tmp >> large.txt
cat tmp >> large.txt
cat tmp >> large.txt
cat tmp >> large.txt

mv large.txt tmp

cat tmp > large.txt
cat tmp >> large.txt
cat tmp >> large.txt
cat tmp >> large.txt
cat tmp >> large.txt

mv large.txt tmp

cat tmp > large.txt
cat tmp >> large.txt
cat tmp >> large.txt
cat tmp >> large.txt
cat tmp >> large.txt

hadoop dfs -mkdir dft
hadoop dfs -copyFromLocal large.txt dft
hadoop dfs -ls
hadoop dfs -ls dft

hadoop jar /usr/share/hadoop/hadoop-examples-1.2.1.jar wordcount dft dft-out


exit 0

# 아래는 예제임.
mkdir wordcount_classes
javac -classpath /usr/share/hadoop/hadoop-core-1.1.2.jar -d wordcount_classes WordCount.java
jar -cvf wordcount.jar -C wordcount_classes/ .

이 이후 실행은 hadoop jar 로 실행.

