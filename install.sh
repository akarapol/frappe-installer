#!/usr/bin/env bash

set -euo pipefail

# ************************************************************ #
# SAFETY CHECKS                                                #
# ************************************************************ #
if [ "$(id -u)" -eq 0 ]; then
  printf "\033[31m\u274C Error: Please do not run this script as root (do not use sudo ./install.sh).\033[0m\n"
  printf "Run it as a normal user. You will be prompted for sudo password when needed.\n"
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  printf "\033[31m\u274C Error: sudo is not installed. Please install sudo first.\033[0m\n"
  exit 1
fi

# ************************************************************ #
# SYSTEM VARIABLES                                             #
# ************************************************************ #
RUNNING_DIR=$(dirname -- "${0}")
OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'=' -f2 | tr -d '"' || echo "Unknown")

# ************************************************************ #
# GLOBAL VARIABLES                                             #
# ************************************************************ #
SERVER_ROLE=
PROG=
FUNC=
PASSWD=

# ************************************************************ #
# USER VARIABLES (Defaults)                                    #
# ************************************************************ #
NODE_VERSION=${NODE_VERSION:-"24.12"}
PYTHON_VERSION=${PYTHON_VERSION:-"3.14"}
MARIADB_VERSION=${MARIADB_VERSION:-"11.8"}

DB_TYPE=${DB_TYPE:-"mariadb"}
DB_HOST=${DB_HOST:-"localhost"}
DB_ROOT_USER=${DB_ROOT_USER:-"root"}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-""}

REPO_MODE=${REPO_MODE:-"ssh"}
REPO_URI=${REPO_URI:-""}
REPO_PORT=${REPO_PORT:-""}
REPO_SSH_KEY=${REPO_SSH_KEY:-""}

BENCH_VERSION=${BENCH_VERSION:-"5.29"}
FRAPPE_VERSION=${FRAPPE_VERSION:-"version-16"}
INSTALL_DIR=${INSTALL_DIR:-"$HOME/opt"}

INSTANCE=${INSTANCE:-"frappe-16"}
APP_LIST=${APP_LIST:-"print_designer=develop"}

SITE_NAME=${SITE_NAME:-"frappe-dev.local"}
SITE_DB_NAME=${SITE_DB_NAME:-"frappe-dev"}

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
  printf "\033c"
}

print_header() {
    printf "\n${cyan}%s\n%s\n%s${reset}\n" \
      $(printf -- "-%.0s" {1..60}) \
      "${1}" \
      $(printf -- "-%.0s" {1..60})
}

info() {
  printf "${white}\u2139 ${1}${reset}\n"
}

warning() {
  printf "${yellow}\u26A0 ${1}${reset}\n"
}

error() {
  printf "${red}\u274C ${1}${reset}\n"
}

success() {
  printf "${green}\u2714 ${1}${reset}\n"
}

exist() {
  command -v "${1}" >/dev/null 2>&1
}

check_variables() {
  print_header "Configuration Check"
  info "Please review and confirm the following configuration variables."
  info "Press [Enter] to accept the default value in brackets."
  printf "\n"

  local fail=0

  # Group variables for clarity
  local core_vars=("NODE_VERSION" "PYTHON_VERSION" "MARIADB_VERSION")
  local db_vars=("DB_TYPE" "DB_HOST" "DB_ROOT_USER" "DB_ROOT_PASSWORD")
  local repo_vars=("REPO_MODE" "REPO_URI" "REPO_PORT" "REPO_SSH_KEY")
  local frappe_vars=("INSTANCE" "SITE_NAME" "SITE_DB_NAME" "APP_LIST")

  local all_vars=("${core_vars[@]}" "${db_vars[@]}" "${repo_vars[@]}" "${frappe_vars[@]}")

  for v in "${all_vars[@]}"; do
    local current_val="${!v:-}"
    local prompt_text="${v}"
    local is_password=0

    if [[ "$v" =~ "PASSWORD" || "$v" =~ "PASSWD" ]]; then
        is_password=1
    fi

    # Visual indicator for the default value
    if [[ -n "${current_val}" ]]; then
        if [[ $is_password -eq 1 ]]; then
            prompt_text="${prompt_text} [${cyan}********${reset}]"
        else
            prompt_text="${prompt_text} [${cyan}${current_val}${reset}]"
        fi
    else
        prompt_text="${prompt_text} [${red}Required${reset}]"
    fi

    # Read user input
    printf "${prompt_text}: "
    if [[ $is_password -eq 1 ]]; then
        read -s input_val
        printf "\n"
    else
        read input_val
    fi

    if [[ -n "${input_val}" ]]; then
      export "${v}=${input_val}"
    fi

    # Validation
    if [[ -z "${!v:-}" ]]; then
      error "Variable ${v} cannot be empty."
      fail=1
    fi
  done

  if [ "${fail}" == 1 ]; then
    error "Configuration incomplete. Please provide values for the required variables."
    exit 1
  fi

  success "Configuration validated."
}

