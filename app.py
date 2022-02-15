from pydoc import text
from flask import Flask, jsonify
import socket
import flask
import netifaces
import subprocess
from flask.globals import request
from uuid import getnode as get_mac
from threading import Thread
import os, sys, json, struct, socket, fcntl, time
import subprocess
from os import listdir
from os.path import islink, realpath, join
import re
import multiprocessing
import ipaddress

cli = sys.modules['flask.cli']
cli.show_server_banner = lambda *x: None

if "OBB_HOME" in os.environ:
    obb_home = os.environ["OBB_HOME"]
    reset_cmd = "make delete && make validate && sleep 5 && make deploy"
else:
    obb_home = "/opt/jci-obb"
    reset_cmd = "make delete && make validate && sleep 5 && make factory-deploy"

app = Flask(__name__)

@app.route('/')
def index():
    return '', 200

@app.route("/ping")
def ping():
    return jsonify({"status": "OK"}), 200


@app.post("/api/systemRestart")
def applyRestart():
    status = request.args.get('apply')
    if status == "true":
        def post_request_systemRestart():
            reboot_cmd = "sudo reboot"
            #reboot_cmd = "echo 'System Reboot'"
            time.sleep(10)
            subprocess.run([reboot_cmd],shell=True)
        threadRestart = Thread(target=post_request_systemRestart)
        threadRestart.start()
        return jsonify({'status': 202, 'message': "System Reboot Initiated Successfully"}), 202
    else:
        return jsonify({'status': 400, 'message': "Bad Request"}), 400

@app.post("/api/factoryReset")
def applyFactoryReset():
    status = request.args.get('apply')
    if status == "true":
        def post_request_factoryReset():
            factoryReset_cmd = "cd {} && {}".format(obb_home,reset_cmd)
            #factoryReset_cmd = "echo 'Factory Reset'"
            time.sleep(10)
            subprocess.run([factoryReset_cmd],shell=True)
        threadReset = Thread(target=post_request_factoryReset)
        threadReset.start()
        return jsonify({'status': 202, 'message': "Factory Reset Initiated Successfully"}), 202
    else:
        return jsonify({'status': 400, 'message': "Bad Request"}), 400

@app.route("/changeSettings",methods=['POST'])
def setStaticIp():
    request_data = request.get_json()

    valid_payload = isValidPayload(request_data)
    if not valid_payload :
        return jsonify({'status': 400, 'message': "Bad Request. Payload is not Valid!"}), 400

    dhcp_value=str(request_data.get("dhcpEnabled"))
    if dhcp_value=='False':
       dhc_false_add_addr="sudo netplan set ethernets.{interface}.addresses=[{ipaddr}/{mask}]".format(interface=request_data['name'],ipaddr=request_data['ipAddress'],mask=request_data['subnetMask'])
       subprocess.run(dhc_false_add_addr, capture_output=True, shell=True)
       autoDns = request_data["dns"]["auto"]
       dhc_false_dns_list=request_data["dns"]['nameservers']
       if autoDns == False:
          dhc_false_nameserver_add="sudo netplan set ethernets.{interface}.nameservers.addresses=[{nameserver}]".format(interface=request_data['name'],nameserver=",".join(dhc_false_dns_list))
          subprocess.run(dhc_false_nameserver_add, capture_output=True, shell=True)
       else:
          auto_dns_command="sudo netplan set ethernets.{interface}.nameservers.addresses={nameserver}".format(interface=request_data['name'],nameserver="null")
          subprocess.run(auto_dns_command, capture_output=True, shell=True)
       dhc_false_gateway_add="sudo netplan set ethernets.{interface}.gateway4={gatewayaddr}".format(interface=request_data['name'],gatewayaddr=request_data['defaultGateway'])
       subprocess.run(dhc_false_gateway_add, capture_output=True, shell=True)
       dhc_false_disable_cmd="sudo netplan set ethernets.{interface}.dhcp4={status}".format(interface=request_data['name'],status="no")
       subprocess.run(dhc_false_disable_cmd, capture_output=True, shell=True)
       pool = multiprocessing.Pool(processes=1)
       pool.apply_async(chconfig)
    elif dhcp_value=='True':
       dhc_true_command="sudo netplan set ethernets.{interface}.dhcp4={status}".format(interface=request_data['name'],status="yes")       
       dhc_true_null_addr="sudo netplan set ethernets.{interface}.addresses={state}".format(interface=request_data['name'],state="null")
       dhc_tru_null_nameserver="sudo netplan set ethernets.{interface}.nameservers.addresses={state}".format(interface=request_data['name'],state="null")
       dhc_tru_null_gateway="sudo netplan set ethernets.{interface}.gateway4={state}".format(interface=request_data['name'],state="null")
       subprocess.run(dhc_true_command, capture_output=True, shell=True)
       subprocess.run(dhc_true_null_addr, capture_output=True, shell=True)
       subprocess.run(dhc_tru_null_nameserver, capture_output=True, shell=True)
       subprocess.run(dhc_tru_null_gateway, capture_output=True, shell=True)
       pool = multiprocessing.Pool(processes=1)
       pool.apply_async(chconfig)
    return "Response from API", 200

