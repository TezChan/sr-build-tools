#!/bin/bash
set -e
source /opt/ros/melodic/setup.bash
source /home/user/projects/shadow_robot/base/devel/setup.bash
num_arms=0

get_serial_from_arm() {
  sshpass -p easybot ssh root@$1 cat /root/ur-serial
}

get_serial_from_file() {
  source /opt/ros/melodic/setup.bash
  source /home/user/projects/shadow_robot/base/devel/setup.bash
  if ! test -f /etc/$1; then
    sudo touch /etc/$1
  fi
  cat "/etc/$1" | sed -r 's/\..*//g'
}

write_serial_to_file() {
  source /opt/ros/melodic/setup.bash
  source /home/user/projects/shadow_robot/base/devel/setup.bash
  printf "${1}.yaml" | sudo tee /etc/shadow_arm_1
}

save_mac_address(){
  mac_address=$(arp | grep $1 | awk '{print $3}')
  printf "${mac_address}" | sudo tee /etc/shadow_arm_1_mac
}

get_mac_address_from_robot(){
  mac_address=$(arp | grep $1 | awk '{print $3}')
  echo "${mac_address}"
}

get_mac_address_from_file(){
  if ! test -f /etc/shadow_arm_1_mac; then
    sudo touch /etc/shadow_arm_1_mac
  fi
  mac_address=$(cat /etc/shadow_arm_1_mac)
  if [[ $mac_address == "" ]]; then
    mac_address="does_not_exist"
  fi
  echo "${mac_address}"
}

generate_new_calibration(){
  source /opt/ros/melodic/setup.bash
  source /home/user/projects/shadow_robot/base/devel/setup.bash
  roslaunch ur_calibration calibration_correction.launch robot_ip:=$1 target_filename:="$(rospack find sr_ur_calibration)/calibrations/$2.yaml" | grep -m 1 "Calibration correction done" &
  sleep 10
  ur_calibration_pid=$(ps aux | grep "roslaunch ur_calibration" | grep -v grep | awk '{print $2}')
  kill $ur_calibration_pid
}

has_mac_address_changed(){
  if [[ $(get_mac_address_from_file) != $(get_mac_address_from_robot $1) ]]; then
    echo "true"
  else
    echo "false"
  fi
}

check_calibration_file_exists(){
  if [[ $1 == "" ]]; then
    serial="does_not_exist"
  else
    serial=$1
  fi
  if [[ $(rosls sr_ur_calibration/calibrations | grep $serial | wc -l) -eq 0 ]]; then
    echo "true"
  else 
    echo "false"
  fi
}


arm_ip="192.168.1.1"
while true; do
  if [[ $(has_mac_address_changed $arm_ip) == "true" ]]; then
    save_mac_address $arm_ip
    arm_serial=$(get_serial_from_arm $arm_ip)
    if [[ $(get_serial_from_file "shadow_arm_1") != "${arm_serial}" ]]; then
      write_serial_to_file "${arm_serial}"
    fi
  fi
  serial_in_file=$(get_serial_from_file "shadow_arm_1")
  if [[ $(check_calibration_file_exists "$serial_in_file") == "true" ]]; then
    arm_serial=$(get_serial_from_arm $arm_ip)
    if $(zenity --question --text="No arm calibration detected, do you wish to generate one/?"); then 
      generate_new_calibration $arm_ip $arm_serial
    fi
  fi
  sleep 5
done