confirm_proceed() {
  print_header "Installation Plan"
  info "Role: ${SERVER_ROLE:-Individual software install}"
  info "Instance: ${INSTANCE}"
  info "Site: ${SITE_NAME}"
  info "Install Directory: ${INSTALL_DIR}"
  info "OS Detected: ${OS_NAME}"

  printf "\n"
  read -p "Do you want to proceed with the installation? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    warning "Installation cancelled by user."
    exit 0
  fi
}

display_help() {
  clear_screen
  print_header "Frappe Installer Help"

  printf "Usage: ./install.sh [OPTIONS] \n\n"
  printf "Options:\n"
  printf "  -h   Display this help message.\n"
  printf "  -i   Install specific software (python, nvm, git).\n"
  printf "  -t   Setup type (dev, aio, app, db).\n"
  printf "  -x   Run specific function directly.\n\n"

  printf "Examples:\n"
  printf "  ./install.sh -t dev        # Full development setup\n"
  printf "  ./install.sh -t db         # Database only setup\n"
  printf "  ./install.sh -i python     # Install Python only\n\n"

  warning "Options -i and -t are mutually exclusive.\n"
  exit 0
}
# ************************************************************ #
# SYSTEM                                                       #
# ************************************************************ #
update_system() {
  print_header "System Update"
  info "Updating apt repositories and upgrading packages..."

  sudo apt update && sudo apt upgrade -y &&
  sudo apt autoclean -y && sudo apt autoremove -y

  success "System update successful"
}

install_library() {
  print_header "Install libraries"
  info "Installing essential system libraries..."

  sudo apt update && sudo apt upgrade -y && \
  sudo apt install --no-install-recommends -y \
      build-essential pkg-config apt-transport-https ca-certificates \
      curl wget llvm make gpg gnupg lsb-release openssl sudo unzip zsh cron \
      libcairo2-dev libffi-dev libnss3 libnspr4 tk-dev xvfb \
      libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev && \
  sudo apt autoclean -y && sudo apt autoremove -y

  success "Install libraries successful"
}

# ************************************************************ #
# DEV TOOLS                                                    #
# ************************************************************ #

install_git() {
  print_header "Install GIT"

  if exist git; then
    local current_git_version=$(git --version 2>&1 | awk '{print $3}')
    info "GIT version ${current_git_version} already installed. Skipping build."
  else
    sudo apt update && sudo apt upgrade -y && \
    sudo apt install --no-install-recommends -y git && \
    sudo apt autoclean -y && sudo apt autoremove -y

    local current_git_version=$(git --version 2>&1 | awk '{print $3}')
    success "Install GIT version ${current_git_version} successful"
  fi
}

install_lazygit() {
  print_header "Install LazyGit"

  if exist lazygit; then
    success "LazyGIT already installed"
  else
    info "Downloading and installing LazyGit..."
    local version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    sudo sh -c "
      cd /tmp &&
      curl -Lo lazygit.tar.gz https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_x86_64.tar.gz &&
      tar xf lazygit.tar.gz lazygit &&
	  install lazygit /usr/local/bin &&
	  rm lazygit.tar.gz lazygit"
    success "Install LazyGIT successful"
  fi
}

install_ohmyposh() {
  print_header "Install oh-my-posh over zsh"

  if ! exist zsh; then
    sudo apt update && sudo apt install --no-install-recommends -y zsh
  fi

  info "Installing oh-my-posh..."
  sudo sh -c "curl https://ohmyposh.dev/install.sh | bash -s"

  local theme="catppuccin_frappe"
  mkdir -p "$HOME/.oh-my-posh"
  wget -q https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${theme}.omp.json -O "$HOME/.oh-my-posh/default.omp.json"

  if ! grep -iq "oh-my-posh init zsh" "$HOME/.zshrc"; then
    printf "\n%s\n" \
      "eval \"\$(oh-my-posh init zsh --config ~/.oh-my-posh/default.omp.json)\"" >> "$HOME/.zshrc"
    info "Zsh configuration updated. Change your shell to zsh manually if needed: chsh -s \$(which zsh)"
  fi
  success "Install oh-my-posh successful"
}

