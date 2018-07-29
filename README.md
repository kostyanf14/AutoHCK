# auto_hck

[![CircleCI](https://circleci.com/gh/20lives/auto_hck.svg?style=svg)](https://circleci.com/gh/20lives/auto_hck)

auto_hck is a tool for automating HCK/HLK testing, doing all the boilerplate steps in the process leaving you with simply choosing which driver you want to test on what os.

## Getting Started

There are not so few steps needed to install and set up auto_hck, First of all clone auto_hck and follow the instruction below:

### QEMU
Use your package manager to install QEMU or build it from [source](https://github.com/qemu/qemu)

### VirtHCK
Clone [VirtHCK](https://github.com/daynix/VirtHCK), auto_hck will use it as a dependency.

### toolsHCK
Get a copy of the powershel script file in [rtoolsHCK](https://github.com/daynix/toolsHCK)

### rtoolsHCK
Get a clone of [rtoolsHCK](https://github.com/daynix/rtoolsHCK), execute the follwing to build and install as a gem:
```
rake build
rake install
```

### RubyGems
Install the following gems using bundler with `bundler install` or `gem install gemname`:
* [dropbox_api](https://rubygems.org/gems/dropbox_api)
* [faraday](https://rubygems.org/gems/faraday) (version 0.12.2)
* [net-ping](https://rubygems.org/gems/net-ping)
* [filelock](https://rubygems.org/gems/filelock)
* [octokit](https://rubygems.org/gems/octokit)

### DHCP SERVER
Use a dhcp server tool like [OpenDHCP](http://dhcpserver.sourceforge.net) or [Node-DHCP](https://github.com/infusion/node-dhcp) to assign static ip to mac-address with the following rule:
```
56:00:XX:00:XX:dd > 192.168.0.XX
```

### Sudoer with no passwod
To run auto_hck correctly the runnig user should have permission to run sudo commands without prompting his password, do this by adding the following line to sudoers file /etc/sudoers
__This might be dangerous to your computer security, do this at your own risk__
```
hck-ci ALL=(ALL) NOPASSWD:ALL
```

### Images preperation
This is similar to making regular HLK/HCK studio and clients images with with few additionals configurations, detailed instrutions available at [HLK-Setup-Scripts](https://github.com/daynix/HLK-Setup-Scripts)

### Configuration
There are 3 diffrenet JSON files for configurations, examples included in the files:
* `config.json` is the general configuration file which holds the paths to the dependencies stated above.
* `platforms.json` list of configured opertaions systems images.
* `devices.json` list of devices drivers information for testing

## Usage

Once everything is installed and configured, run `ruby auto_hck.rb` with these parameters:
```
Required:
-t, --tag [PROJECT]-[OS][ARCH]   The driver name and architecture
-p, --path [PATH-TO-DRIVER]      The location of the driver
Optional:
-d, --diff <DIFF-LIST-FILE>      The location of the driver
-c, --commit <COMMIT-HASH>       Commit hash for updating github status
```
### Examples
```
ruby autoHCK.rb -t Balloon-Win10x86 -p /home/hck-ci/balloon/win10/x86
ruby autoHCK.rb -t NetKVM-Win10x64 -d /home/hck-ci/workspace -d diff_list_file.txt
ruby autoHCK.rb -t viostor-Win10x64 -d /home/hck-ci/viostor -d diff_list_file.txt -c ec3da560827922e5a82486cf19cd9c27e95455a9
```

## Author

* **Lior Haim** - *Development* - [Daynix Computing LTD](https://github.com/Daynix)

