#!/usr/bin/env bash

set -eu

# ************************************************************ #
# SYSTEM VARIABLES                                             #
# ************************************************************ #
RUNNING_DIR=$(dirname -- "${0}")
OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'=' -f2 | tr -d '"')

# ************************************************************ #
# GLOBAL VARIABLES                                             #
# ************************************************************ #
LOG=
SERVER_ROLE=
PROG=
FUNC=
PASSWD=

# ************************************************************ #
# USER VARIABLES                                               #
# ************************************************************ #
GIT_VERSION= #"2.43.0"
NODE_VERSION= #"20.11.0"
PYTHON_VERSION= #"3.12.0"
MARIADB_VERSION= #"10.11"

DB_TYPE= #[mariadb, postgres]
DB_HOST= #"localhost"
DB_ROOT_USERNAME= #"root"
DB_ROOT_PASSWORD= #"1234"

REPO_MODE="ssh" #[ssh]
REPO_URI= #"your.server.domain"
REPO_PORT= #"22"
REPO_SSH_KEY= #"$HOME/path/to/private.key"

BENCH_VERSION= #"5.22"
FRAPPE_VERSION= #"version-15"
INSTALL_DIR= #"$HOME/opt"

INSTANCE= #"frappe-15"
APP_LIST= #"erpnext=version-15 custom_app=branch_name"

SITE_NAME= #"frappe-15.local"
SITE_DB_NAME= #"frappe-15"
SITE_ADMIN_PASSWORD= #"1234"

# ************************************************************ #
# MISC.                                                        #
# ************************************************************ #
reset="\033[0m"
black="\033[30m"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
blue="\033[34m"
magenta="\033[35m"
cyan="\033[36m"
white="\033[37m"

clear_screen() {
  printf "\033c${LOG}${reset}\n"
}

print_header() {
    printf "%s\n%s\n%s\n" \
      $(printf -- "-%.0s" {1..60}) \
      "${1}" \
      $(printf -- "-%.0s" {1..60})
}

info() {
  printf "\n\u2139 ${white}${1}${reset}"
}

warning() {
  printf "\n${yellow}${1}${reset}"
}

error() {
  printf "\n\u274C ${red}${1}${reset}"
}

success() {
  printf "\n\u2714 ${green}${1}${reset}"
}

exist() {
  hash "${1}" 2>/dev/null
}

check_variables() {
  local err_msg=$(print_header "Check Variables")
  local fail=0
  local vars=("GIT_VERSION" "NODE_VERSION" "PYTHON_VERSION" "MARIADB_VERSION")
  vars+=("DB_TYPE" "DB_HOST" "DB_ROOT_USERNAME" "DB_ROOT_PASSWORD")
  vars+=("REPO_MODE" "REPO_URI" "REPO_SSH_KEY")
  vars+=("INSTANCE" "SITE_NAME" "SITE_DB_NAME" "SITE_ADMIN_PASSWORD")

  for v in "${vars[@]}"; do
    if [[ -z "${!v}" ]]; then
      err_msg+=$(error "Variable ${v} must be defined")
      printf "\033c${err_msg}\n"
      fail=1
    fi
  done
  
  if [ "${fail}" == 1 ]; then exit 1; fi
}

display_help() {
  clear_screen

  printf "Usage: install.sh [OPTIONS] \n\n"
  printf "Arguments:\n"
  printf "  -h   Display this help message.\n"
  printf "  -i   Install specific software (python, nvm, git).\n"
  printf "  -t   Setup type (dev, aio, app, db).\n"
  printf "  -x   Run specific function (update_system, install_lazygit, etc... ).\n\n"
  printf "Examples:\n"
  printf "  ./install.sh\n"  # Display help message
  printf "  ./install.sh -i python\n"  # Install Python
  printf "  ./install.sh -t dev\n"  # Set up system in developer mode
  printf "  ./install.sh -x update_system\n"  # Install Python

  warning "** Important: Options -i (install) and -t (type) are mutually exclusive. You can only specify one at a time. **\n\n"
  exit 0
}
# ************************************************************ #
# SYSTTEM                                                      #
# ************************************************************ #
update_system() {
  clear_screen
  print_header "System Update"

  sudo sh -c "
    apt update && apt upgrade -y &&
    apt autoclean -y && apt autoremove -y"

  LOG+=$(success "System update successfull")
}

install_library() {
  clear_screen
  print_header "Install libraries"
  
  sudo sh -c "
    apt update && apt upgrade -y && \
    apt install --no-install-recommends -y \
      build-essential software-properties-common ca-certificates \
      curl wget llvm make gpg openssl sudo unzip zsh \
      libffi-dev libnss3 libnspr4 tk-dev xvfb \
      libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev && \
    apt autoclean -y && apt autoremove -y"

  LOG+=$(success "Install libraries successful")
}

