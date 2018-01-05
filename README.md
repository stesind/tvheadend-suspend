# tvheadend-suspend
Files and scrips for tvheadend suspend and wakeup

## What it does
- Creates Systemd service files for user suspend and resume actions
- Checks if there is a recording happen, planned or clients are connected to tvheadend
- Sets an rtcwake for scheduled recordings
- Loading and unloading DVB hardware kernel modules

## Attention
This files cannot be taken as is, because I (un)load the required DVB kernel modules. This modules may change depening on the DVB hardware one is using. 
Also I store the scrips into my personal folder for easier backup. If you do so as well you need to change the path according to our home directory.

## Install

- Install the service files in /etc/systemd/system
- Install the scrips in the desirec directory
- Change DVB module names and paths according your needs
- Enable the service files

```shell
git clone https://github.com/stesind/tvheadend-suspend.git
cd tvheadend-suspend
install -m 644 -o root -g root root-suspend.service /etc/systemd/system
install -m 644 -o root -g root root-resume.service /etc/systemd/system
install -m 644 -o root -g root tvheadend-check-recordings.service /etc/systemd/system
install -m 644 -o root -g root tvheadend-suspend.service /etc/systemd/system
install -d $HOME/bin
install -m 644 -o $USER -g $USER tvheadend-check-recordings.sh $HOME/bin

systemctl daemon-reload
systemctl enable --now root-suspend.service
systemctl enable --now root-resume.service
systemctl enable --now tvheadend-check-recordings.service
systemctl enable --now tvheadend-suspend.service

```
