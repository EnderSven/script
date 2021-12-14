#!/bin/bash

# This feature on Category5 Technology TV sponsored by ameriDroid.com
# USA-based SBC sales with unmatched support and fast shipping
# To power your Minecraft Server, get a Raspberry Pi 4 from https://ameridroid.com

# Corresponding video series: https://category5.tv/feature/minecraft

pcver="3.1"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root" 2>&1
  exit 1
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Get the LAN IP address

  # test the route based on $host and treat that as the interface
  interface=""
  host=github.com
  host_ip=$(getent ahosts "$host" | awk '{print $1; exit}')
  interface=`ip route get "$host_ip" | grep -Po '(?<=(dev )).*(?= src| proto)' | cut -f 1 -d " "`
  ip=$(/sbin/ip -f inet addr show $interface | grep -Po 'inet \K[\d.]+' | head -n 1)
  if [[ $ip == "" ]]; then
    # Never reply with a blank string - instead, use localhost if no IP is found
    # This would be the case if no network connection is non-existent
    ip="127.0.0.1"
  fi


# Determine where the config.txt file is
  # Generic
  configfile=/boot/config.txt
  # Ubuntu
  if [[ -e /boot/firmware/config.txt ]]; then
    configfile=/boot/firmware/config.txt
  fi


# Version comparison which allows comparing 1.16.5 to 1.14.0 (for example)
function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

# Install the web interface
#psi=1

# Prevent running multiple apt updates
updated=0

# Place the current folder in a variable to use as a base source folder
base=$(pwd)

# dialog allows me to create a pretty installer
# It is a required dependency since Pinecraft 1.1
dialog=$(which dialog)
if [[ $dialog == "" ]]; then
  printf "Installing dialog... "
  if [[ $updated == 0 ]]; then
    apt-get update > /dev/null 2>&1
    updated=1
  fi
  apt-get -y install dialog > /dev/null 2>&1
  dialog=$(which dialog)
  if [[ $dialog == "" ]]; then
    echo "Failed. Aborting. Install dialog first."
    exit 0
  else
    echo "Success."
  fi
fi


dialog --title "Pinecraft Installer $pcver" \
--msgbox "

       Play on our high-performance
             Minecraft servers!

       https://patreon.com/Pinecraft

" 12 48



dialog --title "Pinecraft Installer $pcver" \
--msgbox "
 Pinecraft: The Minecraft Server Installer
      For Raspberry Pi and Other SBCs

    By Robbie Ferguson // The Bald Nerd
  https://category5.tv/feature/minecraft

         Installer Version: $pcver

         Sponsored by ameriDroid
         https://ameridroid.com/
" 16 48



dialog --infobox "Checking dependencies..." 3 34 ; sleep 2

javaminver=8; # The minimum version of Java for Minecraft Server to run
javamaxver=17; # The current max version available in known repositories that Minecraft Server can run on.

if [[ $updated == 0 ]]; then
  dialog --infobox "Updating repositories..." 3 34 ;
  apt-get update > /dev/null 2>&1
  updated=1
fi

if type -p java > /dev/null; then
  _java=java
elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
    _java="$JAVA_HOME/bin/java"
fi

vercount=javamaxver
(( ++vercount ))
while (( --vercount >= $javaminver )); do
  javaver=0
  if [[ "$_java" ]]; then
    javaver=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
  fi

  ver=0
  for i in $(echo $javaver | tr "." "\n")
  do
    if [[ $ver == 0 ]]; then
      ver=$i
    else
      subver=$i
      break
    fi
  done

  result=$(dpkg-query -W --showformat='${Status}\n' openjdk-${vercount}-jre-headless | grep "install ok installed")
  if [ ! "$result" = "" ]; then
    break
  fi

  if (( $ver < $javamaxver )); then
    dialog --infobox "Trying to install JRE ${vercount}..." 3 38 ;
    apt-get -y install openjdk-${vercount}-jre-headless > /dev/null 2>&1
  fi

  result=$(dpkg-query -W --showformat='${Status}\n' openjdk-${vercount}-jre-headless | grep "install ok installed")
  if [ ! "$result" = "" ]; then
    break
  fi

done

# Java installed?
if type -p java > /dev/null; then
  _java=java
elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
    _java="$JAVA_HOME/bin/java"
else
  dialog --title "Error" \
    --msgbox "\nJava installation failed. Please install the latest JRE first and try again." 8 50
  echo
  echo
  echo "Failed."
  echo
  exit 0
fi

javaver=0
if [[ "$_java" ]]; then
  javaver=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
fi

ver=0
for i in $(echo $javaver | tr "." "\n")
do
  if [[ $ver == 0 ]]; then
    ver=$i
  else
    subver=$i
    break
  fi
done

# minimum version of Java supported by Minecraft Server
if [[ $ver > 8 ]] || [[ $ver == 1 ]] && [[ $subver > 8 ]]; then
  dialog --title "Error" \
      --msgbox "\n`which java` is version ${javaver}. You'll need a newer version of JRE." 8 50
  echo
  echo
  echo "Failed."
  echo
  exit 0
fi