# ************************************************************ #
# DEV TOOLS                                                    #
# ************************************************************ #

install_git() {
  clear_screen
  print_header "Install GIT Version ${GIT_VERSION}"

  if exist git; then
    local git_version=$(git --version 2>&1 | awk '{print $3}')
    LOG+=$(success "GIT version ${git_version} already installed")
  else
    sudo sh -c "
      cd /tmp
      curl -fsSL https://github.com/git/git/archive/refs/tags/v${GIT_VERSION}.zip -o git.zip &&
      unzip git.zip && 
      cd git-${GIT_VERSION} &&
      make clean && 
      make prefix=/usr/local all && 
      make prefix=/usr/local install &&
      rm git.zip && 
      rm -rf git-${GIT_VERSION}"
  
    LOG+=$(success "Install GIT version ${GIT_VERSION} successful")
  fi
}
install_lazygit() {
  clear
  print_header "Install LazyGit"

  if exist lazygit; then
    LOG+=$(success "LazyGIT already installed")
  else
    local version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    sudo sh -c "
      cd /tmp
      curl -Lo lazygit.tar.gz https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_x86_64.tar.gz
      tar xf lazygit.tar.gz lazygit
	  sudo install lazygit /usr/local/bin
	  rm lazygit.tar.gz lazygit"
    LOG+=$(success "Install LazyGIT successful")
  fi
}

install_ohmyposh() {
  clear
  print_header "Install oh-my-posh over zsh"
  
  sudo sh -c "
    apt update &&
    apt upgrade -y && 
    apt install --no-install-recommends -y zsh &&
    apt autoclean -y"
  
  sudo sh -c "curl https://ohmyposh.dev/install.sh | bash -s"
  local theme="catppuccin_frappe"
  mkdir -p $HOME/.oh-my-posh &&
    wget https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${theme}.omp.json -O $HOME/.oh-my-posh/default.omp.json
  
  if ! grep -iq "oh-my-posh init zsh" ~/.zshrc; then  
    printf "\n%s" \
      "eval \"\$(oh-my-posh init zsh --config ~/.oh-my-posh/default.omp.json)\"" |
      tee -a $HOME/.zshrc >/dev/null
      chsh -s $(which zsh)
  fi
  LOG+=$(success "Install oh-my-posh successful")
}

install_nvm() {
  clear_screen
  print_header "Install NVM"

  if [ -d "${HOME}/.nvm" ]; then
    local node_version=$(node --version)
    LOG+=$(success "NVM and node version ${node_version} already installed")
  else
    sh -c "curl -fsSL https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash"
    
    if ! grep -iq "export NVM_DIR" ~/.zshrc; then
      printf "\n%s\n%s\n%s" \
        "export NVM_DIR=\"\$HOME/.nvm\"" \
        "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"  # This loads nvm" \
        "[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\"  # This loads nvm bash_completion" |
        tee -a ~/.zshrc ~/.bashrc >/dev/null
    fi
    LOG+=$(success "Install NVM successful")

    #temporary export NVM_DIR to install node, npm and yarn
    export NVM_DIR="${HOME}/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

    nvm install v${NODE_VERSION} &&
    nvm install-latest-npm &&
    npm install -g yarn
    
    LOG+=$(success "Install node, npm and yarn successful")
  fi
}

install_python() {
  clear_screen
  print_header "Install PYTHON Version ${PYTHON_VERSION}"
  
  if exist python; then
    local python_version=$(python --version 2>&1 | awk '{print $2}')
    LOG+=$(success "Python version ${python_version} already installed")
  else
    sudo sh -c "
      apt update && apt upgrade -y && 
      apt install --no-install-recommends -y \
        libbz2-dev libncurses-dev libncursesw5-dev libgdbm-dev \
        liblzma-dev libsqlite3-dev libgdbm-compat-dev libreadline-dev &&
      apt autoclean -y && apt autoremove -y"

    sudo sh -c "
      cd /tmp
      curl "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-${PYTHON_VERSION}.tar.xz" -o python.tar.xz
      mkdir -p /usr/src/python &&
      tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz &&
      rm -f python.tar.xz"

    cd /usr/src/python

    sudo sh -c "./configure \
          --enable-optimizations \
          #--enable-option-checking=fatal \
          --enable-shared \
          #--without-ensurepip"

    sudo sh -c "
      make clean &&
      make -j '$(nproc)' &&
      make install &&
      rm -rf /usr/src/python"

    find /usr/local -type d | grep -E "('test'|'tests'|'idle_test')" | xargs sudo rm -rf
    find /usr/local -type f | grep -E "('*.pyc'|'*.pyo'|'*.a')" | xargs sudo rm -f

    # create symlink
    cd /usr/local/bin
    
    sudo sh -c "
      ln -s idle3 idle &&
      ln -s pydoc3 pydoc &&
      ln -s python3 python &&
      ln -s python3-config python-config &&
      ln -s pip3 pip"

    python -m pip install --upgrade pip
    python -m pip install --upgrade setuptools
    
    sudo python -m pip install poetry && \
      poetry config virtualenvs.in-project true

    LOG+=$(success "Install PYTHON successful")
  fi

}