install_nvm() {
  print_header "Install NVM"

  if [ -d "${HOME}/.nvm" ]; then
    info "NVM already installed. Checking node version..."
    # Source NVM to check
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if exist node; then
        info "Node $(node --version) is already installed."
    else
        nvm install "v${NODE_VERSION}"
    fi
  else
    info "Installing NVM..."
    curl -fsSL https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash

    # Source NVM for the current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    nvm install "v${NODE_VERSION}" &&
    nvm install-latest-npm &&
    npm install -g yarn

    success "Install NVM and Node successful"
  fi
}

install_python() {
  print_header "Install PYTHON Version ${PYTHON_VERSION}"

  sudo apt update && sudo apt upgrade -y && \
  sudo apt install --no-install-recommends -y python3-dev && \
  sudo apt autoclean -y && sudo apt autoremove -y

  if ! exist uv; then
    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source "$HOME/.local/bin/env"
  fi

  info "Installing Python ${PYTHON_VERSION} via uv..."
  uv python install "${PYTHON_VERSION}" --default
  success "Python ${PYTHON_VERSION} installation successful"
}

# ************************************************************ #
# DATABASE                                                     #
# ************************************************************ #
install_redis() {
  print_header "Install Redis Server"

  if exist redis-server; then
    success "Redis already installed"
  else
    info "Installing Redis server..."
    sudo apt update && sudo apt install --no-install-recommends -y redis-server
    success "Install Redis successful"
  fi
}

setup_mariadb_repository() {
  info "Setting up MariaDB Repository for version ${MARIADB_VERSION}..."
  curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup \
    | sudo bash -s -- --skip-maxscale --mariadb-server-version="${MARIADB_VERSION}"
}

secure_mariadb() {
  info "Securing MariaDB installation..."

  # Check if we can login without password (fresh install usually allows sudo mariadb)
  if sudo mariadb -e "SELECT 1;" >/dev/null 2>&1; then
      info "Applying security settings and setting root password..."

      # Commands to:
      # 1. Set root password (force native password auth to fix 1698 socket error)
      # 2. Remove anonymous users
      # 3. Disallow remote root login
      # 4. Remove test database
      # 5. Reload privileges

      sudo mariadb <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_ROOT_PASSWORD}');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
      success "MariaDB secured successfully."
  else
      # If we can't login without password, check if the provided password works
      if mariadb -u"${DB_ROOT_USER}" -p"${DB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
          info "MariaDB is already secured with the provided password."
      else
          warning "Could not log in to MariaDB as root. It might already be secured with a different password."
          warning "Please ensure DB_ROOT_PASSWORD matches the existing root password."
      fi
  fi
}

install_mariadb() {
  print_header "Install MariaDB Server"

  if exist mariadb; then
    success "MariaDB Server already installed"
    secure_mariadb
  else
    setup_mariadb_repository

    info "Installing MariaDB Server..."
    sudo apt update && \
    sudo apt install --no-install-recommends -y \
        mariadb-server mariadb-client \
        libmariadb-dev libmariadb-dev-compat \
        default-libmysqlclient-dev libmysqlclient-dev && \
    sudo apt autoclean -y && sudo apt autoremove -y

    # Config /etc/mysql/mariadb.conf
    info "Configuring MariaDB..."
    sudo sh -c 'printf "
[mysqld]
bind-address = 0.0.0.0
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_thai_520_w2

[mysql]
default-character-set = utf8mb4
" >> /etc/mysql/mariadb.conf'

    sudo service mariadb start
    secure_mariadb

    info "Restarting MariaDB to apply security changes..."
    sudo service mariadb restart

    success "Install MariaDB Server successful"
  fi
}

install_mariadb_client() {
  print_header "Install MariaDB Client"

  if exist mariadb; then
    success "MariaDB Client already installed"
  else
    setup_mariadb_repository

    info "Installing MariaDB Client..."
    sudo apt update && \
    sudo apt install --no-install-recommends -y \
        mariadb-client \
        libmariadb-dev libmariadb-dev-compat \
        default-libmysqlclient-dev libmysqlclient-dev \
    sudo apt autoclean -y && sudo apt autoremove -y

    # Config /etc/mysql/my.cnf
    sudo sh -c 'printf "
[mysql]
default-character-set = utf8mb4
" >> /etc/mysql/my.cnf'

    success "Install MariaDB Client successful"
  fi
}

