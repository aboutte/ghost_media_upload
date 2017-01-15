
# Instrutions for CentOS 7

wget https://packages.chef.io/files/stable/chefdk/1.1.16/el/7/chefdk-1.1.16-1.el7.x86_64.rpm
yum install chefdk-1.1.16-1.el7.x86_64.rpm
yum install sqlite-devel gcc

cd ghost_photo_upload
/opt/chefdk/embedded/bin/bundle install

# Install DropBox

curl -Lo dropbox-linux-x86_64.tar.gz https://www.dropbox.com/download?plat=lnx.x86_64
sudo mkdir -p /opt/dropbox
sudo tar xzfv dropbox-linux-x86_64.tar.gz --strip 1 -C /opt/dropbox


# TODO:
- add bash script to repo that can be used to pull down latest version of repo
- finish support for .mov files
- move hard coded configs into env variables
- move to using cron files

3 * * * * cd /home/aboutte/ghost_photo_upload/; /opt/chefdk/embedded/bin/bundle exec ghost_photo_upload.rb sync_posts_to_directories  >> /var/log/ghost_photo_upload.log 2>&1
*/5 * * * * cd /home/aboutte/ghost_photo_upload/; /opt/chefdk/embedded/bin/bundle exec ghost_photo_upload.rb sync_media_to_posts >> /var/log/ghost_photo_upload.log 2>&1