# ************************************************************ #
# DATABASE                                                     #
# ************************************************************ #
install_redis() {
  clear_screen
  print_header "Install Redis Server"
  
  if exist redis-server; then
    LOG+=$(success "Redis already installed")
  else
    sudo sh -c "
      apt update && apt upgrade -y &&
      apt install --no-install-recommends -y \
        redis-server &&
      apt autoclean -y && apt autoremove -y"

	  LOG+=$(success "Install Redis successful")
  fi
}

setup_mariadb_repository() {  
  LOG+=$(success "Setup MariaDB Repository")
  sudo sh -c "curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup \
    | bash -s -- --skip-maxscale --mariadb-server-version=\"mariadb-${MARIADB_VERSION}\""
}

install_mariadb() {
  clear_screen
  print_header "Install MariaDB Server"
  
  if exist mariadb; then
    LOG+=$(success "MariaDB Server already installed")	
  else
    setup_mariadb_repository

    sudo sh -c "
      apt update && apt upgrade -y &&
      apt install --no-install-recommends -y \
          mariadb-server mariadb-client &&
      apt autoclean -y && apt autoremove -y"

    # Config /etc/mysql/my.cnf
    sudo sh -c 'echo "
    [mysqld]
    bind-address = 0.0.0.0
    character-set-client-handshake = FALSE
    character-set-server = utf8mb4
    collation-server = utf8mb4_unicode_ci

    [mysql]
    default-character-set = utf8mb4
    " >> /etc/mysql/my.cnf'

    sudo service mariadb start  &&
    sudo mysql_secure_installation &&
    sudo service mariadb restart

    LOG+=$(success "Install MariaDB Server successful")
  fi
}

install_mariadb_client() {
  clear_screen
  print_header "Install MariaDB Client"
  
  if exist mariadb; then
    LOG+=$(success "MariaDB Client already installed")
  else
    setup_mariadb_repository

    sudo sh -c "
      apt update && apt upgrade -y &&
      apt install --no-install-recommends -y \
          mariadb-client &&
      apt autoclean -y && apt autoremove -y"

    # Config /etc/mysql/my.cnf
    sudo sh -c 'echo "
    [mysql]
    default-character-set = utf8mb4
    " >> /etc/mysql/my.cnf'
    
    LOG+=$(success "Install MariaDB Client successful")
  fi
}

# ************************************************************ #
# FRAPPE                                                       #
# ************************************************************ #
setup_repo() {
  if [ -f ${REPO_SSH_KEY} ]; then
    if ! grep -iq "Host frappe-repo" ~/.ssh/config; then
      printf "\n%s\n%s\n%s\n%s\n%s\n" \
        "HOST frappe-repo" \
        " HostName ${REPO_URI}" \
        " Port ${REPO_PORT}" \
        " User git" \
        " IdentityFile ${REPO_SSH_KEY}" |
        tee -a ~/.ssh/config >/dev/null  
    fi
    REPO_ADDR=ssh://frappe-repo/frappe
  else
    LOG+=$(error "SSH key ${REPO_SSH_KEY} is missing")
    exit 1
  fi
  LOG+=$(success "Setup Frappe repository")
}

install_bench() {
  clear_screen
  print_header "Install Bench Version ${BENCH_VERSION}"
  
  if ! exist bench; then
    # frappe needed library       
    sudo sh -c "
      apt update && apt upgrade -y &&      
      apt install --no-install-recommends -y \
          xvfb libfontconfig wkhtmltopdf &&
      apt autoclean -y && apt autoremove -y"

    # additional library
    sudo sh -c "
      apt install --no-install-recommends -y \
        libzbar0
      apt autoclean -y && apt autoremove -y"
      
    pip install frappe-bench=="${BENCH_VERSION}"
    sudo pip install frappe-bench=="${BENCH_VERSION}"

	LOG+=$(success "Install Bench successful")
  fi
}

enable_dev() {
  cd "${INSTALL_DIR}/${INSTANCE}"
  bench set-config -g developer_mode True
  LOG+=$(success "Setup Development Mode")
}

