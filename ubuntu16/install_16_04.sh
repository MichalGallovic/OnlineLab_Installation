#! /bin/bash

# COLORING HELPERS
source rainbow.sh

ran_from=$(pwd)

sudo add-apt-repository -y ppa:ondrej/php

echoyellow "Updating apt-get"
sudo apt-get update

echoyellow "Downloading & installing curl, python, php, apache2 and mysql"
sudo apt-get install -y vim curl composer python-software-properties python-dev python-serial git php apache2 libapache2-mod-php php-curl php-gd php-mcrypt php-mbstring php7.0-xml php-readline mysql-server php-mysql php-xdebug

sudo sh -c 'cat << EOF | tee -a /etc/php/5.6/mods-available/xdebug.ini
xdebug.scream=1
xdebug.cli_color=1
xdebug.show_local_vars=1
EOF'

sudo a2enmod rewrite

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/5.6/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/5.6/apache2/php.ini
sed -i "s/disable_functions = .*/disable_functions = /" /etc/php/5.6/cli/php.ini

echoyellow "Restarting apache & mysql"
sudo service apache2 restart
sudo service mysql start

echoyellow "Creating mysql database"
echo "create database olm_app_server" | mysql -u root -proot

mkdir -p /var/www
chmod -R 775 /var/www
chown -R www-data:www-data /var/www
mv olm_app_server /var/www/olm_app_server
cd /var/www/olm_app_server

# echoyellow "Cloning olm app server from git repository"
# gitclone="git clone https://gitlab.com/michalgallovic/olm_appserver.git olm_app_server"

# eval $gitclone

# while : ;
# do
#    [[ -d "olm_app_server" ]] && break
#    echoyellow "Try again please ..."
#    eval $gitclone
# done

echoyellow "Installing app dependencies with composer"
composer install

echoyellow "Setting app credentials"
mv $ran_from/.env.example /var/www/olm_app_server/.env
sed -i 's/DB_DATABASE.*/DB_DATABASE=olm_app_server/' .env
sed -i 's/DB_USERNAME.*/DB_USERNAME=root/' .env
sed -i 's/DB_PASSWORD.*/DB_PASSWORD=root/' .env


echoyellow "Migrating and seeding olm app tables"
php artisan key:generate
php artisan server:reset

echoyellow "Setting up appserver.conf in apache"

sudo sh -c 'cat > /etc/apache2/sites-available/appserver.conf << EOL
<VirtualHost *:80>
  ServerName appserver.dev
  DocumentRoot "/var/www/olm_app_server/public"
  <Directory "/var/www/olm_app_server/public">
    AllowOverride all
  </Directory>
</VirtualHost>
EOL'

echoyellow "Enabling appserver.dev site"

sudo ln -s /etc/apache2/sites-available/appserver.conf /etc/apache2/sites-enabled/appserver.conf

echoyellow "Disabling default 000-default.conf"
sudo rm /etc/apache2/sites-enabled/000-default.conf
sudo service restart apache2

echoyellow "Adding appserver.dev to /etc/hosts"
sudo sh -c 'cat >> /etc/hosts << EOL
# OLM APP SERVER
127.0.0.1 appserver.dev
EOL'

echoyellow "Setting permissions and ownership"
sudo chown -R www-data:www-data /var/www/olm_app_server
sudo chmod -R 775 /var/www/olm_app_server

echoyellow "Adding user www-data to dialout (usb/serial devices group)"
sudo usermod -aG dialout www-data
sudo usermod -aG dialout $USER

rm $ran_from/rainbow.sh