# ************************************************************ #
# FRAPPE                                                       #
# ************************************************************ #
setup_repo() {
  if [[ -z "${REPO_SSH_KEY}" || ! -f "${REPO_SSH_KEY}" ]]; then
      error "SSH key REPO_SSH_KEY is missing or not set: ${REPO_SSH_KEY}"
      exit 1
  fi

  info "Configuring SSH for Frappe repository (${REPO_URI}:${REPO_PORT})..."

  local config_file="$HOME/.ssh/config"
  mkdir -p "$HOME/.ssh"
  touch "$config_file"
  chmod 600 "$config_file"

  # Use awk to remove the existing 'frappe-repo' block if it exists.
  # It detects 'Host frappe-repo' and deletes lines until the next 'Host ...' or EOF.
  local temp_config=$(mktemp)
  awk '
    tolower($1) == "host" && $2 == "frappe-repo" { skip=1; next }
    tolower($1) == "host" && $2 != "frappe-repo" { skip=0 }
    !skip { print }
  ' "$config_file" > "$temp_config"
  mv "$temp_config" "$config_file"

  # Append the new configuration block
  {
    printf "\nHost frappe-repo\n"
    printf "  HostName ${REPO_URI}\n"
    printf "  Port ${REPO_PORT}\n"
    printf "  User git\n"
    printf "  IdentityFile ${REPO_SSH_KEY}\n"
    printf "  StrictHostKeyChecking no\n"
    printf "  UserKnownHostsFile /dev/null\n"
  } >> "$config_file"

  REPO_ADDR="ssh://frappe-repo/frappe"
  success "SSH config updated for host 'frappe-repo'."
}

install_bench() {
  print_header "Install Bench Version ${BENCH_VERSION}"

  if exist bench; then
    success "Bench already installed: $(bench --version)"
  else
    info "Installing Bench dependencies..."
    sudo apt update && \
    sudo apt install --no-install-recommends -y xvfb libfontconfig wkhtmltopdf libzbar0

    info "Installing frappe-bench via uv..."
    uv tool install "frappe-bench==${BENCH_VERSION}"
	success "Install Bench successful"
  fi
}

enable_dev() {
  info "Enabling developer mode for ${INSTANCE}..."
  cd "${INSTALL_DIR}/${INSTANCE}"
  bench set-config -g developer_mode True
  success "Developer Mode enabled"
}

create_instance() {
  print_header "Create new instance ${INSTANCE}"

  if [ -d "${INSTALL_DIR}/${INSTANCE}" ]; then
      warning "Instance directory ${INSTALL_DIR}/${INSTANCE} already exists."
      read -p "Overwrite instance? (y/N): " overwrite
      if [[ "$overwrite" =~ ^[yY]$ ]]; then
          rm -rf "${INSTALL_DIR}/${INSTANCE}"
      else
          success "Skipping instance creation."
          return 0
      fi
  fi

  setup_repo
  info "Initializing bench in ${INSTALL_DIR}/${INSTANCE}..."
  bench init "${INSTALL_DIR}/${INSTANCE}" \
              --frappe-branch "${FRAPPE_VERSION}" \
              --frappe-path "${REPO_ADDR}/frappe" \
              --verbose

  cd "${INSTALL_DIR}/${INSTANCE}"
  chmod -R o+rx "${INSTALL_DIR}/${INSTANCE}"
  success "Instance ${INSTANCE} created successfully"
}

set_password() {
  local password confirmed_password
  while true; do
    read -sp "Enter password: " password
    echo
    read -sp "Confirm password: " confirmed_password
    echo
    if [[ "$password" == "$confirmed_password" ]]; then
      break
    else
      error "Passwords do not match. Please try again."
    fi
  done
  PASSWD=$password
}



start_bench_services() {
  # Check if services are already running (simple check on pids)
  if ls config/pids_redis_*.pid 1> /dev/null 2>&1; then
     # PIDs exist, assume running for this script session
     return 0
  fi

  print_header "Starting Temporary Bench Services"
  info "Starting Redis instances for cache, queue, and socketio..."

  cd "${INSTALL_DIR}/${INSTANCE}"

  # Start Redis servers in background using generated configs
  if [ -f config/redis_cache.conf ]; then
      redis-server config/redis_cache.conf &
      echo $! > config/pids_redis_cache.pid
  fi

  if [ -f config/redis_queue.conf ]; then
      redis-server config/redis_queue.conf &
      echo $! > config/pids_redis_queue.pid
  fi

  if [ -f config/redis_socketio.conf ]; then
      redis-server config/redis_socketio.conf &
      echo $! > config/pids_redis_socketio.pid
  fi

  # Wait a moment for services to spin up
  sleep 3
  success "Temporary bench services started."
}