if [ $(dpkg-query -W -f='${Status}' git 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
  dialog --infobox "Installing git..." 3 34 ;
  if [[ $updated == 0 ]]; then
    apt-get update > /dev/null 2>&1
    updated=1
  fi
  apt-get -y install git > /dev/null 2>&1
fi
git config --global --unset core.autocrlf

if [ $(dpkg-query -W -f='${Status}' screen 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
  dialog --infobox "Installing screen..." 3 34 ;
  if [[ $updated == 0 ]]; then
    apt-get update > /dev/null 2>&1
    updated=1
  fi
  apt-get -y install screen > /dev/null 2>&1
fi

mcver="1.16.5"
if (( $ver >= 17 )); then # Java version 17+ allows 1.18.x
  mcver="1.18.1"
elif (( $ver >= 16 )); then # Java version 16+ allows 1.17.x
  mcver="1.17.1"
fi

# Username may be provided on CLI as in 1.0
user=$1

if [[ $user == "" ]]; then
  validuser=""
else
  validuser=$(getent passwd $user)
fi
while [[ $validuser == "" ]]
do

  users=$(cat /etc/passwd | grep '/home' | cut -d: -f1)
  count=1
  declare -a usersarr=()
  for username in $users; do
    if [[ -d /home/${username}/ ]]; then
      usersarr+=("${username}" "/home/${username}/minecraft/")
    fi
  done

  exec 3>&1
  user=$(dialog --title "Linux User" --menu "Linux User to run Minecraft Server:" 20 50 10 "${usersarr[@]}" 2>&1 1>&3);

  case $? in
  0)
   if [[ $user == "" ]]; then
    validuser=""
   else
    validuser=$(getent passwd $user)
   fi
   if [[ $validuser == "" ]]; then
     dialog --title "Error" \
       --msgbox "\n $user does not exist." 6 50
   fi
   ;;
  1)
   echo
   echo
   echo "Aborted."
   echo
   exit 1 ;;
  esac

done



instdir="/home/$user/minecraft/"

upgrade=0
replace=0
if [[ -e /home/$user ]]; then
  if [[ -e ${instdir} ]]; then
    if [[ ! -e ${instdir}cat5tv.ver ]]; then
      dialog --title "Error"\
        --msgbox "\n${instdir} already exists, but is either not created by Pinecraft Installer or is from a failed installation.\n\nPlease move or remove the folder and try again." 12 50
      clear
      exit 0
    else

      exec 3>&1
      result=$(dialog --title "Pinecraft Installer $pcver" \
         --menu "Pinecraft is already installed:" 9 40 4 \
         "U"       "Upgrade Software (Keep World)" \
         "R"       "Remove Previous and Reinstall" \
        2>&1 1>&3);

      if [[ $? == 0 ]]; then
        case $result in
          U)
            upgrade=1
            ;;
          R)
            dialog --title "Confirmation"  --yesno "\nThis will remove your entire previous installation, including your world files.\n\nContinue?" 12 50
            case $? in
              1)
              echo
              echo
              echo "Aborted."
              echo
              exit 1 ;;
            esac
            replace=1
            ;;
          esac
        else
          echo
          echo
          echo "Aborted."
          echo
          exit 1
        fi

    fi
  fi
else
  echo "Aborting: $user does not have a homedir."
  exit 1
fi



# Get the level seed, but only if this is a new install
if [[ $upgrade == 0 ]]; then
  exec 3>&1
  result=$(dialog --title "Pinecraft Installer $pcver" \
         --menu "Choose your game seed:" 20 50 10 \
         "A"       "Random (Default, ${mcver})" \
         "B"       "Custom (${mcver})" \
         "C"       "Category5 TV RPi Server (1.16.5)" \
         "D"       "Jeff's Tutorial World (1.16.5)" \
         "E"       "Minecraft Title Screen (1.9.4)" \
         "F"       "Slime Farm (1.16.5)" \
         "G"       "Obsidian Farm (1.9.4)" \
         "H"       "Woodland Mansion (1.12.2)" \
         "I"       "Triple Island Ocean Monument (1.14.4)" \
         "J"       "Spruce Village and Coral Reef (1.14.4)" \
         "K"       "Shipwreck Village (1.14.4)" \
         "L"       "Underwater Temple (1.9.4)" \
         "M"       "Diamond Paradise (1.9.4)" \
         "N"       "All Biome World (1.12.2)" \
         "O"       "Paradise Valley (1.16.5)" \
       2>&1 1>&3);

  if [[ $? == 0 ]]; then
    case $result in
    A)
      seed=""
      mcverANY=1
      ;;
    B)
      seed="custom"
      mcverANY=1
      ;;
    C)
      seed="-4385290424787160722"
      mcver="1.16.5"
      ;;
    D)
      seed="6421417242871949536"
      mcver="1.16.5"
      ;;
    E)
      seed="2151901553968352745"
      mcver="1.9.4" # Was actually part of 1.7.3 but that was a beta client, and Spigot only goes back to 1.9. Probably not usable?
      ;;
    F)
      seed="7000"
      mcver="1.16.5"
      ;;
    G)
      seed="-8880302588844065321"
      mcver="1.9.4" # Originally on 1.9
      ;;
    H)
      seed="throwlow"
      mcver="1.12.2" # Originally on 1.12
      ;;
    I)
      seed="6073041046072376055"
      mcver="1.14.4" # OP didn't say what version, so I have to guess
      ;;
    J)
      seed="673900667"
      mcver="1.14.4"
      ;;
    K)
      seed="-613756530319979507"
      mcver="1.14.4"
      ;;
    L)
      seed="-5181140359215069925"
      mcver="1.9.4" # Was on 1.8 but Spigot only goes back to 1.9
      ;;
    M)
      seed="1785852800490497919"
      mcver="1.9.4" # Was on 1.8 but Spigot only goes back to 1.9
      ;;
    N)
      seed="1083719637794"
      mcver="1.12.2"
      ;;
    O)
      seed="4725084288293652062"
      mcver="1.16.5"
      ;;

    esac
  else
    echo
    echo
    echo "Aborted."
    echo
    exit 1
  fi

  # Input custom seed
  if [[ $seed == "custom" ]]; then
    seed=$(dialog --stdout --title "Custom World Seed" \
      --inputbox "Enter your custom world seed" 8 50)
  fi

