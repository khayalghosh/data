import socket

def isValidPayload(request_data):

    bool_array = ["True" , "False"]
    dhcpEnabled = str(request_data.get("dhcpEnabled"))
    autoDns = str(request_data["dns"]["auto"])
    
    if(dhcpEnabled not in bool_array):
        return False

    if(autoDns not in bool_array):
        return False

    if(not str(request_data.get("name")).isalnum):
        return False

    if(not str(request_data.get("subnetMask")).isdecimal):
        return False
        
    try:
        socket.inet_aton(request_data.get("ipAddress"))
        socket.inet_aton(request_data.get("defaultGateway"))
        dns_nameservers_list=request_data["dns"]["nameservers"]
        for nameserver in dns_nameservers_list:
            socket.inet_aton(nameserver)
    except:
         return False

    return True
