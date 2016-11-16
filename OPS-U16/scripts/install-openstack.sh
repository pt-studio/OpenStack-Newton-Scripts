#!/bin/bash


###############################################################################
## Khai bao cac chuong trinh ho tro
source config.cfg
source functions.sh

###############################################################################
## Khai bao duong dan
path_chrony=/etc/chrony/chrony.conf

function install_crudini {
	echocolor "Installing CRUDINI"
	sleep 3
	apt-get -y install crudini
}

function install_python_client {
	echocolor "Install python client"
	sleep 3
	apt-get -y install python-openstackclient
}

function install_ntp {
	echocolor "Install and config NTP"
	sleep 3

	apt-get -y install chrony
	test -f $path_chrony.orig || cp $path_chrony $path_chrony.orig

	if [ "$1" == "controller" ]; then
		sed -i 's/pool 2.debian.pool.ntp.org offline iburst/ \
		server 1.vn.pool.ntp.org iburst \
		server 0.asia.pool.ntp.org iburst \
		server 3.asia.pool.ntp.org iburst/g' $path_chrony

	elif [[ "$1" == "compute1" ]]; then
		sed -i 's/pool 2.debian.pool.ntp.org offline iburst/ \
		server $HOST_CTL iburst/g' $path_chrony

	elif [[ "$1" == "compute2" ]]; then
		sed -i 's/pool 2.debian.pool.ntp.org offline iburst/ \
		server $HOST_CTL iburst/g' $path_chrony

	else
		echo "Sai may chu NTP roi"
		exit 1
	fi

	service chrony restart
	echocolor "Check NTP Server"
	sleep 3
	chronyc sources
		
}

function install_database {
	echocolor "Install MYSQL"
	sleep 3

	echo mariadb-server-10.0 mysql-server/root_password $MYSQL_PASS | debconf-set-selections
	echo mariadb-server-10.0 mysql-server/root_password_again $MYSQL_PASS | debconf-set-selections
	apt-get install -y  mariadb-server

	sed -r -i 's/127\.0\.0\.1/0\.0\.0\.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
	sed -i 's/character-set-server  = utf8mb4/character-set-server  = utf8/' /etc/mysql/mariadb.conf.d/50-server.cnf
	sed -i 's/collation-server/#collation-server/' /etc/mysql/mariadb.conf.d/50-server.cnf

	systemctl restart mysql

	cat << EOF | mysql -uroot -p$MYSQL_PASS
	GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;
	GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;
	FLUSH PRIVILEGES;

	EOF

	echocolor "Configuring MYSQL"
	sleep 3

	cat << EOF > /etc/mysql/conf.d/openstack.cnf

	[client]
	default-character-set = utf8

	[mysqld]
	bind-address = 0.0.0.0
	default-storage-engine = innodb
	innodb_file_per_table
	max_connections = 4096
	collation-server = utf8_general_ci
	character-set-server = utf8
	init-connect = 'SET NAMES utf8'

	[mysql]
	default-character-set = utf8
	EOF

	echocolor "Restarting MYSQL"
	sleep 5
	systemctl restart mysql
}

#############################################

function install_rabbitmq {
	echocolor "Install and Config RabbitMQ"
	sleep 3

	apt-get -y install rabbitmq-server
	rabbitmqctl add_user openstack $RABBIT_PASS
	rabbitmqctl set_permissions openstack ".*" ".*" ".*"
	# rabbitmqctl change_password guest $RABBIT_PASS
	sleep 3

	service rabbitmq-server restart
	echocolor "Finish setup pre-install package !!!"
}

##############################################
function install_memcache {
	echocolor "Install memcache"
	sleep 3
	apt-get -y install memcached python-memcache
	sed -i "s/-l 127.0.0.1/-l $CTL_MGNT_IP/g" /etc/memcached.conf
	service memcached restart

	echocolor "Done, you can run next script"
}


### Thuc thi ham

### Kie tra ham va cu phap thuc thi 
if [ $# -ne 1 ]
    then
        echocolor  "Thu thi voi cac tuy chon sau"
        echo "Thuc hien tren Controller bash $0 controller"
        echo "Thuc hien tren Compute1 bash $0 compute1"
        echo "Thuc hien tren Compute1 bash $0 compute2"
        exit 1;
fi

install_crudini
install_python_client
install_ntp
install_database $1
install_rabbitmq
install_memcache