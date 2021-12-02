from pydoc import text
from flask import Flask
import socket
import flask
import netifaces
import subprocess
from flask.globals import request
from uuid import getnode as get_mac
import fcntl
import socket
import struct
import json
import os
import subprocess
from os import listdir
from os.path import islink, realpath, join
import multiprocessing

app = Flask(__name__)

@app.route("/")
def home():
    print("Starting new process")
    pool = multiprocessing.Pool(processes=1)
    pool.apply_async(do_long_extra_job)
    return "Response from flask"

def do_long_extra_job():
    subprocess.call(['sh', 'service-restart.sh'])
    return "shell executed succiessfully"

if __name__ =='__main__':
    app.run(debug = True, host='0.0.0.0', port=8099)
