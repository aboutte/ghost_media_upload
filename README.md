# Ghost Media Sync

## Summary

## Details

## Usage

- run the ./build.sh script
- deploy cloudformation stack with following command:

```
bundle exec ./aws-lambda-ffmpeg.rb create --region us-west-2 --stack-name aws-lambda-ffmpeg-$(date '+%s') --disable-rollback 
```

During development the following command can be useful to update a Lambda function to use a new copy of zip:

```
aws --region us-west-2 lambda   update-function-code --function-name aws-lambda-ffmpeg-1491169348-Lambda-XHVMDTCPHDCZ --s3-bucket aboutte-lambda --s3-key aws-lambda-ffmpeg.zip --publish
```

### Prerequisites

### Install


## TODO: 

- [x] get Travis CI hooked up
- [ ] setup some rake unit tests






# Instructions for CentOS 7

wget https://packages.chef.io/files/stable/chefdk/1.1.16/el/7/chefdk-1.1.16-1.el7.x86_64.rpm
yum install chefdk-1.1.16-1.el7.x86_64.rpm
yum install sqlite-devel gcc
yum install ImageMagick ImageMagick-devel

cd ghost_photo_upload
/opt/chefdk/embedded/bin/bundle install

# Install DropBox

https://www.digitalocean.com/community/tutorials/how-to-install-dropbox-client-as-a-service-on-centos-7

curl -Lo dropbox-linux-x86_64.tar.gz https://www.dropbox.com/download?plat=lnx.x86_64
sudo mkdir -p /opt/dropbox
sudo tar xzfv dropbox-linux-x86_64.tar.gz --strip 1 -C /opt/dropbox

### Update DropBox 

https://www.dropbox.com/install-linux

Run the following commands as aboutte user

cd ~ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -
~/.dropbox-dist/dropboxd



# TODO:
- add bash script to repo that can be used to pull down latest version of repo
- finish support for .mov files
- move hard coded configs into env variables
- move to using cron files
- run dropbox as a daemon

3 * * * * cd /home/aboutte/ghost_photo_upload/; /opt/chefdk/embedded/bin/bundle exec ghost_photo_upload.rb sync_posts_to_directories  >> /var/log/ghost_photo_upload.log 2>&1
*/5 * * * * cd /home/aboutte/ghost_photo_upload/; /opt/chefdk/embedded/bin/bundle exec ghost_photo_upload.rb sync_media_to_posts >> /var/log/ghost_photo_upload.log 2>&1