fi


# https://www.minecraft.net/en-us/download/server
if [[ $mcver == "1.18.1" ]]; then
  vanilla="https://launcher.mojang.com/v1/objects/125e5adf40c659fd3bce3e66e67a16bb49ecc1b9/server.jar"
elif [[ $mcver == "1.18" ]]; then
  vanilla="https://launcher.mojang.com/v1/objects/3cf24a8694aca6267883b17d934efacc5e44440d/server.jar"
elif [[ $mcver == "1.17.1" ]]; then
  vanilla="https://launcher.mojang.com/v1/objects/a16d67e5807f57fc4e550299cf20226194497dc2/server.jar"
elif [[ $mcver == "1.17" ]]; then
  # 1.17
  vanilla="https://launcher.mojang.com/v1/objects/0a269b5f2c5b93b1712d0f5dc43b6182b9ab254e/server.jar"
else
  # 1.16.5
  vanilla="https://launcher.mojang.com/v1/objects/1b557e7b033b583cd9f66746b7a9ab1ec1673ced/server.jar"
fi
flavor=""


declare -a flavors=()

if [[ $mcverANY == "1" ]] || [[ $mcver == "1.17.1" ]] || [[ $mcver == "1.17" ]] || [[ $mcver == "1.16.5" ]] || [[ $mcver == "1.18" ]] || [[ $mcver == "1.18.1" ]]; then
  flavors+=("P" "Paper (Default, ${mcver})")
fi

# Supports 1.14+
if [[ $mcverANY == "1" ]] || [ $(version $mcver) -ge $(version "1.14.0") ]; then
  flavors+=("F" "Fabric (${mcver})")
fi

if [[ $mcverANY == "1" ]] || [[ $mcver == "1.16.5" ]] || [[ $mcver == "1.17.1" ]] || [[ $mcver == "1.18" ]]; then
  flavors+=("R" "Forge (${mcver})")
fi

# Supports 1.9+
if [[ $mcverANY == "1" ]] || [ $(version $mcver) -ge $(version "1.9") ]; then
  flavors+=("S" "Spigot (${mcver})")
fi

# 1.12 only
if [[ $mcverANY == "1" ]] || [[ $mcver == "1.12.2" ]]; then
  flavors+=("C" "Cuberite (1.12)")
fi

if [[ $mcverANY == "1" ]] || [[ $mcver == "1.17.1" ]] || [[ $mcver == "1.17" ]] || [[ $mcver == "1.16.5" ]] || [[ $mcver == "1.18" ]] || [[ $mcver == "1.18.1" ]]; then
  flavors+=("V" "Vanilla (${mcver})")
fi

exec 3>&1
result=$(dialog --title "Pinecraft Installer $pcver" --menu "Choose your Minecraft server type:" 20 40 10 "${flavors[@]}" 2>&1 1>&3);

