#!/bin/bash

##############################################################################
# READ ME FIRST 
  : ' 
  # Fix IP address, dns and disable ipv6 on Debian server
  
  ## set static ip address
  /etc/network/interfaces
  iface eth0 inet static
   address 192.168.x.x
   netmask 255.255.255.0
   gateway 192.168.x.x

  #dns-nameservers 192.168.x.x
  ## set dns
  /etc/resolv.conf
  nameserver 8.8.8.8
  ## disable ipv6 on 
  /etc/sysctl.conf
  net.ipv6.conf.all.disable_ipv6 = 1
  or 
  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
  '
##############################################################################

##############################################################################
# Base functions

setup_color() {
  RESET_COLOR=$(printf '\033[0m')
  ERROR_COLOR=$(printf '\033[1;31m')
  WARNING_COLOR=$(printf '\033[1;33m')
  INFO_COLOR=$(printf '\033[1;36m')
}

clear_screen(){
  printf "\033c"
  printf "${INFO_COLOR}"
}

print_line(){
  printf "%.s- " {1..35}
  printf "\n"
}

print_header(){ 
  print_line
  printf "$1 \n"
  print_line
}

error_handler() {
  # Save the command exit status
  exit_status=$?
  
  # Check if the command failed (exit status is non-zero)
  if [[ $exit_status -ne 0 ]]; then
    
    # Log the error message to the logfile
    printf "${ERROR_COLOR}Error: command failed with exit status $exit_status ${RESET_COLOR}" >> stderr.log
    
    read -n1 -r -p "Press any key to exit..."
    clear_screen
    exit $exit_status
  fi
}

exists()
{
  hash "$1" 2>/dev/null
}

##############################################################################
# Core 

# **************************************** #
# System
setup_timezone(){
  sudo su -c "
      timedatectl set-timezone 'Asia/Bangkok' && \
      timedatectl set-ntp true
      "
}

switch_to_zsh(){
  clear_screen
  print_header "Change default shell from $SHELL to $(which zsh)"
  chsh -s $(which zsh)
}

update_system() {
  clear_screen
  print_header "System update"
  
  sudo su -c "apt update -qq && apt upgrade -qq -y && apt autoclean -qq -y" 
  
  cleanup_cache
  #read -n1 -p "Press any key to continue: "
}

