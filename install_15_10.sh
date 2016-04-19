#! /bin/bash

# COLORING HELPERS
wget https://raw.githubusercontent.com/xr09/rainbow.sh/master/rainbow.sh
source rainbow.sh

ran_from=$(pwd)

echoyellow "Updating apt-get"
apt-get update

debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

echoyellow "Downloading & installing curl and python"
apt-get install -y vim curl python-software-properties
add-apt-repository -y ppa:ondrej/php5-5.6
add-apt-repository -y ppa:git-core/ppa
apt-get update

echoyellow "Downloading & installing php, apache2 and mysql"
apt-get install -y php5 apache2 libapache2-mod-php5 php5-curl php5-gd php5-mcrypt php5-readline mysql-server php5-mysql git php5-xdebug

cat << EOF | tee -a /etc/php5/mods-available/xdebug.ini
xdebug.scream=1
xdebug.cli_color=1
xdebug.show_local_vars=1
EOF

a2enmod rewrite

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini
sed -i "s/disable_functions = .*/disable_functions = /" /etc/php5/cli/php.ini

echoyellow "Restarting apache & mysql"
systemctl restart apache2
/etc/init.d/mysql start

echoyellow "Creating mysql database"
echo "create database olm_app_server" | mysql -u root -proot

mkdir -p /var/www
cd /var/www

echoyellow "Cloning olm app server from git repository"
gitclone="git clone https://gitlab.com/michalgallovic/olm_appserver.git olm_app_server"

eval $gitclone

while : ;
do
   [[ -d "olm_app_server" ]] && break
   echoyellow "Try again please ..."
   eval $gitclone
done

cd olm_app_server

echoyellow "Downloading & intalling composer"
curl -sS https://getcomposer.org/installer | php

echoyellow "Downloading & installing olm app server dependencies"
php composer.phar install

echoyellow "Setting db credentials"
wget https://gitlab.com/michalgallovic/olm_appserver_install/raw/master/.env.example
mv .env.example .env
sed -i 's/DB_DATABASE.*/DB_DATABASE=olm_app_server/' .env
sed -i 's/DB_USERNAME.*/DB_USERNAME=root/' .env
sed -i 's/DB_PASSWORD.*/DB_PASSWORD=root/' .env


echoyellow "Migrating and seeding olm app tables"
php artisan key:generate
php artisan server:reset

echoyellow "Setting up appserver.conf in apache"

cat > /etc/apache2/sites-available/appserver.conf << EOL
<VirtualHost *:80>
  ServerName appserver.dev
  DocumentRoot "/var/www/olm_app_server/public"
  <Directory "/var/www/olm_app_server/public">
    AllowOverride all
  </Directory>
</VirtualHost>
EOL

echoyellow "Enabling appserver.dev site"

ln -s /etc/apache2/sites-available/appserver.conf /etc/apache2/sites-enabled/appserver.conf

echoyellow "Disabling default 000-default.conf"
rm /etc/apache2/sites-enabled/000-default.conf
systemctl restart apache2

echoyellow "Adding appserver.dev to /etc/hosts"
cat >> /etc/hosts << EOL
# OLM APP SERVER
127.0.0.1 appserver.dev
EOL

echoyellow "Setting permissions to storage & boostrap/cache"
chmod -R 777 /var/www/olm_app_server

echoyellow "Adding user www-data to dialout (usb/serial devices group)"
usermod -aG dialout www-data

rm $ran_from/rainbow.sh