create_instance() {
  clear_screen
  print_header "Create new instance ${INSTANCE} in ${INSTALL_DIR}"
  
  setup_repo
  bench init "${INSTALL_DIR}/${INSTANCE}" \
              --frappe-branch "${FRAPPE_VERSION}" \
              --frappe-path "${REPO_ADDR}/frappe" \
              --verbose &&
  cd "${INSTALL_DIR}/${INSTANCE}" &&
  chmod -R o+rx "${INSTALL_DIR}/${INSTANCE}"
  LOG+=$(success "Create instance ${INSTANCE} in ${INSTALL_DIR}")
}

set_password() {
  local password confirmed_password

  while true; do
    # Prompt for password with masking
    read -sp "Enter password: " password
    echo

    # Prompt for confirmation with masking
    read -sp "Confirm password: " confirmed_password
    echo

    # Check if passwords match
    if [[ "$password" == "$confirmed_password" ]]; then
      break
    else
      echo "Passwords do not match. Please try again."
    fi
  done
  PASSWD=$password
}

create_site() {
  clear_screen
  print_header "Setup site >> ${SITE_NAME}"

  if [ -d "${INSTALL_DIR}/${INSTANCE}/${SITE_NAME}" ]; then
	LOG+=$(success "Site ${SITE_NAME} already exist")
  else
    print_header "Please provide the admin user and password of DB server"
    while true;
    do 
      read -p "User: " user;
      if [ -n "$user" ]; then break;  fi
    done
    set_password
    local db_pass=$PASSWD
    PASSWD=

    print_header "Please provide the administrator password for site ${SITE_NAME}"
    set_password
    local admin_pass=$PASSWD
    PASSWD=
    
	cd "${INSTALL_DIR}/${INSTANCE}" &&
	bench new-site "${SITE_NAME}" \
	              --no-mariadb-socket \
	              --db-host "${DB_HOST}" \
	              --db-root-username "$user" \
	              --db-root-password "${db_pass}" \
	              --db-name "${SITE_DB_NAME}" \
	              --admin-password "${admin_pass}" \
	              --verbose &&
	bench --site "${SITE_NAME}" add-to-hosts
	LOG+=$(success "Create site ${SITE_NAME} for instance ${INSTANCE}")

	case "${SERVER_ROLE}" in
	  dev)
	    enable_dev 
	    ;;
	  aio)  ;;
	  app)  ;;
	  *)    ;;
	esac	
  fi
}

install_app() {
  setup_repo
  cd "${INSTALL_DIR}/${INSTANCE}"

  for app in ${APP_LIST}; do
    local app_name="${app%%=*}"  # Extract key (everything before =)
    local app_branch="${app#*=}"  # Extract value (everything after =)
    
    bench get-app "{app_name}" "${REPO_ADDR}/${app_name}" --branch ${app_branch} &&
    bench --site "${SITE_NAME}" install-app "${app_name}"
  	LOG+=$(success "Install app ${app_name} branch ${app_branch}")
  done
}

install_frappe() {
  clear_screen
  print_header "Install Frappe Version ${FRAPPE_VERSION}"
  create_instance && create_site && install_app

  LOG+=$(success "Install Frappe successful")
}

# ************************************************************ #
# MAIN PROGRAM                                                 #
# ************************************************************ #

if [ -f "${RUNNING_DIR}/.env" ]; then
  source "${RUNNING_DIR}/.env"
fi

check_variables

while getopts ":hi:t:x:" opt; do
  case $opt in
    h)
      display_help
      ;;
    i)
      PROG="$OPTARG"
      ;;
    t)
      SERVER_ROLE="$OPTARG"
      ;;
    x)
      FUNC="$OPTARG"
      "$FUNC"
      clear_screen
      exit
      ;;
    \?)
      printf "Invalid option: -$OPTARG\n" >&2
      display_help
      ;;
  esac
done

shift $((OPTIND-1))

if [[ -z "${SERVER_ROLE}" && -z "$PROG" && -z "$FUNC" ]]; then
  display_help
fi

if [[ -n "$SERVER_ROLE" ]]; then
  case "$SERVER_ROLE" in
    dev)
      clear_screen
      LOG=$(print_header "Setup Frappe Dev server")
      update_system
      install_library && install_git && install_nvm && install_python
      install_redis && install_mariadb
      install_bench && install_frappe
      clear_screen && exit 0
      ;;
    *)
      LOG=$(error "Invalid setup mode: $SERVER_ROLE\n")
      clear_screen
      exit 1
      ;;
  esac
else 
  case "$PROG" in
    *)
      LOG=$(error "Invalid software to install: $PROG\n")
      clear_screen
      exit 1
      ;;
  esac
fi