stop_bench_services() {
  # Only stop if we find our pid files
  if ! ls config/pids_redis_*.pid 1> /dev/null 2>&1; then
     return 0
  fi

  print_header "Stopping Temporary Bench Services"
  cd "${INSTALL_DIR}/${INSTANCE}"

  for pid_file in config/pids_redis_*.pid; do
      if [ -f "$pid_file" ]; then
          local pid=$(cat "$pid_file")
          info "Stopping Redis process ${pid}..."
          kill "$pid" 2>/dev/null || true
          rm "$pid_file"
      fi
  done
  success "Temporary bench services stopped."
}

create_site() {
  print_header "Setup site >> ${SITE_NAME}"
  cd "${INSTALL_DIR}/${INSTANCE}"

  if [ -d "sites/${SITE_NAME}" ]; then
	success "Site ${SITE_NAME} already exists. Skipping creation."
  else
    info "Configuring database for site ${SITE_NAME}..."

    info "Set Administrator password for site ${SITE_NAME}:"
    set_password
    local admin_pass=$PASSWD

	bench new-site "${SITE_NAME}" \
	              --db-host "${DB_HOST}" \
	              --db-root-username "${DB_ROOT_USER}" \
	              --db-root-password "${DB_ROOT_PASSWORD}" \
	              --db-name "${SITE_DB_NAME}" \
	              --admin-password "${admin_pass}" \
				  --mariadb-user-host-login-scope "localhost" \
	              --verbose &&
	bench use "${SITE_NAME}" &&
	bench --site "${SITE_NAME}" add-to-hosts

	success "Site ${SITE_NAME} created successfully"

	case "${SERVER_ROLE}" in
	  dev) enable_dev ;;
	  *) ;;
	esac
  fi
}

install_app() {
  print_header "Installing Apps"
  setup_repo
  cd "${INSTALL_DIR}/${INSTANCE}"

  # Start services for the duration of app installation
  start_bench_services

  for app in ${APP_LIST}; do
    local app_name="${app%%=*}"
    local app_branch="${app#*=}"

    if [ -d "apps/${app_name}" ]; then
        info "App ${app_name} already exists. Skipping."
    else
        info "Fetching app ${app_name} [${app_branch}]..."
        bench get-app "${app_name}" "${REPO_ADDR}/${app_name}" --branch "${app_branch}"
    fi

    info "Installing app ${app_name} on site ${SITE_NAME}..."
    bench --site "${SITE_NAME}" install-app "${app_name}"
  	success "App ${app_name} installed successfully"
  done

  # Stop services
  stop_bench_services
}

install_frappe() {
  print_header "Frappe Installation"

  create_instance
  create_site
  install_app

  success "Frappe installation completed"
}

# ************************************************************ #
# MAIN PROGRAM                                                 #
# ************************************************************ #

if [ -f "${RUNNING_DIR}/.env" ]; then
  source "${RUNNING_DIR}/.env"
fi

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
      exit 0
      ;;
    \?)
      error "Invalid option: -$OPTARG"
      display_help
      ;;
  esac
done

shift $((OPTIND-1))

if [[ -z "${SERVER_ROLE}" && -z "$PROG" && -z "$FUNC" ]]; then
  display_help
fi

# Run Validation and Confirmation
check_variables
confirm_proceed

if [[ -n "$SERVER_ROLE" ]]; then
  case "$SERVER_ROLE" in
    dev|aio)
      print_header "Setup Frappe Dev server"
      update_system
      install_library && install_git && install_nvm && install_python
      install_redis && install_mariadb
      install_bench && install_frappe
      success "Frappe Dev server setup completed successfully!"
      exit 0
      ;;
    db)
      print_header "Setup MariaDB server"
      update_system
      install_library
      install_redis && install_mariadb
      success "MariaDB server setup completed successfully!"
      exit 0
      ;;
    app)
      print_header "Setup Frappe App server"
      update_system
      install_library && install_git && install_nvm && install_python
      install_bench && install_frappe
      success "Frappe App server setup completed successfully!"
      exit 0
      ;;
    *)
      error "Invalid setup mode: $SERVER_ROLE"
      exit 1
      ;;
  esac
elif [[ -n "$PROG" ]]; then
  case "$PROG" in
    python) install_python ;;
    nvm) install_nvm ;;
    git) install_git ;;
    lazygit) install_lazygit ;;
    *)
      error "Invalid software to install: $PROG"
      exit 1
      ;;
  esac
fi
