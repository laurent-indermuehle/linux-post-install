#!/bin/bash
CURRENTDIR="$(dirname "$(readlink -f "$0")")"

source "$CURRENTDIR"/config.sh
# Todo controle si le fichier existe

readonly HOSTNAMEFULL="$COMPUTERNAME"."$HOSTNAME"
 
# http://linuxcommand.org/wss0150.php
function error_exit
{
    echo "$1" 1>&2
    exit 1
} 
 
# http://unix.stackexchange.com/questions/70859/why-doesnt-sudo-su-in-a-shell-script-run-the-rest-of-the-script-as-root 
if [ "$(whoami)" = root ]; then

    mkdir -p /root/.ssh
    if [ ! -e /root/.ssh/authorized_keys ]; then
       echo "$AUTHORIZEDKEYS" > /root/.ssh/authorized_keys
    else
       echo "$AUTHORIZEDKEYS" >> /root/.ssh/authorized_keys
    fi
    chmod 600 /root/.ssh/authorized_keys
    sed -i 's/RSAAuthentication no/RSAAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
    sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
    # sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
    systemctl restart sshd
 
    # Firewalld
    yum -y install firewalld
    systemctl enable firewalld
    systemctl start firewalld
    # 2018-09-29 Laurent Indermühle: Why do you want to add ssh to drop zone ? without source or interface, I don't see the point
    # firewall-cmd --permanent --zone=drop --add-service=ssh
    # firewall-cmd --set-default-zone=drop
    # Allow OVH to monitor the server
    firewall-cmd --zone=public --permanent --add-interface=eth0  # this will activate zone public for main network link and thus allow ICMP (ping)
    firewall-cmd --zone=public --permanent --add-port=6100-6200/udp
    firewall-cmd --reload

    # Hostname
    hostnamectl set-hostname "$COMPUTERNAME" --pretty
    hostnamectl set-hostname "$HOSTNAME" --static

    # Yum-cron
    yum -y install yum-cron sendmail
    # https://askubuntu.com/questions/76808/how-do-i-use-variables-in-a-sed-command
    sed -i "s/system_name = None/system_name = $HOSTNAMEFULL/g" /etc/yum/yum-cron.conf
    sed -i 's/emit_via = stdio/emit_via = email/g' /etc/yum/yum-cron.conf
    sed -i "s/email_from = root@localhost/email_from = root@$HOSTNAMEFULL/g" /etc/yum/yum-cron.conf
    sed -i "s/email_to = root/email_to = $USEREMAIL/g" /etc/yum/yum-cron.conf
    # Remember, on CentOs you can only use updade_cmd = default
    # apply_updates = no it means you have to login an apply updates
    systemctl start yum-cron.service
    systemctl enable yum-cron.service
    systemctl start sendmail.service
    systemctl enable sendmail.service

    # Install base packages
    # ---------------------------------------------------------------------------
    # epel-release : Extra Packages for Enterprise Linux repository configuration.
    # make         : A GNU tool for controlling the generation of executables.
    # gcc          : Various compilers (C, C++, Objective-C, Java, ...).
    # git          : Git is a fast, scalable, distributed revision control system.
    # git-daemon   : The git dæmon for supporting git:// access to git repositories.
    # p7zip        : p7zip is a port of 7za.exe for Unix.
    yum -y install epel-release make gcc git git-daemon p7zip
    # nmap         : I don't remember why I installed this package -> Desactivated.

    # Install personnal preferences packages
    # ---------------------------------------------------------------------------
    # vim-enhanced : includes recently added enhancements like interpreters for the Python and Perl.
    # tmux         : tmux is a "terminal multiplexer."
    # links        : Links is a web browser capable of running in either graphics or text mode.
    # mlocate      : A locate/updatedb implementation. Keeps a database of all files and allows you to lookup files by name.
    yum -y install vim-enhanced tmux links mlocate
    
    # Rmate
    # todo

    # Netdata
    # todo

    # Docker
    #yum -y install docker docker-registry
    # make the Docker registry listen only on localhost
    #sed -i 's/REGISTRY_ADDRESS=0\.0\.0\.0/REGISTRY_ADDRESS=127.0.0.1/g' /etc/sysconfig/docker-registry

    # Httpd (Apache)
    # todo

    # MariaDB
    # todo

    ## Installing Go
    #cd /usr/local
    #wget https://storage.googleapis.com/golang/go1.4.linux-amd64.tar.gz
    #tar -zxvf go1.4.linux-amd64.tar.gz
    #cd /root
    
    # Creating and configuring $USERNAME user
    useradd -m "$USERNAME"
    gpasswd -a "$USERNAME" wheel
    mkdir -p /home/"$USERNAME"/.ssh
    cp /root/.ssh/authorized_keys /home/"$USERNAME"/.ssh/authorized_keys
    chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh
    chmod 500 /home/"$USERNAME"/.ssh
    chmod 400 /home/"$USERNAME"/.ssh/authorized_keys

    # Add Docker right for USERNAME
    # https://www.projectatomic.io/blog/2015/08/why-we-dont-let-non-root-users-run-docker-in-centos-fedora-or-rhel/
    # TODO
    # something like echo username(add constant here) ALL=(ALL) /usr/bin/docker >> /etc/sudoers
 
    cp -r /root/linux-post-install /home/"$USERNAME"/
    cd /home/"$USERNAME"/linux-post-install/
    chown "$USERNAME":"$USERNAME" centos7-postinstall.sh
    chmod u+x centos7-postinstall.sh
    su - -c /home/"$USERNAME"/linux-post-install/centos7-postinstall.sh "$USERNAME"
    rm -rf /home/"$USERNAME"/linux-post-install/
    
    # Haskdev can shut the machine down
    # http://www.garron.me/en/linux/visudo-command-sudoers-file-sudo-default-editor.html
    #echo "$USERNAME ALL= NOPASSWD: /sbin/shutdown -h now, /usr/bin/lastb" >> /etc/sudoers
 
    # Starting Docker
    # service docker start
    # service docker-registry start
 
