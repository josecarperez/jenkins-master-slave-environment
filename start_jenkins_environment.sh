#!/usr/bin/env bash

CLEAN_ENV=0

function wait_for() {
   MSG="."
   while [ ! -f $1 ]
   do
     echo -n $MSG
     sleep 1
     MSG="$MSG."
   done
}

function print_usage() {
    echo -e "\nUsage: $0 -p path-home -m master -s slave [-c clean-env] [-h help]"
    echo -e "  -p --path-home   Jenkins home path. \n\tThe path will be use as volume for the container. It will map with '/var/jenkins_home'."
    echo -e "  -m --master      Master node name. \n\tUsed as name in master container."
    echo -e "  -s --slave       Slave node name. \n\tUsed as name in slave container."
    echo -e "  -c --clean-evn   Clean environment. \n\tIt allows to clean the folder used as volume for the containers and eliminate the containers with the name of master and slave passed as parameters."
    echo    "  -h --help        Display help."
    exit 1
}

ARGS=$(getopt -o "p:m:s:ch" -l "path-home:,master:,slave:,clean-env,help"  -- "$@");
if [ $? -ne 0 ]; then echo "Error parsing parameters." && print_usage; fi
if [ $# -lt 6 ] && [ $# -ne 1 ]; then echo "The options --path-home, --master and --slave are mandatory." && print_usage; fi

eval set -- "$ARGS";

while true; do
  case "$1" in
    -p|--path-home)
      JENKINS_HOME_PATH=$2
      shift;
      ;;
    -m|--master)
      MASTER_NAME=$2
      shift;
      ;;
    -s|--slave)
      SLAVE_NAME=$2
      shift;
      ;;
    -c|--clean-env)
      CLEAN_ENV=1
      ;;
    -h|--help)
      print_usage
      ;;
    --) shift; break ;;
  esac
  shift
done

if [ ${CLEAN_ENV:?} -eq 1 ]
then 
  echo -e "\nCleaning environment..."
  echo "- Stopping & removing containers: ${MASTER_NAME:?} and ${SLAVE_NAME:?}"
  docker stop ${MASTER_NAME:?} > /dev/null 2>&1 && docker rm ${MASTER_NAME:?} > /dev/null 2>&1 
  docker stop ${SLAVE_NAME:?} > /dev/null 2>&1 && docker rm ${SLAVE_NAME:?} > /dev/null 2>&1
  if [ -d "${JENKINS_HOME_PATH:?}" ]; then
    echo "- Cleaning folder ${JENKINS_HOME_PATH:?}"
    find ${JENKINS_HOME_PATH:?} -mindepth 1 -delete
  fi
elif [ "$(ls -A ${JENKINS_HOME_PATH:?})" ]; then
     echo "${JENKINS_HOME_PATH:?} is not empty. Use --clean-env option." && print_usage && exit 1
fi 

echo -e "\nStarting Jenkins master ${MASTER_NAME:?} (vol: ${JENKINS_HOME_PATH:?})"
if [ ! -d "${JENKINS_HOME_PATH:?}" ]; then mkdir ${JENKINS_HOME_PATH:?}; fi
docker run -d -p 8080:8080 -p 50000:50000 -v ${JENKINS_HOME_PATH:?}:/var/jenkins_home --name ${MASTER_NAME:?} jenkins/jenkins:lts
if [ $? -ne 0 ]; then echo -e "\n\nError creating container ${MASTER_NAME:?}." && print_usage && exit 1; fi

echo -e "\nCreating SSH Key Pair."
docker exec -i -u jenkins ${MASTER_NAME:?} ssh-keygen -N "" -f /var/jenkins_home/.ssh/id_rsa > /dev/null 2>&1
MASTER_PUB=$(docker exec -i -u jenkins ${MASTER_NAME:?} cat /var/jenkins_home/.ssh/id_rsa.pub)

echo -e "\nStarting Jenkins slave ${SLAVE_NAME:?}"
docker run -d --name ${SLAVE_NAME:?} jenkinsci/ssh-slave "${MASTER_PUB:?}"
if [ $? -ne 0 ]; then echo -e "\n\nError creating container ${SLAVE_NAME:?}." && print_usage && exit 1; fi

echo -e "\nCreating 'ssh/known_hosts' file in master node."
IP_SLAVE=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${SLAVE_NAME:?})
docker exec -i -u jenkins ${MASTER_NAME:?} bash -c "ssh-keyscan -H ${IP_SLAVE:?} >> /var/jenkins_home/.ssh/known_hosts" > /dev/null 2>&1
PRIVATE_KEY=$(docker exec -i -u jenkins ${MASTER_NAME:?} cat /var/jenkins_home/.ssh/id_rsa)

echo -e "\n\n****************************************************************"
echo -e "********************[  INIT INFO  ]*****************************"
echo -e "****************************************************************\n\n"

echo -e " JAVA_HOME path to configure on node creation: "
echo -e "---------------------------------------------------------------- "
echo -e "\n/docker-java-home/bin/java"

echo -e "\n IP of slave node created: "
echo -e "---------------------------------------------------------------- "
echo -e "\n${IP_SLAVE:?}"

echo -e "\n Private key to configure credential of access on node creation: "
echo -e "---------------------------------------------------------------- "
echo -e "\n${PRIVATE_KEY:?}"

echo -e "\n\nStart Jenkins and configure it with: " 
echo -e "\n*** ADMINISTRATOR PASSWORD *** "
wait_for "${JENKINS_HOME_PATH:?}/secrets/initialAdminPassword"
echo -e "\n$(docker exec -i -u jenkins ${MASTER_NAME:?} cat /var/jenkins_home/secrets/initialAdminPassword)"

echo -e "\ndone!"

