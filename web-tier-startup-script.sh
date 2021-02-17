#!/bin/bash

echo `date` >> /var/tmp/startup_script_output.txt
echo "Testing startip script." >> /var/tmp/startup_script_output.txt
echo "======================================" >> /var/tmp/startup_script_output.txt

sudo apt-get update

sudo apt-get -y install nginx

sudo service nginx start