if [[ $? == 0 ]]; then
  case $result in
    S)
      # https://hub.spigotmc.org/jenkins/job/BuildTools/
      # NOTE: BuildTools (Spigot) AUTOMATICALLY ensures the correct Minecraft version is installed (see switches below)
      #       No need to update the script manually.
      flavor="Spigot"
      url="https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"
      jarname="spigot-*.jar"
      switches="--rev ${mcver}"
      ;;
    F)
      # https://fabricmc.net/use/
      flavor="Fabric"
      url="https://maven.fabricmc.net/net/fabricmc/fabric-installer/0.10.2/fabric-installer-0.10.2.jar"
      jarname="fabric-server-launch.jar"
      switches="server -mcversion ${mcver} -downloadMinecraft"
      ;;
    R)
      # https://files.minecraftforge.net/net/minecraftforge/forge/
      flavor="Forge"
      if [[ $mcver == "1.18" ]]; then
        url="https://maven.minecraftforge.net/net/minecraftforge/forge/1.18-38.0.17/forge-1.18-38.0.17-installer.jar"
      elif [[ $mcver == "1.17.1" ]]; then
        url="https://maven.minecraftforge.net/net/minecraftforge/forge/1.17.1-37.0.107/forge-1.17.1-37.0.107-installer.jar"
      else
        url="https://maven.minecraftforge.net/net/minecraftforge/forge/1.16.5-36.1.0/forge-1.16.5-36.1.0-installer.jar"
      fi
      jarname="forge-installer.jar"
      switches="--installServer ."
      ;;
    V)
      flavor="Vanilla"
      url=$vanilla
      jarname="server.jar"
      switches=""
      ;;
    P)
      # https://papermc.io/downloads
      flavor="Paper"
      if [[ $mcver == "1.18.1" ]]; then
        url="https://papermc.io/api/v2/projects/paper/versions/1.18.1/builds/68/downloads/paper-1.18.1-68.jar"
      elif [[ $mcver == "1.18" ]]; then
        url="https://papermc.io/api/v2/projects/paper/versions/1.18/builds/66/downloads/paper-1.18-66.jar"
      elif [[ $mcver == "1.17.1" ]]; then
        url="https://papermc.io/api/v2/projects/paper/versions/1.17.1/builds/391/downloads/paper-1.17.1-391.jar"
      elif [[ $mcver == "1.17" ]]; then
        url="https://papermc.io/api/v2/projects/paper/versions/1.17/builds/28/downloads/paper-1.17-28.jar"
      else
        url="https://papermc.io/api/v2/projects/paper/versions/1.16.5/builds/778/downloads/paper-1.16.5-778.jar"
      fi
      jarname="minecraft.jar"
      switches=""
      ;;
    C)
      flavor="Cuberite"
      mcver="1.12" # Cuberite is a whole other beast
      script="https://compile.cuberite.org"
      executable="Cuberite"
      compiler=1;
      ;;
    esac
else
  echo
  echo
  echo "Aborted."
  echo
  exit 1
fi
if [[ $flavor == "" ]]; then
  echo
  echo
  echo "Aborted."
  echo
  exit 1
fi

exec 3>&1
result=$(dialog --title "Pinecraft Installer $pcver $mcver" \
         --menu "Choose your game type:" 20 40 10 \
         "S"       "Survival" \
         "C"       "Creative" \
       2>&1 1>&3);

if [[ $? == 0 ]]; then
  case $result in
    S)
      gamemode="survival"
      ;;
    C)
      gamemode="creative"
      ;;
    esac
else
  echo
  echo
  echo "Aborted."
  echo
  exit 1
fi



dialog --title "End-User License Agreement"  --yesno "In order to proceed, you must read and accept the EULA at https://account.mojang.com/documents/minecraft_eula\n\nDo you accept the EULA?" 8 60

  case $? in
  0)
   eula="accepted"
   eula_stamp=$(date)
   ;;
  1)
   echo
   echo
   echo "EULA not accepted. You are not permitted to install this software."
   echo
   exit 1 ;;
  esac




# Gather some info about your system which will be used to determine the config
revision=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}')
board="Unknown" # Default will be overridden if determined
memtotal=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}') # Amount of memory in KB
memavail=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}') # Amount of memory in KB
memvariance=$(($memtotal - $memavail)) # Figure out how much memory is being used so we can make dynamic decisions for this board
mem=$(( (($memtotal - $memvariance) / 1024) - 518)) # Amount of memory in MB
memreservation=$((($memavail * 20/100) / 1024)) # Reserve memory for system (Failure to do this will cause "Error occurred during initialization of VM")
gamemem=$(($mem - $memreservation)) # Calculate how much memory we can give to the game server (in MB)
gamememMIN=$((($mem * 80/100) - 1024)) # Figure a MINIMUM amount of memory to allocate
# Seriously, if you have 100 GB RAM, we don't need more than 12 of it
if (( $gamemem > 12000 )); then
    gamemem=12288
    gamememMIN=1500
fi
oc_volt=0
oc_friendly="N/A"
if (( $gamememMIN < 0 )); then
  dialog --title "Error" \
    --msgbox "
YOU DON'T HAVE ENOUGH AVAILABLE RAM

Your system shows only $((${memavail} / 1024))MB RAM available, but with the applications running you have only $mem MB RAM available for allocation, which doesn't leave enough for overhead. Typically I'd want to be able to allocate at least 2 GB RAM.

Either you have other things running, or your board is simply not good enough to run a Minecraft server." 18 50
   echo
   echo
   echo "Failed. Not enough memory available for Minecraft server."
   echo
   exit 0
fi

if
   [[ "$revision" == *"a03111" ]] ||
   [[ "$revision" == *"b03111" ]] ||
   [[ "$revision" == *"b03112" ]] ||
   [[ "$revision" == *"b03114" ]] ||
   [[ "$revision" == *"c03111" ]] ||
   [[ "$revision" == *"c03112" ]] ||
   [[ "$revision" == *"c03114" ]] ||
   [[ "$revision" == *"d03114" ]]; then
     board='Raspberry Pi 4'
     boardnum=1
     oc_volt=4
     oc_freq=1900
     oc_friendly="1.9 GHz"
elif [[ "$revision" == *"c03130" ]]; then
  board='Raspberry Pi 400'
  boardnum=2
  oc_volt=6
  oc_freq=2000
  oc_friendly="2.0 GHz"
