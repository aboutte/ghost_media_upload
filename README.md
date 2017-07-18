# Ghost Media Sync

## Summary

The ghost media sync script is used to push images and videos from mobile devices to a Ghost blog.

## Details

Images for the most part are pushed as is.  The only exception is that iPhone devices don't do a good job with the orientation of images.  ghost media sync will correct the orientation automatically. 

## Usage

- run the ./build.sh script
- deploy cloudformation stack with following command:

```
cd cloudformation/
bundle exec ./aws-lambda-ffmpeg.rb create --region us-west-2 --stack-name aws-lambda-ffmpeg-$(date '+%s') --disable-rollback 
```

During development the following command can be useful to update a Lambda function to use a new copy of zip:

```
aws --region us-west-2 lambda update-function-code --function-name $(aws lambda list-functions --query 'Functions[0].FunctionName' --output text) --s3-bucket aboutte-lambda --s3-key aws-lambda-ffmpeg.zip --publish
```

### Prerequisites

### Install


## TODO: 

- [ ] update travis test case to include python syntax checker
- [x] get Travis CI hooked up
- [ ] setup some rake unit tests
- [x] flock the crons (flock -x /var/run/cron -c 'sleep 30')
- [x] add bash script to repo that can be used to pull down latest version of repo
- [ ] finish support for .mov files
- [ ] move hard coded configs into env variables
- [ ] move to using cron files
- [ ] run dropbox as a daemon
- [ ] add requirments.txt to lambda function






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
