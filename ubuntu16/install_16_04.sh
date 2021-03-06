#! /bin/bash

# COLORING HELPERS
source rainbow.sh

ran_from=$(pwd)
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

echoyellow "Updating apt-get"
sudo apt-get update

echoyellow "Downloading & installing curl, python, php, apache2, mysql, nodejs, npm, supervisor"
sudo apt-get install -y vim curl supervisor nodejs npm composer python-software-properties python-dev python-serial git php apache2 libapache2-mod-php php-curl php-mbstring php7.0-xml mysql-server php-mysql php-xdebug openssh-server

echoyellow "Installing & setting up redis"
tar xvzf redis-stable.tar.gz
cd redis-stable 
make
sudo make install
sudo mkdir /etc/redis
sudo mkdir -p /var/redis/6379
sudo cp utils/redis_init_script /etc/init.d/redis_6379
sudo cp redis.conf /etc/redis/6379.conf
sudo sed -i "s/daemonize .*/daemonize yes/" /etc/redis/6379.conf
sudo sed -i "s/pidfile .*/pidfile \/var\/run\/redis_6379.pid/" /etc/redis/6379.conf
sudo sed -i "s/logfile .*/logfile \/var\/log\/redis_6379.log/" /etc/redis/6379.conf
sudo sed -i "s/dir .*/dir \/var\/redis\/6379/" /etc/redis/6379.conf
sudo update-rc.d redis_6379 defaults
sudo /etc/init.d/redis_6379 start


echoyellow "Setting xdebug"
sudo sh -c 'cat << EOF | tee -a /etc/php/7.0/mods-available/xdebug.ini
xdebug.scream=1
xdebug.cli_color=1
xdebug.show_local_vars=1
EOF'

echoyellow "Enabling mod rewrite"
sudo a2enmod rewrite

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/disable_functions = .*/disable_functions = /" /etc/php/7.0/cli/php.ini

echoyellow "Restarting apache & mysql"
sudo service apache2 restart
sudo service mysql start

echoyellow "Creating mysql database"
echo "create database olm_app_server" | mysql -u root -proot

mkdir -p /var/www
sudo chmod -R 775 /var/www
sudo chown -R www-data:www-data /var/www
mv $ran_from/olm_app_server /var/www/olm_app_server
cd /var/www/olm_app_server


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
sudo service apache2 restart

echoyellow "Adding appserver.dev to /etc/hosts"
sudo sh -c 'cat >> /etc/hosts << EOL
# OLM APP SERVER
127.0.0.1 appserver.dev
EOL'

echoyellow "Setting permissions and ownership"
sudo chown -R www-data:www-data /var/www/olm_app_server
sudo chmod -R 775 /var/www/olm_app_server
echoyellow "Enabling www-data to run programs"
sudo sed -i "s/www-data:\/var\/www.*/www-data:\/var\/www:\/bin\/bash/" /etc/passwd

echoyellow "Adding user www-data to dialout (usb/serial devices group)"
sudo usermod -aG dialout www-data
sudo usermod -aG dialout $USER

echoyellow "Installing nodejs dependencies"
cd /var/www/olm_app_server
sudo npm install

echoyellow "Setting up supervisor for laravel queue"
sudo mv $ran_from/laravel-worker.conf /etc/supervisor/conf.d/laravel-worker.conf
sudo mv $ran_from/nodejs-worker.conf /etc/supervisor/conf.d/nodejs-worker.conf
sudo mv /etc/init.d/supervisor /etc/init.d/supervisord
sudo update-rc.d supervisord defaults
sudo service supervisord start
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start laravel-worker:*
sudo supervisorctl start nodejs-worker:*
