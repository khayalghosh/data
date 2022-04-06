#!/bin/bash
#sudo apt-get install python3-setuptools 
#sudo python3 -m easy_install install pip
sudo python3 bin/get-pip.py && sudo pip3 install -r lib/requirements.txt --no-index --find-links lib