cleanup_cache() {
  print_header "Cleanup"
  rm --force ~/.*_history && \
  rm --force ~/.zcompdump* && \
  rm -rf ~/.cache/* && \
  
  printf "Cleanup cache and unused files successfully!\n"

}

smoke_test() {
  clear_screen
  printf "$(git --version)\n\n"
  
  printf "node version $(node --version)\n"
  printf "npm version $(npm --version)\n"
  printf "yarn version $(yarn --version)\n\n"
  
  printf "$(python --version)\n"
  printf "$(pip --version)\n\n"
  
  printf "$(poetry --version)\n\n"

  printf "$(mariadb --version)\n"
  printf "$(mariadbd --version)\n\n"
  
  printf "$(redis-cli --version)\n"
  printf "$(redis-server --version)\n\n"
  
  read -n1 -p "Press any key to continue: "
}

# **************************************** #

# **************************************** #
# oh-my-posh
setup_terminal() {
  clear_screen
  print_header "Install Oh My Posh over zsh"

  install_upgrade_ohmyposh
  
  mkdir -p ~/.oh-my-posh && \
  wget https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/paradox.omp.json -O ~/.oh-my-posh/default.omp.json
  
  printf '\neval "$(oh-my-posh init zsh --config ~/.oh-my-posh/default.omp.json)"' | sudo tee -a ~/.zshrc > /dev/null
}

install_upgrade_ohmyposh() {
  # oh-my-posh

  sudo su -c "wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh"
  sudo su -c "chmod +x /usr/local/bin/oh-my-posh"
}

change_theme() {
  
  clear_screen
  print_header "Change Oh My Posh theme"
  
  read -p "Please enter theme name: " omp_theme
  wget https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$omp_theme.omp.json -O ~/.oh-my-posh/default.omp.json
}

# **************************************** #
# Update Linux System
install_library(){
  clear_screen
  print_header "Install Library"
      
  sudo su -c "apt update -qq && \
      apt upgrade -qq -y && \ 
      apt install --no-install-recommends -qq -y \
        build-essential software-properties-common ca-certificates \
        curl wget llvm make openssl sudo unzip zsh \
        libffi-dev libnss3 libnspr4 tk-dev xvfb \
        libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev && \
      apt autoclean -qq -y"
      
  printf 'unset HISTFILE\n' | tee -a ~/.zshrc > /dev/null
  printf '\nexport PATH=~/.local/bin:/usr/local/bin:$PATH\n' | tee -a ~/.zshrc > /dev/null
}

# **************************************** #
# Install git, nvm, python, mariadb, redis
install_git() {
  clear_screen
  print_header "Install Git ${GIT_VERSION}" 
  if ! exists git; then
    sudo su -c "curl -fsSL https://github.com/git/git/archive/refs/tags/v$GIT_VERSION.zip -o git.zip && \
          unzip git.zip && \
          cd git-$GIT_VERSION && \
          make clean && \
          make prefix=/usr/local all && \
          make prefix=/usr/local install"

    sudo rm git.zip && \
    sudo rm -rf git-$GIT_VERSION

    # smoke test
    git --version     
  fi
}

install_nvm() {
  clear_screen
  print_header "Install nvm"
  if ! [ -d "${HOME}/.nvm" ]; then
    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash  
    
    print_header "Install node $NODE_VERSION"

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion  

    nvm install $NODE_VERSION && \
    nvm install-latest-npm && \
    npm install -g yarn

    # smoke test
    node --version
    npm --version
    yarn --version
    
    printf '\nexport NVM_DIR="$HOME/.nvm"\n' | tee -a ~/.zshrc > /dev/null
    printf '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm\n' | tee -a ~/.zshrc > /dev/null
    printf '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion\n' | tee -a ~/.zshrc > /dev/null
    
  fi
}

install_python() {
  clear_screen
  print_header "Install python $PYTHON_VERSION"
  
  sudo su -c "apt update -qq && \
      apt upgrade -qq -y && \ 
      apt install --no-install-recommends -qq -y \
        libbz2-dev libncurses-dev libncursesw5-dev libgdbm-dev \
        liblzma-dev libsqlite3-dev libgdbm-compat-dev libreadline-dev && \
      apt autoclean -qq -y"
      
  if ! exists python; then
    curl "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" -o python.tar.xz && \
    sudo su -c "mkdir -p /usr/src/python && \
          tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz && \
          rm -f python.tar.xz"

    cd /usr/src/python
    sudo su -c "./configure \
          --enable-optimizations \
          # --enable-option-checking=fatal \
          --enable-shared \
          # --without-ensurepip"

    sudo su -c "make clean && \
          make -j '$(nproc)' && \
          make install && \
          rm -rf /usr/src/python"

    find /usr/local -type d | grep -E "('test'|'tests'|'idle_test')" | xargs sudo rm -rf
    find /usr/local -type f | grep -E "('*.pyc'|'*.pyo'|'*.a')" | xargs sudo rm -f

    # create symlink
    cd /usr/local/bin
    sudo su -c "ln -s idle3 idle \
          && sudo ln -s pydoc3 pydoc \
          && sudo ln -s python3 python \
          && sudo ln -s python3-config python-config"

    # smoke test
    python --version
  fi
}

upgrade_pip() {
  print_header "Upgrade pip"

  python -m pip install --upgrade pip
  python -m pip install --upgrade setuptools
  
  cd /usr/local/bin
  sudo su -c "ln -s pip3 pip"

  # smoke test
  pip --version 
}

install_poetry() {
  print_header "Install poetry"
  
  if ! exists poetry; then
    sudo pip install poetry && \
    poetry config virtualenvs.in-project true

    # smoke test
    poetry --version
  fi
}

install_redis() {
  clear_screen
  print_header "Update System && Install Redis"
  
  if ! exists redis-server; then
    sudo su -c "apt update -qq && \
          apt upgrade -qq -y && \
          apt install --no-install-recommends -qq -y \
          redis-server && \
          apt autoclean -qq -y"
          
  fi
}

install_mariadb(){
  clear_screen
  print_header "Update System && Install MariaDB"

  sudo su -c "curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup && \
        bash mariadb_repo_setup --os-type=debian  --os-version=buster --mariadb-server-version=$MARIADB_VERSION && \
        rm -f mariadb_repo_setup"
  
  sudo su -c "wget http://ftp.us.debian.org/debian/pool/main/r/readline5/libreadline5_5.2+dfsg-3+b13_amd64.deb && \
        dpkg -i libreadline5_5.2+dfsg-3+b13_amd64.deb && \
        rm -f libreadline5_5.2+dfsg-3+b13_amd64.deb"
  
  if ! exists mariadb; then         
    sudo su -c "apt update -qq && \
          apt upgrade -qq -y && \   
          apt install --no-install-recommends -qq -y \
          mariadb-server mariadb-client && \
          apt autoclean -qq -y"

    # Config /etc/mysql/my.cnf
    sudo su -c 'echo "
    [mysqld]
    character-set-client-handshake = FALSE
    character-set-server = utf8mb4
    collation-server = utf8mb4_unicode_ci

    [mysql]
    default-character-set = utf8mb4
    " >> /etc/mysql/my.cnf'
    
    config_mariadb
  fi  
}

config_mariadb(){
  print_header "Config MariaDB"

  sudo service mariadb start  && \
  sudo mysql_secure_installation && \
  sudo service mariadb restart
}

install_git_nvm_python() {

  if [ ! -v GIT_VERSION ]; then
    echo "Error: GIT_VERSION is not defined." 2>> stderr.log
    exit 1
  fi
  
  install_git && install_nvm && \
  install_python && upgrade_pip && install_poetry
}

install_redis_mariadb() {
  if [ ! -v MARIADB_VERSION ]; then
    echo "Error: MARIADB_VERSION is not defined." 2>> stderr.log
    exit 1
  fi
  install_redis && install_mariadb
}
##############################################################################

##############################################################################
# Frappe

# ******************** #frappe# ******************** #
confirm_site(){     
  while true;
  do
    read -p "Please type '$SITE' to confirm: " site_name
    
    if [ "$site_name" != "$SITE" ]; then
      printf "${ERROR_COLOR}";      
      read -p "You want to change site from $SITE to $site_name? [Y/N]: " confirm_to_change_site
      if [ $confirm_to_change_site = "Y" ] || [ $confirm_to_change_site = "y" ]; then
        SITE="$site_name";
        break;
      fi
    else
      # if [ $site_name == $SITE ]; then break; fi
      break;
    fi
  done  
}

install_bench(){
  clear_screen
  print_header "Install frappe-bench" 
  if ! exists bench; then
    # frappe needed library       
    sudo su -c "apt install --no-install-recommends -qq -y\
          xvfb libfontconfig wkhtmltopdf npm supervisor"
          
    # playwright library
    sudo su -c "apt install --no-install-recommends -qq -y\
          libatk1.0-0 libatk-bridge2.0-0 libcups2 libxkbcommon0 libxcomposite1 \
          libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2 libatspi2.0-0"
    
    sudo su -c "apt autoclean -qq -y"
    
    sudo pip install frappe-bench==$BENCH_VERSION
    
    # smoke test
    bench --version
  fi
}

create_env(){
  clear_screen
  print_header "Create frappe Environment >> $SITE"
  
  if [[ -v "$REPO_URL" || -v "$APP_DIR" || -v "$SITE" ]]; then
    echo "Error: REPO_URL or APP_DIR or SITE is not defined." 2>> stderr.log
    exit 1  
  fi
  
  while true;
  do    
    read -p "Site: " -e -i "$SITE" SITE;
    if [ -n "$SITE" ]; then break; fi
  done
  
  while true;
  do    
    read -p "Frappe version: " -e -i "$FRAPPE_VERSION" FRAPPE_VERSION;
    if [ -n "$FRAPPE_VERSION" ]; then break; fi
  done  
  
  while true;
  do  
    if [ -n "$ROOT_PASSWORD" ]; then break; fi
    read -p "MariaDB root password: " ROOT_PASSWORD;    
  done
  
  while true;
  do  
    if [ -n "$ADMIN_PASSWORD" ]; then break; fi
    read -p "Default user password: " ADMIN_PASSWORD;   
  done
  
  confirm_site $SITE && \
  bench init --frappe-branch $FRAPPE_VERSION --frappe-path $REPO_URL/frappe $APP_DIR/$SITE && \
  cd $APP_DIR/$SITE && \
  chmod -R o+rx $HOME && \
  bench find . && \
  
  print_header "Setup New Site >> $SITE" && \
  bench new-site $SITE --mariadb-root-password $ROOT_PASSWORD --admin-password $ADMIN_PASSWORD --db-name $SITE && \
  bench use $SITE && \
  bench set-config developer_mode 1
}

install_app(){
  clear_screen
  print_header "Install app >> $SITE"

  while true;
  do    
    read -p "Site: " -e -i "$SITE" SITE;
    if [ -n "$SITE" ]; then break; fi
  done
  
  while true;
  do 
    read -p "App name: " APP; 
    if [ -n "$APP" ]; then break; fi    
  done      
      
  while true;
  do 
    read -p "Branch: " BRANCH;
    if [ -n "$BRANCH" ]; then break;  fi
  done
  
  printf "Install App $APP on branch $BRANCH\n"
    
  confirm_site $SITE && \
  cd $APP_DIR/$SITE && \
  bench get-app $APP $REPO_URL/$APP --branch $BRANCH && \
  bench --site $SITE install-app $APP 
}

install_erpnext() {
  clear_screen
  print_header "Install ERPNext >> $SITE"

  if [[ -v "$APP_DIR" || -v "$SITE" ]]; then
    echo "Error: APP_DIR or SITE is not defined." 2>> stderr.log
    exit 1  
  fi

  while true;
  do    
    read -p "Site: " -e -i "$SITE" SITE;
    if [ -n "$SITE" ]; then break; fi
  done
  
  while true;
  do
    read -p "ERPNext version: " -e -i "$ERPNEXT_VERSION" ERPNEXT_VERSION;
    if [ -n "$ERPNEXT_VERSION" ]; then break; fi
  done
  
  confirm_site $SITE && \
  cd $APP_DIR/$SITE && \
  bench get-app erpnext --branch $ERPNEXT_VERSION && \
  bench get-app payments && \
  bench --site $SITE install-app erpnext
}

install_frappe_app() {
  clear_screen
  print_header "Install frappe app >> $SITE"

  if [[ -v "$APP_DIR" || -v "$SITE" ]]; then
    echo "Error: APP_DIR or SITE is not defined." 2>> stderr.log
    exit 1  
  fi

  while true;
  do    
    read -p "Site: " -e -i "$SITE" SITE;
    if [ -n "$SITE" ]; then break; fi
  done
  
  while true;
  do
    read -p "App name: " -e -i "" APP_NAME;
    if [ -n "$APP_NAME" ]; then break; fi
  done
  
  # while true;
  # do
    # read -p "App version: " -e -i "version-14" APP_VERSION;
    # if [ -n "$APP_VERSION" ]; then break; fi
  # done
  
  confirm_site $SITE && \
  cd $APP_DIR/$SITE && \
  bench get-app $APP_NAME && \
  bench --site $SITE install-app $APP_NAME
}

create_demo_user(){
  clear_screen
  print_header "Create demo user >> $SITE"

  if [[ -v "$APP_DIR" || -v "$SITE" ]]; then
    echo "Error: APP_DIR or SITE is not defined." 2>> stderr.log
    exit 1  
  fi

  while true;
  do    
    read -p "Site: " -e -i "$SITE" SITE;
    if [ -n "$SITE" ]; then break; fi
  done
  
  confirm_site $SITE && \
  cd $APP_DIR/$SITE && \
  bench add-user 'barista@frappe.dev' --first-name Barista --password s3cr3t --add-role 'System Manager' && \
  bench add-user 'peter.haycox@frappe.dev' --first-name Peter --last-name Haycox --password s3cr3t --add-role 'Inbox User' && \
  bench add-user 'mike.stendell@frappe.dev' --first-name Mike --last-name Stendell --password s3cr3t --add-role 'Inbox User' && \
  bench add-user 'john.gullberg@frappe.dev' --first-name John --last-name Gullberg --password s3cr3t --add-role 'Inbox User' && \
  bench add-user 'kate.penright@frappe.dev' --first-name Kate --last-name Penright --password s3cr3t --add-role 'Inbox User' && \
  bench add-user 'jane.halson@frappe.dev' --first-name Jane --last-name Halson --password s3cr3t --add-role 'Inbox User' && \
  bench add-user 'sarah.caffrey@frappe.dev' --first-name Sarah --last-name Caffrey --password s3cr3t --add-role 'Inbox User'
}

enable_production_mode(){
  clear_screen
  print_header "Enable production >> $SITE"

  if [[ -v "$APP_DIR" || -v "$SITE" ]]; then
    echo "Error: APP_DIR or SITE is not defined." 2>> stderr.log
    exit 1  
  fi
  
  printf "${WARNING_COLOR}WARNING: This task will enable production mode for $SITE\n"
  
  confirm_site $SITE && \
  cd $APP_DIR/$SITE
  bench --site $SITE set-config developer_mode 0 && \
  bench --site $SITE add-to-hosts && \
  bench --site $SITE enable-scheduler && \
  bench --site $SITE set-maintenance-mode off && \
  sudo su -c "bench setup production $(whoami)" && \
  bench setup nginx && \
  bench setup supervisor && \
  sudo supervisorctl restart all && \
  sudo su -c "bench setup production $(whoami)"
}

# ******************** #frappe# ******************** #


load_frappe_menu() {
  while true;
  do
    clear_screen  
    print_header "Setup Frappe Environment"

    printf "1) Install Bench (frappe-bench) \n" 
    printf "2) Create frappe environment \n"
    printf "3) Get && Install app to site \n"
    printf "4) Get && Install ERPNext to site \n"
    printf "5) Get && Install Frappe App to site \n"
    printf "6) Enable production \n"
    printf "7) Create demo user \n"     
    printf "L) List frappe instances \n"
    printf "T) Library test \n"
    printf "M) Return to main menu \n"
    printf "Q) Quit \n"
    print_line
    
    read -p "Choose an option: " option
    
    trap error_handler ERR
    clear_screen
    
    case $option in
      1)
        install_bench       
        ;;
      2)    
        create_env
        ;;
      3)
        install_app
        ;;
      4)
        install_erpnext
        ;;
      5)
        install_frappe_app
        ;;
      6)
        enable_production_mode
        ;;                
      7)
        create_demo_user
        ;;        
      t|T)
        smoke_test
        ;;
      l|L)
        bench find
        read -n1 -r -p "Press any key to continue..."
        ;;
      u|U)
        update_system
        ;;
      m|M)
        load_main_menu
        ;;
        
      q|Q) 
        exit
        ;;  
      *)
        printf "${ERROR_COLOR}\nInvalid option\n${INFO_COLOR}"
        ;;
    esac
  done
}

##############################################################################

##############################################################################
# Setup on WSL

before_setup_wsl() {
  clear_screen
  print_header "Update && Config WSL"
  
  if [ -z "$host" ] || [ -z "$(whoami)" ]; then
    print_header "Please specify host name && default user"   
    read -p "Host name: " host
    read -p "User: " -e -i $(whoami) user
  fi
  
  printf '[network]\n\thostname=%s\n[user]\n\tdefault=%s\n' "${host}" "${user}" | sudo tee /etc/wsl.conf > /dev/null
}

setup_wsl() {
  before_setup_wsl && install_library && \
  install_git_nvm_python && 
  install_redis_mariadb && \
  # setup_terminal && switch_to_zsh && \
  after_setup_wsl
}

after_setup_wsl() {
  # Auto start MariaDB && Redis
  printf '[boot]\n\tcommand=sudo service mariadb start; sudo service redis-server start;' | sudo tee -a /etc/wsl.conf > /dev/null
  
  cleanup_cache
}
##############################################################################

##############################################################################
# Setup on Debian server

before_setup_debian() {
  clear_screen
  print_header "Task start ...."

}

setup_debian(){
  before_setup_debian && install_library && \
  install_git_nvm_python && \
  install_redis_mariadb && \
  # setup_terminal && switch_to_zsh && \
  after_setup_debian 
}

after_setup_debian(){
  cleanup_cache
}
##############################################################################

##############################################################################
# Setup on xfce desktop

before_setup_desktop() {
  clear_screen
  print_header "Setup desktop environment ...."

}

setup_desktop(){
  before_setup_desktop && \
  sudo su -c "apt-get update && \
              apt-get upgrade -y && \
              apt-get install task-xfce-desktop dbus-x11 xrdp -y && \
              service xrdp restart" && \
  sudo su -c "sudo apt-get install wget gpg && \
              wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
              install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && \
              echo 'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' > /etc/apt/sources.list.d/vscode.list && \
              rm -f packages.microsoft.gpg && \
              apt install apt-transport-https && \
              apt update && \
              apt install code chromium -y" && \
  after_setup_desktop 
}

after_setup_desktop(){
  cleanup_cache
}
##############################################################################


##############################################################################
# MAIN

load_main_menu() {
  while true;
  do
    clear_screen
    print_header "Welcome to frappe setup script"
    
    printf "1) Debian Server \n"    
    printf "2) Windows (WSL) \n"
    printf "3) Desktop Environment \n"
    printf "4) Setup Frappe \n" 
    printf "5) Setup Timezone to 'Asia/Bangkok' \n"
    printf "6) Setup Terminal to 'oh-my-posh && zsh' \n"
    
    printf "Q) Quit \n"
    print_line
    
    read -p "Choose an option: " option

    trap error_handler ERR
    clear_screen
    
    case $option in
      1)
        setup_debian
        ;;
      2)
        setup_wsl
        ;;
      3)
        setup_desktop
        ;;
      4)
        load_frappe_menu
        ;;
      5)
        setup_timezone
        ;;
      6)
        setup_terminal && switch_to_zsh
        ;;
      q|Q) 
        exit
        ;;  
      *)
        printf "\n${ERROR_COLOR}Invalid option\n${INFO_COLOR}"
        ;;
    esac
  
  done  
}
# ******************** #Main menu# ******************** #

main(){   
  PATH=~/.local/bin:/usr/local/bin:$PATH
  
  RUNNING_DIR=$(dirname -- $0)  
  
  #Read variables from frappe.env
  if [ -f $RUNNING_DIR/frappe.env ]; 
  then 
    . $RUNNING_DIR/frappe.env; 
  else
    set_variable
  fi
  
  if [ -z $X_USER ]; then
    while true;
    do
      read -p "User: " X_USER;
      if [ -n "$X_USER" ]; then break; fi
    done;
  fi

  if [ -z $X_TOKEN ]; then
    while true;
    do
      read -p "Token: " X_TOKEN;
      if [ -n "$X_TOKEN" ]; then break; fi
    done;
  fi

  if [ -z $X_REPO ]; then
    while true;
    do
      read -p "URL: " X_REPO;
      if [ -n "$X_REPO" ]; then break; fi
    done;
  fi
  
  REPO_URL="https://$X_USER:$X_TOKEN@$X_REPO"

  if [ $SHELL | grep bash ]; then source ~/.bashrc; fi
  if [ $SHELL | grep zsh ]; then source ~/.zshrc; fi
  
  setup_color
  clear_screen  
  load_main_menu
}

set_variable() {
  GIT_VERSION=2.39.0
  PYTHON_VERSION=3.11.0
  NODE_VERSION=v18.12.0
  
  MARIADB_VERSION=10.6
  
  BENCH_VERSION=5.16
  FRAPPE_VERSION=version-14
  ERPNEXT_VERSION=version-14
    
  APP_DIR="$HOME/opt"
  SITE="frappe.local"

  ROOT_PASSWORD=
  ADMIN_PASSWORD=
  
  X_USER=
  X_TOKEN=
  X_REPO=
}

main "$@"
set -u

##############################################################################