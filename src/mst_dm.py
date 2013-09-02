#!/usr/bin/python
# -*- coding: utf-8 -*-
#################################################################
#
# Hadoop Provisioning API Script - As Master
#
#  - Script by Jioh L. Jung (zio.zzang@kt.com)
#
#################################################################
# Configuration

import os
import re
import json
import threading
from flask import Flask, redirect, url_for, request, Response

import config

app = Flask(__name__)
lock = threading.Lock()

def comp_conf():
  os.system("tar -czvf %s /etc/hadoop" %(config.CONF_TGZ))
  os.system("md5sum -b %s | awk '{print $1}' > %s" % \
    (config.CONF_TGZ, config.CONF_HASH))

def find_set(ip, fname):
  exist = False
  trimed_ip = ip.strip()
  lock.acquire()
  try:
    f = open(fname, "r")
    for i in f.readlines():
      line_ip = i.strip()
      if line_ip == trimed_ip:
        exist = True
    f.close()
  except:
    pass

  if exist == False:
    os.system("echo '%s' >> %s" % (ip, fname))
    comp_conf()

  lock.release()

# Add to Slave.
@app.route('/')
def cmd_show_ip():
  ip = request.remote_addr
  find_set(ip, "/etc/hadoop/slaves")
  return Response(response=ip, mimetype="text/plain")

# This code is role as user-data proxy
@app.route('/meta-data/')
def cmd_meta():
  d = open(config.ENV_RUNONBOOT, "r").read()

  return Response(d,
    mimetype="application/octet-stream",
    headers={"Content-Disposition":
      "attachment;filename=slave_data.env"})

# Hadoop configure tarball
@app.route('/conf-data/')
def cmd_data():
  d = open(config.CONF_TGZ, "r").read()

  return Response(d,
    mimetype="application/x-compressed",
    headers={"Content-Disposition":
      "attachment;filename=conf.tgz"})

# Hadoop configure tarball's hash
@app.route('/conf-hash/')
def cmd_hash():
  d = open(config.CONF_HASH, "r").read()

  return Response(d, mimetype="text/plain")

# Request rebuilding of tarball
@app.route('/re-tar/')
def cmd_retar():
  comp_conf()

  d = open(config.CONF_HASH, "r").read()

  return Response(d, mimetype="text/plain")

# SSH key request
@app.route('/pubkey/')
def cmd_pubkey():
  d = open("/root/.ssh/authorized_keys", "r").read()
  return Response(response=d, mimetype="text/plain")


# Do start as server
app.run(
    debug=config.DEBUG_FLAG,
    host='0.0.0.0',
    port=config.LISTEN_PORT,
    threaded=True
  )