fi

if (( $gamemem > 3800 )); then
  kernel=$(uname -a)
  if [[ ! "$kernel" == *"amd64"* ]] && [[ ! "$kernel" == *"arm64"* ]] && [[ ! "$kernel" == *"aarch64"* ]] && [[ ! "$kernel" == *"x86_64"* ]]; then

    dialog --title "Warning" \
    --msgbox "
WARNING: 32-Bit OS on 64-Bit Board!

Upgrade your distro to 64-bit to use your RAM.

Since you are only using a 32-bit OS, you cannot use more than 4 GB RAM for Minecraft. Abort and Upgrade." 13 50

    gamemem=2500
    gamememMIN=1500

  fi
else if (( $gamememMIN < 1024 )); then
  dialog --title "Warning" --yesno "\nWARNING: Either you have other things running, or your board is simply not good enough to run a Minecraft server. It is recommended you abort. ONLY install this on a dedicated system with no desktop environment or other applications running.\n\nWould you like to ABORT?" 14 50
  case $? in
  0)
   echo
   echo
   echo "Aborted."
   echo
   exit 1 ;;
  esac
fi
fi

dialog --title "Pinecraft Installer $pcver"  --yesno "Automatically load the server on boot?" 6 60
  case $? in
  0)
   cron=1
   ;;
  1)
   cron=0
   ;;
  esac

#dialog --title "Pinecraft Installer $pcver"  --yesno "Install Pinecraft Settings Interface?" 6 60
#  case $? in
#  0)
#   psi=1
#   ;;
#  1)
#   psi=0
#   ;;
#  esac

dialog --title "Information" \
--msgbox "
Detected Hardware:
$board

RAM to Allocate:
${gamememMIN##*( )}MB - ${gamemem##*( )}MB

Overclock To:
$oc_friendly

Server User:
$user

Server Version:
$flavor $mcver ($gamemode)" 20 50

if [[ ! $oc_volt == 0 ]]; then
  dialog --title "Confirmation"  --yesno "\nI will be modifying ${configfile} to overclock this ${board}. I am not responsible for damage to your system, and you do this at your own risk.\n\nContinue?" 12 50
  case $? in
  1)
   echo
   echo
   echo "Aborted."
   echo
   exit 1 ;;
  esac
fi


###############################################
# Finished Asking Questions: Begin Installation
###############################################

if [[ $upgrade == 1 ]] || [[ $replace == 1 ]]; then
  if [[ -e ${instdir}stop ]]; then
    dialog --infobox "Stopping server..." 3 22 ;
    su - $user -c "${instdir}stop" > /dev/null 2>&1
  fi
fi
if [[ $replace == 1 ]]; then
  dialog --infobox "Creating Backup in home folder..." 3 40 ;
  tar -czvf ${instdir}../pinecraft_backup-$(date -d "today" +"%Y-%m-%d-%H-%M").tar.gz $instdir > /dev/null 2>&1
  cd ${instdir}..
  dialog --infobox "Removing Old Install..." 3 27 ;
  rm -rf ${instdir}
  sleep 2
fi

if [[ $upgrade == 0 ]]; then
  mkdir $instdir
fi
cd $instdir

if [[ $upgrade == 1 ]]; then
  rm -rf src
fi
mkdir src && cd src

