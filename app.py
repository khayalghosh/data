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

app = Flask(__name__)

@app.route("/")
def home():
    return "Flask server to set Static IP address!"

@app.route("/setstaticip",methods=['POST'])
def setStaticIp():
    request_data = request.get_json()
    print (type(request_data))
    dhcp_value=str(request_data.get("dhcpEnabled"))
    #print (dhcp_value)
    if dhcp_value=='False':
       print ("Changing ip address")
       command = "sudo ifconfig {interface} {ipaddr} netmask {mask}".format(interface=request_data['name'],ipaddr=request_data['ipAddress'],mask=request_data['subnetMask'])
       subprocess.run(command, capture_output=True, shell=True)
    #request_converted = json.loads(request_data)
    #print (request_converted)
    return "ok"
    #print (request_data)
    # subprocess.run(["python3", "add.pyi"], text=True, input="2 3")
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
    if_list = netifaces.interfaces()
    for if_name in if_list:
        try: 
          if_data = {}
          # ip = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['addr']
          if_data['name'] = if_name
          if_data['macAddress'] = getHwAddr(if_name)
          if_data['ipAddress'] = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['addr']
          if_data['subnetMask'] = netifaces.ifaddresses(if_name)[netifaces.AF_INET][0]['netmask']
          gws=netifaces.gateways()
          if_data['defaultGateway'] = gws['default'][netifaces.AF_INET][0]
          addr = netifaces.ifaddresses(if_name)
          if_data['dhcpEnabled'] = netifaces.AF_INET in addr
          if_data['dns'] = get_dns_settings()
          # print(if_data)
          if_res_main.append(if_data)
        except:
          print("ommiting")
    # print(if_res_main)
    return flask.jsonify(if_res_main)



def getHwAddr(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    info = fcntl.ioctl(s.fileno(), 0x8927,  struct.pack('256s', bytes(ifname, 'utf-8')[:15]))
    return ':'.join('%02x' % b for b in info[18:24])

def get_dns_settings()->dict:
    # Initialize the output variables
    dns_ns, dns_search = [], ''

    # For Unix based OSs
    if os.path.isfile('/etc/resolv.conf'):
        for line in open('/etc/resolv.conf','r'):
            if line.strip().startswith('nameserver'):
                nameserver = line.split()[1].strip()
                dns_ns.append(nameserver)
            elif line.strip().startswith('search'):
                search = line.split()[1].strip()
                dns_search = search

    # If it is not a Unix based OS, try "the Windows way"
    elif os.name == 'nt':
        cmd = 'ipconfig /all'
        raw_ipconfig = subprocess.check_output(cmd)
        # Convert the bytes into a string
        ipconfig_str = raw_ipconfig.decode('cp850')
        # Convert the string into a list of lines
        ipconfig_lines = ipconfig_str.split('\n')

        for n in range(len(ipconfig_lines)):
            line = ipconfig_lines[n]
            # Parse nameserver in current line and next ones
            if line.strip().startswith('DNS-Server'):
                nameserver = ':'.join(line.split(':')[1:]).strip()
                dns_ns.append(nameserver)
                next_line = ipconfig_lines[n+1]
                # If there's too much blank at the beginning, assume we have
                # another nameserver on the next line
                if len(next_line) - len(next_line.strip()) > 10:
                    dns_ns.append(next_line.strip())
                    next_next_line = ipconfig_lines[n+2]
                    if len(next_next_line) - len(next_next_line.strip()) > 10:
                        dns_ns.append(next_next_line.strip())

            elif line.strip().startswith('DNS-Suffix'):
                dns_search = line.split(':')[1].strip()

    return {'nameservers': dns_ns, 'search': dns_search}



if __name__ =='__main__':  
    app.run(debug = True, host='0.0.0.0', port=8099)