elif [ "$(whoami)" = "$USERNAME" ]; then
 
    # Configuring git
    git config --global user.name "$USERNAME"
    git config --global user.email "$USEREMAIL"
    git config --global push.default simple
 
    # Configuring vim
    #curl -L -O https://raw.githubusercontent.com/danidiaz/miscellany/master/linux/.vimrc
     
    #mkdir -p ~/.vim/autoload ~/.vim/bundle && \
    #curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
     
    #cd .vim/bundle
    #git clone https://github.com/Shougo/unite.vim.git
    #git clone https://github.com/tpope/vim-repeat
    #git clone https://github.com/tpope/vim-surround.git
    #git clone https://github.com/tommcdo/vim-exchange.git
    #git clone https://github.com/justinmk/vim-sneak.git
    #git clone https://github.com/sirver/ultisnips
    #git clone https://github.com/dag/vim2hs
    #git clone https://github.com/fatih/vim-go
    #git clone https://github.com/michaeljsmith/vim-indent-object
    #cd "$HOME"
    #
    #mkdir .vim/colors
    #cd .vim/colors
    #curl -L -O https://raw.githubusercontent.com/fugalh/desert.vim/master/desert.vim
    #cd "$HOME"
 
    # Configuring tmux
    # Note that prefix is set to C-j
    curl -L -O "$TMUXCONFURL"
    mv tmux.conf .tmux.conf
     
    # Necessary for tmux to work
    # echo export LD_LIBRARY_PATH=/usr/local/lib >> "$HOME"/.bash_profile
 
    # Settign go path
    #echo "PATH=\$PATH:/usr/local/go/bin" >> .bash_profile
    #
    #mkdir go
    #mkdir go/src
    #mkdir go/pkg
    #mkdir go/bin
    #
    #echo "GOPATH=\$PATH:\$HOME/go" >> .bash_profile
    #echo "export GOPATH" >> .bash_profile
    #echo "PATH=\$PATH:\$HOME/go/bin" >> .bash_profile
 
else
 
    echo "Should not be here!!!"
 
fi