# Install the tools needed to compile C code
if [[ $compiler == 1 ]]; then

  if [ $(dpkg-query -W -f='${Status}' gcc 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    dialog --infobox "Installing gcc..." 3 34 ;
    if [[ $updated == 0 ]]; then
      apt-get update > /dev/null 2>&1
      updated=1
    fi
    apt-get -y install gcc > /dev/null 2>&1
  fi

  if [ $(dpkg-query -W -f='${Status}' g++ 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    dialog --infobox "Installing g++..." 3 34 ;
    if [[ $updated == 0 ]]; then
      apt-get update > /dev/null 2>&1
      updated=1
    fi
    apt-get -y install g++ > /dev/null 2>&1
  fi

  if [ $(dpkg-query -W -f='${Status}' cmake 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    dialog --infobox "Installing cmake..." 3 34 ;
    if [[ $updated == 0 ]]; then
      apt-get update > /dev/null 2>&1
      updated=1
    fi
    apt-get -y install cmake > /dev/null 2>&1
  fi

fi


# The server version requires the supplemental download of the vanilla server
if [[ "$dlvanilla" = "1" ]]; then
  dialog --infobox "Downloading Vanilla..." 3 34 ;
  wget $vanilla -O ${instdir}server.jar > /dev/null 2>&1
fi

dialog --infobox "Downloading ${flavor}..." 3 34 ; sleep 1

if [[ $jarname != "" ]]; then

  wget $url -O minecraft.jar > /dev/null 2>&1

elif [[ $script != "" ]]; then

  wget $script -O minecraft.sh > /dev/null 2>&1

else

  # This should never happen. No URL or Script for selection
  echo
  echo
  echo "Died."
  echo
  exit 0

fi

dialog --infobox "Installing ${flavor}..." 3 34 ;
if [[ $url == $vanilla ]]; then
  # Vanilla doesn't need to be compiled, just copy the file
  cp minecraft.jar server.jar
elif [[ $flavor == "Cuberite" ]]; then
  sh minecraft.sh -m Release -t 1
  cuberiteresponse=$?
else
  java -Xmx500M -jar minecraft.jar $switches > /dev/null 2&>1
fi

if [[ $flavor == "Cuberite" ]]; then

  if [[ $cuberiteresponse != 0 ]]; then
    dialog --title "Error" \
      --msgbox "\nSadly, it appears compiling failed." 8 50
    echo
    echo
    echo "Failed."
    echo
    exit 0
  else
    mv cuberite/build-cuberite/Server/* $instdir
  fi

else

  # The installer also created or obtained the Minecraft server.jar file. Include it.
  if [[ -e ${instdir}src/server.jar ]]; then
    cp -f ${instdir}src/server.jar $instdir
  fi

  # Fabric and Forge use a libraries folder, so we'll keep that.
  if [[ -d ${instdir}src/libraries ]]; then
    mv ${instdir}src/libraries ${instdir}
    cp ${SCRIPT_DIR}/assets/server.properties ${instdir}
  fi

  if [[ $flavor == "Forge" ]]; then
    # The forge installer removes itself and creates instead a minecraft.jar file
    # Use this instead to measure whether compile was successful
    jarname="minecraft.jar"
  fi

  jarfile=$(ls ${instdir}src/${jarname})
  if [[ $jarfile == "" ]]; then
    dialog --title "Error" \
      --msgbox "\nSadly, it appears compiling failed." 8 50
    echo
    echo
    echo "Failed."
    echo
    exit 0
  else
    cp $jarfile $instdir
    t=${jarfile#*-}
    version=$(basename $t .jar)
  fi

fi


if [[ $psi == 1 ]]; then

  # PHP interpreter / server for Pinecraft configuration interface
  if [ $(dpkg-query -W -f='${Status}' php 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    dialog --infobox "Installing PHP..." 3 34 ;
    if [[ $updated == 0 ]]; then
      apt-get update > /dev/null 2>&1
      updated=1
    fi
    apt-get -y install php-cli > /dev/null 2>&1
  fi

  if [[ ! -d /etc/pinecraft/psi/ ]]; then
    mkdir -p /etc/pinecraft/psi
  fi

  cp ${base}/assets/psi/* /etc/pinecraft/psi/

  printf '{"pcver":"%s","instdir":"%s","flavor":"%s"}\n' "$pcver" "$instdir" "$flavor" > /etc/pinecraft/psi/psi.json

  chown -R $user:$user /etc/pinecraft/
fi


###############################################
# Patch Minecraft against exploit within Log4j
# See https://www.minecraft.net/en-us/article/important-message--security-vulnerability-java-edition?ref=launcher
###############################################

# This exploit was patched in 1.18.1, so we only have to deal with older releases.

# 1.17-1.18
if [ $(version $mcver) -ge $(version "1.17") ] && [ $(version $mcver) -le $(version "1.18") ]; then
  cli_args="-Dlog4j2.formatMsgNoLookups=true"
fi
# 1.12-1.16.5
if [ $(version $mcver) -ge $(version "1.12") ] && [ $(version $mcver) -le $(version "1.16.5") ]; then
  wget https://launcher.mojang.com/v1/objects/02937d122c86ce73319ef9975b58896fc1b491d1/log4j2_112-116.xml -O ${instdir}log4j2_112-116.xml > /dev/null 2>&1
  cli_args="-Dlog4j.configurationFile=log4j2_112-116.xml"
fi
# 1.7-1.11.2
if [ $(version $mcver) -ge $(version "1.7") ] && [ $(version $mcver) -le $(version "1.11.2") ]; then
  wget https://launcher.mojang.com/v1/objects/dd2b723346a8dcd48e7f4d245f6bf09e98db9696/log4j2_17-111.xml -O ${instdir}log4j2_112-116.xml > /dev/null 2>&1
  cli_args="-Dlog4j.configurationFile=log4j2_17-111.xml"
fi

###############################################
# /Patch against exploit within Log4j
###############################################


###############################################
# Create the scripts
###############################################

dialog --infobox "Creating scripts..." 3 34 ; sleep 1

# Create the run script
echo '#!/bin/bash
user=$(whoami); if [[ $user != "'${user}'" ]]; then echo "Cannot run as ${user} - expecting '${user}'"; exit; fi
cd "$(dirname "$0")"' > ${instdir}server
if [[ $flavor == "Cuberite" ]]; then
  echo ${instdir}cuberite/Cuberite >> ${instdir}server
else
  # Forge requires its own unix_args be included
  if [[ $flavor == "Forge" ]]; then
    # Forge servers
    forge_args=$(ls ${instdir}libraries/net/minecraftforge/forge/*/unix_args.txt | head -n 1)
    forge_args="@${forge_args}"
    echo "exec java ${cli_args} -Xms${gamememMIN}M -Xmx${gamemem}M ${forge_args}" >> ${instdir}server
  else
    # Non-forge servers
    echo "exec java ${cli_args} -Xms${gamememMIN}M -Xmx${gamemem}M -jar `basename $jarfile` --nogui" >> ${instdir}server
  fi
fi
chmod +x ${instdir}server
# Set ownership to the user
chown -R $user:$user $instdir
# Need to generate the config and EULA
# Note: Because the EULA is not yet accepted within eula.txt, the server will init and quit immediately.
if [[ $upgrade == 0 ]] || [[ ! -e ${instdir}server.properties ]]; then
  dialog --infobox "Initializing server..." 3 34 ; sleep 1
  su - $user -c ${instdir}server > /dev/null 2>&1
fi

# Accepting the EULA
if [[ $eula == "accepted" ]]; then
  echo "# https://account.mojang.com/documents/minecraft_eula ACCEPTED by user during installation
# $eula_stamp
eula=true" > ${instdir}eula.txt
fi

# Create the safe reboot script
echo '#!/bin/bash
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root" 2>&1
  exit 1
fi
su - $user -c "'${instdir}'stop"
echo
echo "Rebooting."
/sbin/reboot' > ${instdir}reboot
chmod +x ${instdir}reboot

# Create the safe stop script
echo '#!/bin/bash
user=$(whoami);
if [[ $user != "'${user}'" ]]; then
  if su - '$user' -c "/usr/bin/screen -list" | grep -q Pinecraft; then
    printf "Stopping Minecraft Server. This will take time."
    su - '$user' -c "screen -S Pinecraft -p 0 -X stuff \"stop^M\""
    running=1
  fi
  while [[ $running == 1 ]]; do
    if ! su - '$user' -c "/usr/bin/screen -list" | grep -q Pinecraft; then
      running=0
    fi
    sleep 3
    printf "."
  done
else
  if /usr/bin/screen -list | grep -q Pinecraft; then
    printf "Stopping Minecraft Server. This will take time."
    screen -S Pinecraft -p 0 -X stuff "stop^M"
    running=1
  fi
  while [[ $running == 1 ]]; do
    if ! /usr/bin/screen -list | grep -q Pinecraft; then
      running=0
    fi
    sleep 3
    printf "."
  done
fi
echo
echo "Done. Minecraft has been stopped safely."' > ${instdir}stop
chmod a+x ${instdir}stop

# Create the service
echo '#/bin/bash
set -e

### BEGIN INIT INFO
# Provides:       pinecraft
# Required-Start: $remote_fs $network
# Required-Stop:  $remote_fs
# Default-Stop:   0 1 6
# Short-Description: Minecraft server powered by Pinecraft Installer
### END INIT INFO

case "$1" in

stop)
      '${instdir}'stop
    ;;

status)
      user=$(whoami); if [ $user != "'${user}'" ]; then echo "Cannot run as ${user} - expecting '${user}'"; exit; fi
      if screen -ls | grep -q Pinecraft; then
        echo 1
      else
        echo 0
      fi
    ;;

*)

    echo "usage: $0 <stop|status>" >&2

    exit 1
esac
' > /etc/init.d/pinecraft
chmod a+x /etc/init.d/pinecraft

# Make the stop command run automatically at shutdown
sudo ln -s ${instdir}stop /etc/rc0.d/K01stop-pinecraft
# Make the stop command run automatically at reboot
sudo ln -s ${instdir}stop /etc/rc6.d/K01stop-pinecraft

###############################################
# /Create the scripts
###############################################


###############################################
# Create config folders
###############################################

  if [[ ! -d /etc/pinecraft/pid/ ]]; then
    mkdir -p /etc/pinecraft/pid
  fi

  chown -R $user:$user /etc/pinecraft/

###############################################
# /Create config folders
###############################################


###############################################
# Overclock
###############################################

if [[ ! $oc_volt == 0 ]]; then
  dialog --infobox "Overclocking your system..." 3 34 ; sleep 1
  datestamp=$(date +"%Y-%m-%d_%H-%M-%S")

  cp $configfile /boot/config-${datestamp}.txt

  # Replace existing overclock settings or add new ones if none exist

  /bin/sed -i -- "/over_voltage=/c\over_voltage=${oc_volt}" $configfile
  if ! grep -q "over_voltage=" $configfile; then
    echo "over_voltage=$oc_volt" >> $configfile
  fi

  /bin/sed -i -- "/arm_freq=/c\arm_freq=${oc_freq}" $configfile
  if ! grep -q "arm_freq=" $configfile; then
    echo "arm_freq=${oc_freq}" >> $configfile
  fi

  /bin/sed -i -- "/dtparam=audio=/c\dtparam=audio=off" $configfile
  if ! grep -q "dtparam=audio=" $configfile; then
    echo "dtparam=audio=" >> $configfile
  fi

fi

###############################################
# /Overclock
###############################################


###############################################
# Tweak Server Configs
###############################################

if [[ -e ${instdir}server.properties ]]; then

  dialog --infobox "Applying config..." 3 34 ; sleep 1
  # These settings are my own defaults, so only do these during first install (not upgrade)
  # Will not replace user-configured changes in the server.properties
  if [[ $upgrade == 0 ]]; then

    # Enable Query
      # Change the value if it exists
      /bin/sed -i '/enable-query=/c\enable-query=true' ${instdir}server.properties
      # Add it if it doesn't exist
      if ! grep -q "enable-query=" ${instdir}server.properties; then
        echo "enable-query=true" >> ${instdir}server.properties
      fi

    # Set game difficulty to Normal (default is Easy, but we want at least SOME challenge)
      # Change the value if it exists
      /bin/sed -i '/difficulty=/c\difficulty=normal' ${instdir}server.properties
      # Add it if it doesn't exist
      if ! grep -q "difficulty=" ${instdir}server.properties; then
        echo "difficulty=normal" >> ${instdir}server.properties
      fi

    # Set the view distance to something the Raspberry Pi can handle quite well
      # Change the value if it exists
      /bin/sed -i '/view-distance=/c\view-distance=7' ${instdir}server.properties
      # Add it if it doesn't exist
      if ! grep -q "view-distance=" ${instdir}server.properties; then
        echo "view-distance=7" >> ${instdir}server.properties
      fi

    # Level Seed
      # Change the value if it exists
      /bin/sed -i "/level-seed=/c\level-seed=${seed}" ${instdir}server.properties
      # Add it if it doesn't exist
      if ! grep -q "level-seed=" ${instdir}server.properties; then
        echo "level-seed=${seed}" >> ${instdir}server.properties
      fi

  fi

  # These ones, however, are selected by the user, so we'll make these changes even if already installed

    # Game Mode (User Selected During Install)
      # Change the value if it exists
      /bin/sed -i "/gamemode=/c\gamemode=${gamemode}" ${instdir}server.properties
      # Add it if it doesn't exist
      if ! grep -q "gamemode=" ${instdir}server.properties; then
        echo "gamemode=${gamemode}" >> ${instdir}server.properties
      fi

fi

###############################################
# /Tweak Server Configs
###############################################


# Create a file to later let us know the version of Pinecraft used
echo $pcver > ${instdir}cat5tv.ver

# Set ownership to the user
chown -R $user:$user $instdir



###############################################
# Install cronjob to auto-start server on boot
###############################################

# Dump current crontab to tmp file, empty if doesn't exist
  crontab -u $user -l > /tmp/cron.tmp 2>/dev/null

  if [[ "$cron" == "1" ]]; then
    # Remove previous entry (in case it's an old version)
    /bin/sed -i~ "\~${instdir}server~d" /tmp/cron.tmp
    # Add server to auto-load at boot if doesn't already exist in crontab
    if ! grep -q "minecraft/server" /tmp/cron.tmp; then
      dialog --infobox "Enabling auto-run..." 3 34 ; sleep 1
      printf "\n@reboot /usr/bin/screen -dmS Pinecraft ${instdir}server > /dev/null 2>&1\n" >> /tmp/cron.tmp
      cronupdate=1
    fi
  else
    # Just in case it was previously enabled, disable it
    # as this user requested not to auto-run
    /bin/sed -i~ "\~${instdir}server~d" /tmp/cron.tmp
    cronupdate=1
  fi

  if [[ $psi == 1 ]]; then
    if ! grep -q "pinecraft/psi/psi.php" /tmp/cron.tmp; then
      dialog --infobox "Enabling Pinecraft SI..." 3 34 ; sleep 1
      php=$(type -p php)
      printf "\n@reboot $php -S 0.0.0.0:8088 -t /etc/pinecraft/psi/ > /dev/null 2>&1\n" >> /tmp/cron.tmp
      cronupdate=1
    fi
  fi

  # Import revised crontab
  if [[ "$cronupdate" == "1" ]]
  then
    crontab -u $user /tmp/cron.tmp
  fi

  # Remove temp file
  rm /tmp/cron.tmp

###############################################
# /Install cronjob to auto-start server on boot
###############################################

###############################################
# Run the server now
###############################################

  dialog --infobox "Starting the server..." 3 26 ;
  su - $user -c "/usr/bin/screen -dmS Pinecraft ${instdir}server"

###############################################
# /Run the server now
###############################################

# Forge is a bit funny because it doesn't create server.properties file during initialization, so that file is created from assets.
# However, upon initialization, and 'mods' folder is created, so we will use that to identify if initialization was successful.
if [[ $flavor == "Forge" ]]; then
  if [[ ! -d ${instdir}mods ]]; then
    # mods folder not found, so initialization failed. Remove the server.properties asset file so we don't lie about success
    rm ${instdir}server.properties
  fi
fi

if [[ -e ${instdir}server.properties ]]; then
  dialog --title "Success" \
      --msgbox "\n$flavor Minecraft server installed successfully." 8 50
else
  dialog --title "Warning" \
      --msgbox "\n$flavor appears to have installed, but is not initializing correctly. It is unlikely to work until this is resolved." 9 50
fi

clear
  echo
  echo
  echo "Installation complete."
  echo
  echo "Minecraft server is now running on $ip"
  echo
  echo "Remember: World generation can take a few minutes. Be patient."
  echo
  echo "Documentation: https://github.com/Cat5TV/Pinecraft"
  echo
  echo "Support The Project: https://patreon.com/Pinecraft"
  echo
