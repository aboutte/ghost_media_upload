# Ghost Media Sync

## Summary

The ghost media sync script is used to push images and videos from mobile devices to a Ghost blog.

## Details

Images for the most part are pushed as is.  The only exception is that iPhone devices don't do a good job with the orientation of images.  ghost media sync will correct the orientation automatically. 

## Usage



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
