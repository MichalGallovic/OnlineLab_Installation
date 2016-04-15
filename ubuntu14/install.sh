#! /bin/bash

# COLORING HELPERS
wget https://raw.githubusercontent.com/xr09/rainbow.sh/master/rainbow.sh
source rainbow.sh

ran_from=$(pwd)
version=$(lsb_release -sr)
version=${version:0:2}

echoyellow "Updating apt-get"
apt-get update

debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

echoyellow "Downloading & installing curl and python"
apt-get install -y --force-yes vim curl python-software-properties
add-apt-repository -y ppa:ondrej/php5-5.6
if [ $version = "15" ]; then
  add-apt-repository -y ppa:git-core/ppa
fi
apt-get update

echoyellow "Downloading & installing php, apache2 and mysql"
apt-get install -y --force-yes php5 apache2 libapache2-mod-php5 php5-curl php5-gd php5-mcrypt php5-readline mysql-server-5.5 php5-mysql php5-xdebug git-core

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
if [ $version = "14" ]; then
  service apache2 restart
fi

if [ $version = "15" ]; then
  systemctl restart apache2
fi

/etc/init.d/mysql start

echoyellow "Creating mysql database"
echo "create database olm_app_server" | mysql -u root -proot

mkdir -p /var/www
cd /var/www/olm_app_server

echoyellow "Downloading & intalling composer"
curl -sS https://getcomposer.org/installer | php

echoyellow "Downloading & installing olm app server dependencies"
php composer.phar install

echoyellow "Setting db credentials"
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

if [ $version = "14" ]; then
  service apache2 restart
fi

if [ $version = "15" ]; then
  systemctl restart apache2
fi

echoyellow "Adding appserver.dev to /etc/hosts"
cat >> /etc/hosts << EOL
# OLM APP SERVER
127.0.0.1 appserver.dev
EOL

echoyellow "Setting permissions to storage & boostrap/cache"
chmod -R 777 storage
chmod -R 777 bootstrap/cache

echoyellow "Adding user www-data to dialout (usb/serial devices group)"
usermod -aG dialout www-data
usermod -aG dialout vagrant

rm $ran_from/rainbow.sh
