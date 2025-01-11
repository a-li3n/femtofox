  #!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

args="$@" # arguments to this script
interaction="true"
help=$(cat <<EOF
Arguments:
-h          This message
    Environment - must be first argument:
-x          User UI is not terminal (script interaction unavailable)
    Actions:
-i          Install
-u          Uninstall
-g          Upgrade
-e          Enable service, if applicable
-d          Disable service, if applicable
-s          Stop service
-r          Start/Restart
    Information:
-N          Get name
-A          Get author
-D          Get description
-U          Get URL
-O          Get options supported by this script
-S          Get service status
-L          Get Install location
-C          Get Conflicts
-I          Check if installed. Returns an error if not installed
EOF
)

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't really possible
# Arguments to the script are stored in $args
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interaction="false". In this cause special instructions to the user should be given as user_message
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed


name="TC2-BBS"   # software name
author="The Comms Channel"   # software author - OPTIONAL
description="The TC²-BBS system integrates with Meshtastic devices. The system allows for message handling, bulletin boards, mail systems, and a channel directory."   # software description - OPTIONAL (but strongly recommended!)
URL="https://github.com/TheCommsChannel/TC2-BBS-mesh"   # software URL. Can contain multiple URLs - OPTIONAL
options="xiugedsrNADUOSLCIto"   # script options in use by software package. For example, for a package with no service, exclude `edsr`
service_name="mesh-bbs"   # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
location="/opt/TC2-BBS-mesh"   # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
conflicts="Meshing Around, other \"full control\" packages"   # comma delineated plain-text list of packages with which this package conflicts. Blank if none. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"


if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi


# install script
install() {
  if ! git clone https://github.com/TheCommsChannel/TC2-BBS-mesh.git $location; then
    echo "user_message: Git clone failed. Is internet connected?"
    exit 1
  fi
  chown -R femto $location #give ownership of installation directory to $user
  git config --global --add safe.directory $location # prevents git error when updating

  cd $location
  mv example_config.ini config.ini
  sed -i 's/type = serial/type = tcp/' config.ini
  sed -i 's/^# hostname = 192.168.x.x/hostname = 127.0.0.1/' config.ini
  echo "Installation/upgrade successful! Adding/recreating service."
  sed -i "s/pi/${SUDO_USER:-$(whoami)}/g" mesh-bbs.service
  sed -i "s|/home/femto/|/opt/|g" mesh-bbs.service
  cp mesh-bbs.service /etc/systemd/system/
  systemctl enable mesh-bbs.service
  systemctl restart mesh-bbs.service

  echo "user_message: Installation complete, service launched. To adjust configuration, run \`sudo nano $location/config.ini\`"
  exit 0
}


# uninstall script
uninstall() {
  systemctl disable mesh-bbs.service
  systemctl stop mesh-bbs.service
  rm -rf $location
  echo "user_message: Service removed, all files deleted."
  exit 0
}


#upgrade script
upgrade() {
  cd $location
  if ! git pull; then
    echo "user_message: Git pull failed. Is internet connected?"
    exit 1
  fi
  exit 0
}


# Check if already installed. `exit 0` if yes, `exit 1` if no
check() {
  #the following works for cloned repos, but not for apt installs
  if [ -d "$location" ]; then
    #echo "Already installed"
    exit 0
  else
    #echo "Not installed"
    exit 1
  fi
}


while getopts ":h$options" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    x) # Option -x (no user interaction available)
      interaction="false"
      ;;
    i) # Option -i (install)
      install
      ;;
    u) # Option -u (uninstall)
      uninstall
      ;;
    g) # Option -g (upgrade)
      upgrade
      ;;
    e) # Option -e (Enable service, if applicable)
      systemctl enable $service_name
      ;;
    d) # Option -d (Disable service, if applicable)
      systemctl disable $service_name
      ;;
    s) # Option -s (Stop service)
      systemctl stop $service_name
      ;;
    r) # Option -r (Start/Restart)
      systemctl restart $service_name
      ;;
    N) echo -e $name ;;
    A) echo -e $author ;;
    D) echo -e $description ;;
    U) echo -e $URL ;;
    O) echo -e $options ;;
    S) # Option -S (Get service status)
      systemctl status $service_name
    ;;
    L) echo -e $location ;;
    C) echo -e $conflicts ;;
    I) # Option -I (Check if already installed)
      check
    ;;
  esac
done

exit 0