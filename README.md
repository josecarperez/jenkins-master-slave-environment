# jenkins-master-slave-environment
Creating a master and a slave of Jenkins to start a testing environment with docker.   
#### Usage  
`start_jenkins_environment.sh -p path-home -m master -s slave [-c clean-env] [-h help]`

#### Params
  `-p --path-home`   Jenkins home path.  
	The path will be use as volume for the container. It will map with '/var/jenkins_home'.
  
  `-m --master`      Master node name.  
	Used as name in master container.  
	
  `-s --slave`       Slave node name.  
	Used as name in slave container.  
	
  `-c --clean-evn`   Clean environment.  
	It allows to clean the folder used as volume for the container and to eliminate the containers with the name of master and slave passed as parameters.  
	  
  `-h --help`        Display help.  


#### Example

`./start_jenkins_environment.sh -p /tmp/jenkins --master jenkins-master --slave jenkins-slave-01 --clean-env`




