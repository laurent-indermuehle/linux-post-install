#!/usr/bin/env bash
readonly CURRENTDIR="$(dirname "$(readlink -f "$0")")"

source "${CURRENTDIR}"/config.sh
# Todo controle si le fichier existe

readonly HOSTNAMEFULL="$COMPUTERNAME"."$HOSTNAME"

# http://unix.stackexchange.com/questions/70859/why-doesnt-sudo-su-in-a-shell-script-run-the-rest-of-the-script-as-root 
if [[ "$(whoami)" = root ]]; then

  mkdir -p /root/.ssh
  if [[ ! -e /root/.ssh/authorized_keys ]]; then
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

  # Add /usr/local/bin to root PATH after a sudo -i
  chmod u+w /etc/sudoers
  sed -i 's/Defaults    secure_path = \/sbin:\/bin:\/usr\/sbin:\/usr\/bin/Defaults    secure_path = \/sbin:\/bin:\/usr\/sbin:\/usr\/bin:\/usr\/local\/bin/g' /etc/sudoers
  chmod u-w /etc/sudoers

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

  # Timezone
  timedatectl set-timezone "$TIMEZONE"

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

  # -------------------------------------------------------------------------
  #                           Install base packages
  # -------------------------------------------------------------------------
  # epel-release : Extra Packages for Enterprise Linux repository config.
  # make         : A GNU tool for controlling the generation of executables.
  # gcc          : Various compilers (C, C++, Objective-C, Java, ...).
  # git          : A fast, scalable, distributed revision control system.
  # git-daemon   : For supporting git:// access to git repositories.
  # p7zip        : p7zip is a port of 7za.exe for Unix.
  # wget         : The non-interactive network downloader.
  yum -y install epel-release make gcc git git-daemon p7zip wget
  # nmap         : I don't remember why I installed this package -> OFF.

  # -------------------------------------------------------------------------
  #                 Creating and configuring your admin user
  # -------------------------------------------------------------------------
  useradd -m "$USERNAME"

  # Add sudo (admin) rights
  gpasswd -a "$USERNAME" wheel

  # SSH
  mkdir -p /home/"$USERNAME"/.ssh
  cp /root/.ssh/authorized_keys /home/"$USERNAME"/.ssh/authorized_keys
  chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh
  chmod 500 /home/"$USERNAME"/.ssh
  chmod 400 /home/"$USERNAME"/.ssh/authorized_keys


  # -------------------------------------------------------------------------
  #                  Install personnal preferences packages
  # -------------------------------------------------------------------------
  # vim-enhanced : includes enhancements like interpreters for Python, Perl..
  # tmux         : tmux is a "terminal multiplexer."
  # links        : A web browser capable of running in graphics or text mode.
  # mlocate      : A locate/updatedb implementation. Keeps a database of all 
  #                files and allows you to lookup files by name.
  # zsh          : Resembles ksh but with many enhancements
  # cryptsetup   : To encrypt partitions
  yum -y install vim-enhanced tmux links mlocate zsh cryptsetup ncdu

  # Tmux doesn't work unless you're in tty group
  gpasswd -a "$USERNAME" tty
  # Change shell
  chsh "$USERNAME" -s /bin/zsh
  
  # -------------------------------------------------------------------------
  #                                   Rmate
  # -------------------------------------------------------------------------
  # This app let you edit files on a remote computer. I use it with this
  # SublimeText 3 package: https://packagecontrol.io/packages/RemoteSubl
  wget -O /usr/local/bin/rmate \
  https://raw.githubusercontent.com/aurora/rmate/master/rmate
  chmod a+x /usr/local/bin/rmate
  
  # -------------------------------------------------------------------------
  #                                  Docker
  # -------------------------------------------------------------------------
  # Using this guide: https://docs.docker.com/install/linux/docker-ce/centos
  yum install -y yum-utils device-mapper-persistent-data lvm2
  yum-config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce
  systemctl enable docker

  # Add Docker right for USERNAME
  # https://www.projectatomic.io/blog/2015/08/why-we-dont-let-non-root-users-run-docker-in-centos-fedora-or-rhel/
  # But this script is for personal server, so we trust ourself...
  gpasswd -a "$USERNAME" docker

  # -------------------------------------------------------------------------
  #             Prepare script to continue loged as your new user
  # -------------------------------------------------------------------------
  cp -r /root/linux-post-install /home/"$USERNAME"/ || exit 1
  cd /home/"$USERNAME"/linux-post-install/ || exit 1
  chown "$USERNAME":"$USERNAME" centos7-postinstall.sh
  chmod u+x centos7-postinstall.sh
  su - -c /home/"$USERNAME"/linux-post-install/centos7-postinstall.sh "$USERNAME"
  rm -rf /home/"$USERNAME"/linux-post-install/

elif [[ "$(whoami)" = "$USERNAME" ]]; then

  # -------------------------------------------------------------------------
  #                              Configuring GIT
  # -------------------------------------------------------------------------
  git config --global user.name "$USERNAME"
  git config --global user.email "$USEREMAIL"
  git config --global push.default simple

  # -------------------------------------------------------------------------
  #                              Configuring vim
  # -------------------------------------------------------------------------
  # Not tested yet
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

  # -------------------------------------------------------------------------
  #                             Configuring tmux
  # -------------------------------------------------------------------------
  # Note that prefix is set to C-j
  curl -L -O "$TMUXCONFURL"
  mv tmux.conf .tmux.conf
  # Neither in Putty or WinSSHTerm on Kitty, the binding works. I'm not sure
  # I want to continue using screen or tmux from Windows...

  # -------------------------------------------------------------------------
  #                                 Oh-My-ZSH
  # -------------------------------------------------------------------------
  # Prerequisite : zsh

  # Silent installation: https://github.com/robbyrussell/oh-my-zsh/issues/5873
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended
  # You may want to add your own ~/.zshrc for enabling plugins, ...
  # This script doesn't take car of that.

  # -------------------------------------------------------------------------
  #                                 Cheat.sh
  # -------------------------------------------------------------------------
  # TODO : Attention, we use ZSH !
  # mkdir -p ~/.bash.d/
  # curl https://cht.sh/:bash_completion > ~/.bash.d/cht.sh
  # echo 'source ~/.bash.d/cht.sh' >> ~/.bashrc
  # source ~/.bash.d/cht.sh

else

  echo "Should not be here!!!"

fi
