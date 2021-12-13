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
from threading import Thread
import json
import os
import subprocess
from os import listdir
from os.path import islink, realpath, join
import re
import multiprocessing

app = Flask(__name__)

@app.route("/")
def home():
    return "Flask server to set Static IP address!"

@app.route("/changeSettings",methods=['POST'])
def setStaticIp():
    request_data = request.get_json()
    print (request_data)
    dhcp_value=str(request_data.get("dhcpEnabled"))
    #print (dhcp_value)
    if dhcp_value=='False':
       print ("Allocating static ip ")
#       command = "sudo ifconfig {interface} {ipaddr} netmask {mask}".format(interface=request_data['name'],ipaddr=request_data['ipAddress'],mask=request_data['subnetMask'])
       dhc_false_add_addr="sudo netplan set ethernets.{interface}.addresses=[{ipaddr}/{mask}]".format(interface=request_data['name'],ipaddr=request_data['ipAddress'],mask=request_data['subnetMask'])
       print(dhc_false_add_addr)
       subprocess.run(dhc_false_add_addr, capture_output=True, shell=True)
       autoDns = request_data["dns"]["auto"]
       dhc_false_dns_list=request_data["dns"]['nameservers']
       print (dhc_false_dns_list)
       if autoDns == False:
          dhc_false_nameserver_add="sudo netplan set ethernets.{interface}.nameservers.addresses=[{nameserver}]".format(interface=request_data['name'],nameserver=",".join(dhc_false_dns_list))
          print (dhc_false_nameserver_add)
          subprocess.run(dhc_false_nameserver_add, capture_output=True, shell=True)
       else:
          auto_dns_command="sudo netplan set ethernets.{interface}.nameservers.addresses={nameserver}".format(interface=request_data['name'],nameserver="null")
          print ('setting nameservers null')
          subprocess.run(auto_dns_command, capture_output=True, shell=True)
       dhc_false_gateway_add="sudo netplan set ethernets.{interface}.gateway4={gatewayaddr}".format(interface=request_data['name'],gatewayaddr=request_data['defaultGateway'])
       print (dhc_false_gateway_add)
       subprocess.run(dhc_false_gateway_add, capture_output=True, shell=True)
       print("**********************************************************Netplan Apply******************************************************************")
       print("Updating ip addreess in backend*********************** Please Wait")
       dhc_false_disable_cmd="sudo netplan set ethernets.{interface}.dhcp4={status}".format(interface=request_data['name'],status="no")
       subprocess.run(dhc_false_disable_cmd, capture_output=True, shell=True)
       print(dhc_false_disable_cmd)
       pool = multiprocessing.Pool(processes=1)
       pool.apply_async(chconfig)
    elif dhcp_value=='True':
       print("Taking ip from DHCP")
       dhc_true_command="sudo netplan set ethernets.{interface}.dhcp4={status}".format(interface=request_data['name'],status="yes")       
       dhc_true_null_addr="sudo netplan set ethernets.{interface}.addresses={state}".format(interface=request_data['name'],state="null")
       dhc_tru_null_nameserver="sudo netplan set ethernets.{interface}.nameservers.addresses={state}".format(interface=request_data['name'],state="null")
       dhc_tru_null_gateway="sudo netplan set ethernets.{interface}.gateway4={state}".format(interface=request_data['name'],state="null")
       subprocess.run(dhc_true_command, capture_output=True, shell=True)
       subprocess.run(dhc_true_null_addr, capture_output=True, shell=True)
       subprocess.run(dhc_tru_null_nameserver, capture_output=True, shell=True)
       subprocess.run(dhc_tru_null_gateway, capture_output=True, shell=True)
       print(dhc_true_command,dhc_true_null_addr,dhc_tru_null_nameserver,dhc_tru_null_gateway)
       print("Updating ip addreess in backend*********************** Please Wait")
       pool = multiprocessing.Pool(processes=1)
       pool.apply_async(chconfig)
       #p = Popen(['/bin/sh','service-restart.sh'])
    #request_converted = json.loads(request_data)
    #print (request_converted)
    return "Response from fask", 200
    #print (request_data)
    # subprocess.run(["python3
#    exit_code = subprocess.call(['./practice.sh', static_ip])
#    print(exit_code)
#    if exit_code is 0: return ('Success', 204) 
#    return ('Failed', 500) 
#print (setStaticIp())
#xyz=setStaticIp()
#print(xyz)

@app.route("/getstaticip", methods=['GET'])
def getStaticIp():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    print(s.getsockname()[0])
    staticip = s.getsockname()[0]
    s.close()
    return flask.jsonify(StaticIp=staticip)

@app.route("/getinterfaces", methods=['GET'])
def getinterfaces():
    if_res_main = []
    if_list = interdiscover()
    for if_name in if_list:
          if_data = {}
          # ip = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['addr']
          if_data['name'] = if_name
          if_data['macAddress'] = getHwAddr(if_name)
#          if_data['ipAddress'] = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['addr']
#          if_data['subnetMask'] = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['netmask']
          status = interfacestatus(if_name)
          if_data['status'] = status
          if status == 'Online':
            if_data['subnetMask'] = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['netmask']
            if_data['ipAddress'] = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['addr']
            command_check_primary="hostname -I | cut -d' ' -f1"
            op=subprocess.run(command_check_primary, capture_output=True, shell=True)
            if if_data['ipAddress']==op.stdout.decode().rstrip("\n"):
                if_data['primary']= True
            else:
                if_data['primary']= False
            gws=netifaces.gateways()
            if_data['defaultGateway'] = gws['default'][netifaces.AF_INET][0]
          else:
            if_data['subnetMask'] = "None"
            if_data['ipAddress'] = "None"
            if_data['defaultGateway'] = "None"
          if_data['dhcpEnabled'] = dhcpstatus(if_name)
          if_data['dns']= get_dns_settings(if_name)
          # print(if_data)
          if_res_main.append(if_data)
    # print(if_res_main)
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
    return "shell executed succiessfully"

if __name__ =='__main__':  
    app.run(debug = True, host='0.0.0.0', port=8099)