@app.route("/api/getstaticip", methods=['GET'])
def getStaticIp():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    staticip = s.getsockname()[0]
    s.close()
    return flask.jsonify(StaticIp=staticip)

@app.route("/api/getinterfaces", methods=['GET'])
def getinterfaces():
    if_res_main = []
    if_list = interdiscover()
    for if_name in if_list:
          if_data = {}
          if_data['name'] = if_name
          if_data['macAddress'] = getHwAddr(if_name)
          status = interfacestatus(if_name)
          if_data['status'] = status
          if status == 'Online':
            if_data['subnetMask'] = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['netmask']
            if_data['ipAddress'] = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['addr']
            gws=netifaces.gateways()
            if_data['defaultGateway'] = gws['default'][netifaces.AF_INET][0]
          else:
            if_data['subnetMask'] = "None"
            if_data['ipAddress'] = "None"
            if_data['defaultGateway'] = "None"
          if_data['dhcpEnabled'] = dhcpstatus(if_name)
          if_data['dns']= get_dns_settings(if_name)
          if_res_main.append(if_data)
    return flask.jsonify(if_res_main)

def interdiscover():
    all_interfaces = [i for i in listdir("/sys/class/net") if islink(join("/sys/class/net", i))]
    phy_interfaces = [i for i in all_interfaces if not realpath(join("/sys/class/net", i)).startswith(("/sys/devices/virtual", "/sys/devices/vif"))]
    return phy_interfaces

def dhcpstatus(intname):
    dhc_command="sudo netplan get ethernets.{}".format(intname)
    dhc_status = subprocess.run(dhc_command, capture_output=True, shell=True)
    x = dhc_status.stdout.decode()
    if "dhcp4: false" in x:
        return False
    else:
        return True

def interfacestatus(ifname):
    command = "sudo ethtool {}".format(ifname)
    ret = subprocess.run(command, capture_output=True, shell=True)
    x = ret.stdout.decode()
    if "Link detected: yes" in x:
        return "Online"
    else:
        return "Offline"

def getHwAddr(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    info = fcntl.ioctl(s.fileno(), 0x8927,  struct.pack('256s', bytes(ifname, 'utf-8')[:15]))
    return ':'.join('%02x' % b for b in info[18:24])

def get_dns_settings(ifname)-> dict:
    x=[]
    command = "sudo netplan get ethernets.{}.nameservers.addresses".format(ifname)
    ret = subprocess.run(command, capture_output=True, shell=True)
    x=ret.stdout.decode()
    z=re.findall( r'[0-9]+(?:\.[0-9]+){3}', x)
    return { 'nameservers': z, 'auto': len(z) == 0 }

def chconfig():
    apply_command="sudo netplan apply"
    subprocess.run(apply_command, capture_output=True, shell=True)
    subprocess.call(['sh', 'service-restart.sh'])
    return "shell executed successfully"

def isValidPayload(request_data):

    bool_array = ["True" , "False"]
    dhcpEnabled = str(request_data.get("dhcpEnabled"))
    autoDns = str(request_data["dns"]["auto"])
    interface_list = interdiscover()

    if(dhcpEnabled not in bool_array):
        return False

    if(autoDns not in bool_array):
        return False

    if(not str(request_data.get("name")) in interface_list):
        return False

    if(not str(request_data.get("subnetMask")).isdecimal):
        return False
    try:
        ipaddress.ip_address(str(request_data.get("ipAddress")))
        ipaddress.ip_address(str(request_data.get("defaultGateway")))
        dns_nameservers_list=request_data["dns"]["nameservers"]
        for nameserver in dns_nameservers_list:
            ipaddress.ip_address(nameserver)    
    except ValueError:
         return False

    return True


if __name__ =='__main__':  
    app.run(debug = False, host='0.0.0.0', port=8099)

