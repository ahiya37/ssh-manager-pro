#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 🔐 SSH Manager Pro - מנהל מפתחות מקצועי
# גרסה: 4.0
# עיצוב משופר, ממשק ידידותי, קל לשימוש
# שיפורים: ביצועים מהירים, מעבר בין שרתים, עדכון אוטומטי
###############################################################################

# צבעים וסגנונות
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'
NC='\033[0m'

# אמוג'ים
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="💡"
ROCKET="🚀"
KEY="🔑"
LOCK="🔒"
UNLOCK="🔓"
FOLDER="📁"
SAVE="💾"
TRASH="🗑️"
SHIELD="🛡️"
STAR="⭐"
FIRE="🔥"
DIAMOND="💎"
GEAR="⚙️"
GLOBE="🌍"
COMPUTER="💻"
CLOUD="☁️"
SPARKLES="✨"
UPDATE="🔄"
LIGHTNING="⚡"
ARROW="➜"

# הגדרות
SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/ssh_manager_servers.json"
KEYS_DIR="$SSH_DIR/keys"
BACKUP_DIR="$SSH_DIR/backups"
LOG_FILE="$SSH_DIR/ssh_manager.log"
CACHE_DIR="$SSH_DIR/cache"
SCRIPTS_DIR="$SSH_DIR/update_scripts"

# יצירת תיקיות
mkdir -p "$SSH_DIR" "$KEYS_DIR" "$BACKUP_DIR" "$CACHE_DIR" "$SCRIPTS_DIR"
chmod 700 "$SSH_DIR" "$KEYS_DIR"

# משתנים גלובליים למטמון
declare -A SERVER_CACHE
declare -A STATUS_CACHE
CACHE_LOADED=false
CACHE_TTL=300  # 5 דקות

# פונקציות עיצוב
print_center() {
    local text="$1"
    local width=$(tput cols 2>/dev/null || echo 80)
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%*s%s\n" $padding "" "$text"
}

print_line() {
    local char="${1:-─}"
    local width=$(tput cols 2>/dev/null || echo 80)
    printf "${CYAN}%*s${NC}\n" "$width" | tr ' ' "$char"
}

print_header() {
    clear
    print_line "═"
    echo -e "${CYAN}${BOLD}"
    print_center "🔐 SSH Manager Pro 4.0 🔐"
    print_center "ניהול מפתחות וחיבורים מתקדם"
    echo -e "${NC}"
    print_line "═"
    echo
}

print_box() {
    local title="$1"
    local content="$2"
    local color="${3:-$CYAN}"
    
    echo -e "${color}┌─ ${BOLD}${title}${NC}${color} ─────────────────${NC}"
    echo -e "${color}│${NC} ${content}"
    echo -e "${color}└────────────────────────────────${NC}"
}

# פונקציות הודעות
success() {
    echo -e "\n${GREEN}${CHECK} ${BOLD}$1${NC}"
    echo "$(date): SUCCESS - $1" >> "$LOG_FILE"
}

error() {
    echo -e "\n${RED}${CROSS} ${BOLD}$1${NC}"
    echo "$(date): ERROR - $1" >> "$LOG_FILE"
    sleep 2
}

warning() {
    echo -e "\n${YELLOW}${WARNING} ${BOLD}$1${NC}"
    echo "$(date): WARNING - $1" >> "$LOG_FILE"
}

info() {
    echo -e "\n${BLUE}${INFO} $1${NC}"
}

loading() {
    local text="${1:-טוען...}"
    echo -ne "${CYAN}⏳ ${text}${NC}"
    for i in {1..3}; do
        sleep 0.3
        echo -ne "."
    done
    echo -e " ${GREEN}${CHECK}${NC}"
}

# אנימציה מהירה
quick_loading() {
    local text="${1:-טוען...}"
    echo -ne "${CYAN}${LIGHTNING} ${text}${NC}"
    sleep 0.1
    echo -e " ${GREEN}${CHECK}${NC}"
}

# טעינת מטמון שרתים
load_servers_cache() {
    if [[ "$CACHE_LOADED" == "true" ]]; then
        return 0
    fi
    
    # טעינת כל השרתים למטמון
    for conf in "$SSH_DIR"/.server_*.conf; do
        if [[ -f "$conf" ]]; then
            local server_id=$(basename "$conf" .conf | sed 's/.server_//')
            SERVER_CACHE[$server_id]="$conf"
        fi
    done
    
    CACHE_LOADED=true
}

# בדיקת סטטוס מהירה (ברקע)
check_server_status_async() {
    local server_id="$1"
    local cache_file="$CACHE_DIR/status_${server_id}"
    
    # בדיקה אם יש מטמון תקף
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file") ))
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            STATUS_CACHE[$server_id]=$(cat "$cache_file")
            return 0
        fi
    fi
    
    # בדיקה ברקע
    {
        source "${SERVER_CACHE[$server_id]}"
        if [[ -f "${KEY_PATH}.pub" ]]; then
            if timeout 2 ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
                -o ConnectTimeout=2 -o BatchMode=yes "true" 2>/dev/null; then
                echo "online" > "$cache_file"
                STATUS_CACHE[$server_id]="online"
            else
                echo "offline" > "$cache_file"
                STATUS_CACHE[$server_id]="offline"
            fi
        else
            echo "nokey" > "$cache_file"
            STATUS_CACHE[$server_id]="nokey"
        fi
    } &
}

# תפריט ראשי מהיר
main_menu() {
    # טעינת מטמון בפעם הראשונה
    load_servers_cache
    
    print_header
    
    echo -e "${WHITE}${BOLD}ברוך הבא!${NC} בחר פעולה:\n"
    
    echo -e "  ${GREEN}${BOLD}[1]${NC} ${ROCKET} התחלה מהירה ${DIM}(מומלץ למתחילים)${NC}"
    echo -e "  ${BLUE}${BOLD}[2]${NC} ${COMPUTER} השרתים שלי ${LIGHTNING}"
    echo -e "  ${PURPLE}${BOLD}[3]${NC} ${KEY} המפתחות שלי"
    echo -e "  ${YELLOW}${BOLD}[4]${NC} ${GEAR} כלים וטיפים"
    echo -e "  ${CYAN}${BOLD}[5]${NC} ${SHIELD} בדיקת אבטחה"
    echo -e "  ${WHITE}${BOLD}[6]${NC} ${SAVE} גיבוי ושחזור"
    echo -e "  ${GREEN}${BOLD}[7]${NC} ${UPDATE} עדכון שרתים"
    echo -e "  ${BLUE}${BOLD}[8]${NC} ${INFO} עזרה"
    echo -e "  ${RED}${BOLD}[0]${NC} יציאה\n"
    
    echo -ne "${BOLD}בחירתך: ${NC}"
    read -r choice
    
    case $choice in
        1) quick_start ;;
        2) fast_servers_menu ;;
        3) keys_menu ;;
        4) tools_menu ;;
        5) security_check ;;
        6) backup_menu ;;
        7) update_servers_menu ;;
        8) show_help ;;
        0) goodbye ;;
        *) 
            error "אפשרות לא חוקית"
            sleep 1
            main_menu
            ;;
    esac
}

# תפריט שרתים מהיר
fast_servers_menu() {
    print_header
    echo -e "${COMPUTER} ${BOLD}השרתים שלי${NC} ${LIGHTNING}\n"
    
    # טעינת שרתים ממטמון
    local count=0
    declare -a server_list
    
    for server_id in "${!SERVER_CACHE[@]}"; do
        source "${SERVER_CACHE[$server_id]}"
        ((count++))
        server_list[$count]="$server_id"
        
        # בדיקת סטטוס ברקע
        check_server_status_async "$server_id"
        
        # הצגה מיידית עם סטטוס זמני
        local status_icon="${DIM}⏳${NC}"
        if [[ -n "${STATUS_CACHE[$server_id]:-}" ]]; then
            case "${STATUS_CACHE[$server_id]}" in
                "online") status_icon="${GREEN}${CHECK}${NC}" ;;
                "offline") status_icon="${RED}${CROSS}${NC}" ;;
                "nokey") status_icon="${YELLOW}${WARNING}${NC}" ;;
            esac
        fi
        
        echo -e "  ${BOLD}[$count]${NC} $status_icon ${WHITE}$SERVER_NAME${NC}"
        echo -e "      ${DIM}$SERVER_USER@$SERVER_HOST:$SERVER_PORT${NC}"
        
        # קיצורי דרך לשרתים פופולריים
        case "$SERVER_NAME" in
            *n8n*) echo -e "      ${PURPLE}[U$count]${NC} ${UPDATE} עדכן N8N" ;;
            *waha*) echo -e "      ${PURPLE}[U$count]${NC} ${UPDATE} עדכן WAHA" ;;
            *chatwoot*) echo -e "      ${PURPLE}[U$count]${NC} ${UPDATE} עדכן Chatwoot" ;;
        esac
        echo
    done
    
    if [[ $count -eq 0 ]]; then
        info "אין שרתים שמורים עדיין"
        echo -e "\n${BOLD}[+]${NC} הוסף שרת חדש"
    else
        echo -e "${BOLD}[+]${NC} הוסף שרת חדש"
        echo -e "${BOLD}[#]${NC} בחר מספר שרת להתחבר ${LIGHTNING}"
        echo -e "${BOLD}[U#]${NC} עדכן שרת (למשל: U1)"
        echo -e "${BOLD}[S]${NC} ${ARROW} מעבר מהיר בין שרתים"
    fi
    
    echo -e "${BOLD}[R]${NC} ${UPDATE} רענן סטטוס"
    echo -e "${BOLD}[0]${NC} חזור\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    if [[ "$choice" == "+" ]]; then
        easy_server_setup
    elif [[ "$choice" == "0" ]]; then
        main_menu
    elif [[ "$choice" == "R" ]] || [[ "$choice" == "r" ]]; then
        rm -rf "$CACHE_DIR"/*
        STATUS_CACHE=()
        fast_servers_menu
    elif [[ "$choice" == "S" ]] || [[ "$choice" == "s" ]]; then
        server_switcher
    elif [[ "$choice" =~ ^U([0-9]+)$ ]] || [[ "$choice" =~ ^u([0-9]+)$ ]]; then
        local num="${BASH_REMATCH[1]}"
        if [[ $num -le $count ]]; then
            quick_update_server "${server_list[$num]}"
        fi
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -le $count ]]; then
        quick_connect_to_server "${server_list[$choice]}"
    else
        fast_servers_menu
    fi
}

# התחברות מהירה עם אפשרות מעבר
quick_connect_to_server() {
    local server_id="$1"
    source "${SERVER_CACHE[$server_id]}"
    
    echo -e "\n${GREEN}${ROCKET} מתחבר ל-$SERVER_NAME...${NC}"
    echo -e "${DIM}(הקלד 'exit' ואז '~' למעבר בין שרתים)${NC}\n"
    
    # שמירת שרת אחרון
    echo "$server_id" > "$CACHE_DIR/last_server"
    
    # התחברות עם סקריפט מעבר
    ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
        -o SendEnv="SSH_MANAGER_SESSION" \
        -t "echo '${YELLOW}מחובר ל: $SERVER_NAME${NC}'; echo 'הקלד ~ למעבר מהיר בין שרתים'; exec bash"
    
    # בדיקה אם המשתמש רוצה לעבור שרת
    echo -e "\n${CYAN}${ARROW} אפשרויות:${NC}"
    echo -e "  ${BOLD}[~]${NC} מעבר מהיר לשרת אחר"
    echo -e "  ${BOLD}[R]${NC} התחבר שוב ל-$SERVER_NAME"
    echo -e "  ${BOLD}[U]${NC} עדכן את $SERVER_NAME"
    echo -e "  ${BOLD}[Enter]${NC} חזור לתפריט\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r action
    
    case "$action" in
        "~") server_switcher ;;
        "R"|"r") quick_connect_to_server "$server_id" ;;
        "U"|"u") quick_update_server "$server_id" ;;
        *) fast_servers_menu ;;
    esac
}

# מעבר מהיר בין שרתים
server_switcher() {
    print_header
    echo -e "${ARROW} ${BOLD}מעבר מהיר בין שרתים${NC} ${LIGHTNING}\n"
    
    local count=0
    declare -a server_list
    
    # הצגת שרתים אונליין בלבד
    for server_id in "${!SERVER_CACHE[@]}"; do
        if [[ "${STATUS_CACHE[$server_id]:-}" == "online" ]]; then
            source "${SERVER_CACHE[$server_id]}"
            ((count++))
            server_list[$count]="$server_id"
            
            echo -e "  ${BOLD}[$count]${NC} ${GREEN}${CHECK}${NC} ${WHITE}$SERVER_NAME${NC}"
            echo -e "      ${DIM}$SERVER_USER@$SERVER_HOST${NC}"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        warning "אין שרתים מחוברים כרגע"
        echo -e "\n${BOLD}לחץ Enter...${NC}"
        read -r
        fast_servers_menu
        return
    fi
    
    # שרת אחרון
    if [[ -f "$CACHE_DIR/last_server" ]]; then
        local last_server=$(cat "$CACHE_DIR/last_server")
        echo -e "\n${DIM}שרת אחרון: $last_server${NC}"
    fi
    
    echo -e "\n${BOLD}בחר שרת למעבר מהיר:${NC}"
    echo -ne "${BOLD}מספר [1-$count]: ${NC}"
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -le $count ]]; then
        quick_connect_to_server "${server_list[$choice]}"
    else
        fast_servers_menu
    fi
}

# תפריט עדכון שרתים
update_servers_menu() {
    print_header
    echo -e "${UPDATE} ${BOLD}עדכון שרתים${NC}\n"
    
    echo -e "${WHITE}בחר שרת לעדכון:${NC}\n"
    
    local count=0
    declare -a server_list
    
    for server_id in "${!SERVER_CACHE[@]}"; do
        source "${SERVER_CACHE[$server_id]}"
        ((count++))
        server_list[$count]="$server_id"
        
        local update_type="כללי"
        case "$SERVER_NAME" in
            *n8n*|*N8N*) update_type="N8N" ;;
            *waha*|*WAHA*) update_type="WAHA" ;;
            *chatwoot*|*Chatwoot*) update_type="Chatwoot" ;;
        esac
        
        echo -e "  ${BOLD}[$count]${NC} ${WHITE}$SERVER_NAME${NC} ${DIM}($update_type)${NC}"
    done
    
    echo -e "\n${BOLD}[A]${NC} עדכן את כל השרתים"
    echo -e "${BOLD}[C]${NC} הגדר סקריפט עדכון מותאם אישית"
    echo -e "${BOLD}[0]${NC} חזור\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    if [[ "$choice" == "0" ]]; then
        main_menu
    elif [[ "$choice" == "A" ]] || [[ "$choice" == "a" ]]; then
        update_all_servers
    elif [[ "$choice" == "C" ]] || [[ "$choice" == "c" ]]; then
        configure_update_script
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -le $count ]]; then
        quick_update_server "${server_list[$choice]}"
    else
        update_servers_menu
    fi
}

# עדכון מהיר של שרת
quick_update_server() {
    local server_id="$1"
    source "${SERVER_CACHE[$server_id]}"
    
    print_header
    echo -e "${UPDATE} ${BOLD}מעדכן את: $SERVER_NAME${NC}\n"
    
    # בדיקה ראשונה - האם יש סקריפט מותאם אישית?
    if [[ -f "$SCRIPTS_DIR/${server_id}_update.sh" ]]; then
        echo -e "${YELLOW}${SPARKLES} נמצא סקריפט מותאם אישית ל-$SERVER_NAME${NC}"
        local update_script="custom"
    else
        # זיהוי חכם של סוג השרת
        local update_script=""
        
        # בדיקה מדויקת יותר לפי שם
        if [[ "$SERVER_NAME" =~ n8n|N8N ]]; then
            # בדיקה איזה סוג של N8N
            echo -e "${PURPLE}זוהה: N8N Server${NC}"
            echo -e "${CYAN}בודק איזה סוג התקנה...${NC}\n"
            
            # בדיקה בשרת איך N8N מותקן
            local install_type=$(ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
                "if command -v n8n &>/dev/null; then echo 'npm'; \
                elif docker ps | grep -q n8n; then echo 'docker'; \
                elif pm2 list | grep -q n8n; then echo 'pm2'; \
                else echo 'unknown'; fi" 2>/dev/null)
            
            case "$install_type" in
                "npm"|"pm2")
                    echo -e "${GREEN}${CHECK} התקנת NPM/PM2${NC}"
                    update_script="n8n-npm"
                    ;;
                "docker")
                    echo -e "${BLUE}${CHECK} התקנת Docker${NC}"
                    update_script="n8n-docker"
                    ;;
                *)
                    echo -e "${YELLOW}${WARNING} לא זוהה סוג ההתקנה${NC}"
                    echo -e "\n${WHITE}איך N8N מותקן בשרת הזה?${NC}"
                    echo -e "  ${BOLD}[1]${NC} NPM/PM2"
                    echo -e "  ${BOLD}[2]${NC} Docker"
                    echo -e "  ${BOLD}[3]${NC} Docker Compose"
                    echo -e "  ${BOLD}[4]${NC} אחר/לא יודע\n"
                    
                    echo -ne "${BOLD}בחירה: ${NC}"
                    read -r n8n_type
                    
                    case "$n8n_type" in
                        1) update_script="n8n-npm" ;;
                        2) update_script="n8n-docker" ;;
                        3) update_script="n8n-compose" ;;
                        4) update_script="general" ;;
                    esac
                    
                    # שמירת הבחירה לפעם הבאה
                    echo -e "\n${YELLOW}לשמור את ההגדרה הזו לשרת $SERVER_NAME?${NC}"
                    echo -ne "${BOLD}(כן/לא) [כן]: ${NC}"
                    read -r save_config
                    
                    if [[ "$save_config" != "לא" ]] && [[ "$save_config" != "n" ]]; then
                        save_server_update_config "$server_id" "$update_script"
                    fi
                    ;;
            esac
            
        elif [[ "$SERVER_NAME" =~ waha|WAHA ]]; then
            update_script="update-waha.sh"
            echo -e "${GREEN}זוהה: WAHA Server${NC}"
            
        elif [[ "$SERVER_NAME" =~ chatwoot|Chatwoot ]]; then
            update_script="update-chatwoot.sh"
            echo -e "${BLUE}זוהה: Chatwoot Server${NC}"
            
        else
            echo -e "${YELLOW}לא זוהה סוג השרת${NC}"
            echo -e "\n${WHITE}מה מותקן בשרת הזה?${NC}"
            echo -e "  ${BOLD}[1]${NC} N8N"
            echo -e "  ${BOLD}[2]${NC} WAHA"
            echo -e "  ${BOLD}[3]${NC} Chatwoot"
            echo -e "  ${BOLD}[4]${NC} אפליקציה אחרת"
            echo -e "  ${BOLD}[5]${NC} עדכון כללי של המערכת\n"
            
            echo -ne "${BOLD}בחירה: ${NC}"
            read -r app_type
            
            case "$app_type" in
                1) 
                    # חזרה לבדיקת N8N
                    SERVER_NAME="${SERVER_NAME}_n8n"
                    quick_update_server "$server_id"
                    return
                    ;;
                2) update_script="update-waha.sh" ;;
                3) update_script="update-chatwoot.sh" ;;
                4) 
                    configure_update_script "$server_id"
                    return
                    ;;
                5) update_script="general" ;;
                *) return ;;
            esac
        fi
    fi
    
    echo -e "\n${CYAN}${UPDATE} מתחיל עדכון...${NC}\n"
    
    # ביצוע העדכון לפי הסוג
    case "$update_script" in
        "n8n-npm")
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'EOF'
                echo "מעדכן N8N (NPM)..."
                # עדכון דרך NPM
                npm update -g n8n
                # אם יש PM2
                if command -v pm2 &>/dev/null; then
                    pm2 restart n8n
                    pm2 save
                fi
                echo "העדכון הושלם!"
EOF
            ;;
            
        "n8n-docker")
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'EOF'
                echo "מעדכן N8N (Docker)..."
                # עדכון קונטיינר בודד
                docker pull n8nio/n8n:latest
                docker stop n8n
                docker rm n8n
                # הרצה מחדש עם אותן הגדרות
                docker run -d --restart always \
                    --name n8n \
                    -p 5678:5678 \
                    -v n8n_data:/home/node/.n8n \
                    n8nio/n8n:latest
                echo "העדכון הושלם!"
EOF
            ;;
            
        "n8n-compose")
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'EOF'
                echo "מעדכן N8N (Docker Compose)..."
                # מציאת התיקייה של docker-compose
                if [ -f "/root/docker-compose.yml" ]; then
                    cd /root
                elif [ -f "$HOME/n8n/docker-compose.yml" ]; then
                    cd $HOME/n8n
                elif [ -f "$HOME/docker-compose.yml" ]; then
                    cd $HOME
                else
                    echo "מחפש קובץ docker-compose.yml..."
                    cd $(find / -name "docker-compose.yml" -path "*/n8n/*" 2>/dev/null | head -1 | xargs dirname)
                fi
                
                docker-compose pull
                docker-compose down
                docker-compose up -d
                docker system prune -f
                echo "העדכון הושלם!"
EOF
            ;;
            
        "update-n8n.sh")
            # תאימות אחורה - בדיקה איזה סוג
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'EOF'
                echo "מעדכן N8N..."
                # בדיקה אם הסקריפט קיים
                if [ -f "/root/update-n8n.sh" ]; then
                    bash /root/update-n8n.sh
                elif [ -f "$HOME/update-n8n.sh" ]; then
                    bash $HOME/update-n8n.sh
                else
                    # ניסיון עדכון אוטומטי
                    echo "מנסה עדכון אוטומטי..."
                    if command -v n8n &>/dev/null; then
                        npm update -g n8n
                        pm2 restart n8n 2>/dev/null || true
                    elif docker ps | grep -q n8n; then
                        docker pull n8nio/n8n:latest
                        docker restart n8n
                    fi
                fi
                echo "העדכון הושלם!"
EOF
            ;;
            
        "update-waha.sh")
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'EOF'
                echo "מעדכן WAHA..."
                if [ -f "/root/update-waha.sh" ]; then
                    bash /root/update-waha.sh
                elif [ -f "$HOME/update-waha.sh" ]; then
                    bash $HOME/update-waha.sh
                else
                    # עדכון ידני של WAHA
                    echo "מעדכן WAHA באופן ידני..."
                    docker pull devlikeapro/waha
                    docker-compose down
                    docker-compose up -d
                fi
EOF
            ;;
            
        "update-chatwoot.sh")
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'EOF'
                echo "מעדכן Chatwoot..."
                if [ -f "/root/update-chatwoot.sh" ]; then
                    bash /root/update-chatwoot.sh
                elif [ -f "$HOME/update-chatwoot.sh" ]; then
                    bash $HOME/update-chatwoot.sh
                else
                    # עדכון ידני של Chatwoot
                    echo "מעדכן Chatwoot באופן ידני..."
                    cd /home/chatwoot/chatwoot
                    git pull
                    bundle install
                    yarn install
                    RAILS_ENV=production bundle exec rails db:migrate
                    systemctl restart chatwoot.target
                fi
EOF
            ;;
            
        "custom")
            # הרצת סקריפט מותאם אישית
            local custom_script=$(cat "$SCRIPTS_DIR/${server_id}_update.sh")
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" "$custom_script"
            ;;
            
        "general")
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" << 'EOF'
                echo "מבצע עדכון כללי..."
                sudo apt update
                sudo apt upgrade -y
                sudo apt autoremove -y
                echo "העדכון הושלם!"
EOF
            ;;
    esac
    
    success "העדכון הושלם!"
    
    # עדכון מטמון הסטטוס
    rm -f "$CACHE_DIR/status_${server_id}"
    check_server_status_async "$server_id"
    
    echo -e "\n${BOLD}לחץ Enter להמשך...${NC}"
    read -r
    update_servers_menu
}

# שמירת הגדרת עדכון לשרת
save_server_update_config() {
    local server_id="$1"
    local update_type="$2"
    
    case "$update_type" in
        "n8n-npm")
            cat > "$SCRIPTS_DIR/${server_id}_update.sh" << 'EOF'
#!/bin/bash
echo "מעדכן N8N (NPM)..."
npm update -g n8n
if command -v pm2 &>/dev/null; then
    pm2 restart n8n
    pm2 save
fi
echo "הושלם!"
EOF
            ;;
        "n8n-docker")
            cat > "$SCRIPTS_DIR/${server_id}_update.sh" << 'EOF'
#!/bin/bash
echo "מעדכן N8N (Docker)..."
docker pull n8nio/n8n:latest
docker stop n8n
docker rm n8n
docker run -d --restart always --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n n8nio/n8n:latest
echo "הושלם!"
EOF
            ;;
        "n8n-compose")
            cat > "$SCRIPTS_DIR/${server_id}_update.sh" << 'EOF'
#!/bin/bash
echo "מעדכן N8N (Docker Compose)..."
cd $(dirname $(find / -name "docker-compose.yml" -path "*/n8n/*" 2>/dev/null | head -1))
docker-compose pull
docker-compose down
docker-compose up -d
docker system prune -f
echo "הושלם!"
EOF
            ;;
    esac
    
    chmod +x "$SCRIPTS_DIR/${server_id}_update.sh"
    success "ההגדרה נשמרה לשימוש עתידי!"
}

# עדכון כל השרתים
update_all_servers() {
    print_header
    echo -e "${UPDATE} ${BOLD}מעדכן את כל השרתים${NC}\n"
    
    local total=${#SERVER_CACHE[@]}
    local current=0
    
    for server_id in "${!SERVER_CACHE[@]}"; do
        ((current++))
        source "${SERVER_CACHE[$server_id]}"
        
        echo -e "\n${CYAN}[$current/$total]${NC} מעדכן: ${WHITE}$SERVER_NAME${NC}"
        echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # בדיקה אם השרת אונליין
        if [[ "${STATUS_CACHE[$server_id]:-}" != "online" ]]; then
            warning "השרת לא זמין, מדלג..."
            continue
        fi
        
        quick_update_server "$server_id"
    done
    
    success "כל השרתים עודכנו!"
    echo -e "\n${BOLD}לחץ Enter להמשך...${NC}"
    read -r
    main_menu
}

# הגדרת סקריפט עדכון מותאם אישית
configure_update_script() {
    local server_id="${1:-}"
    
    if [[ -z "$server_id" ]]; then
        echo -e "\n${WHITE}בחר שרת להגדרת סקריפט:${NC}\n"
        local count=0
        declare -a server_list
        
        for sid in "${!SERVER_CACHE[@]}"; do
            source "${SERVER_CACHE[$sid]}"
            ((count++))
            server_list[$count]="$sid"
            echo -e "  ${BOLD}[$count]${NC} $SERVER_NAME"
        done
        
        echo -ne "\n${BOLD}בחירה: ${NC}"
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -le $count ]]; then
            server_id="${server_list[$choice]}"
        else
            return
        fi
    fi
    
    source "${SERVER_CACHE[$server_id]}"
    
    print_header
    echo -e "${GEAR} ${BOLD}הגדרת סקריפט עדכון ל: $SERVER_NAME${NC}\n"
    
    echo -e "${WHITE}בחר סוג סקריפט:${NC}\n"
    echo -e "  ${BOLD}[1]${NC} Docker Compose"
    echo -e "  ${BOLD}[2]${NC} NPM/Node.js"
    echo -e "  ${BOLD}[3]${NC} Python/pip"
    echo -e "  ${BOLD}[4]${NC} מותאם אישית"
    echo -e "  ${BOLD}[0]${NC} ביטול\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r type
    
    local script_content=""
    
    case "$type" in
        1)
            script_content="#!/bin/bash
cd /path/to/docker/compose
docker-compose pull
docker-compose down
docker-compose up -d
docker system prune -f"
            ;;
        2)
            script_content="#!/bin/bash
npm update -g package-name
pm2 restart app-name"
            ;;
        3)
            script_content="#!/bin/bash
pip install --upgrade package-name
systemctl restart service-name"
            ;;
        4)
            echo -e "\n${WHITE}הקלד את הסקריפט (סיים עם CTRL+D):${NC}"
            script_content=$(cat)
            ;;
        *)
            return
            ;;
    esac
    
    # שמירת הסקריפט
    echo "$script_content" > "$SCRIPTS_DIR/${server_id}_update.sh"
    chmod +x "$SCRIPTS_DIR/${server_id}_update.sh"
    
    success "הסקריפט נשמר!"
    
    echo -e "\n${YELLOW}לבדוק את הסקריפט עכשיו?${NC}"
    echo -ne "${BOLD}(כן/לא) [כן]: ${NC}"
    read -r test
    
    if [[ "$test" != "לא" ]] && [[ "$test" != "n" ]]; then
        quick_update_server "$server_id"
    fi
}

# ייבוא מפתח קיים
import_key() {
    print_header
    echo -e "${KEY} ${BOLD}ייבוא מפתח קיים${NC}\n"
    
    echo -e "${WHITE}מאיפה לייבא?${NC}\n"
    echo -e "  ${BOLD}[1]${NC} מקובץ במחשב"
    echo -e "  ${BOLD}[2]${NC} מטקסט (העתק/הדבק)"
    echo -e "  ${BOLD}[3]${NC} מ-GitHub/GitLab"
    echo -e "  ${BOLD}[0]${NC} ביטול\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    case "$choice" in
        1)
            echo -e "\n${WHITE}הקלד את הנתיב למפתח:${NC}"
            echo -ne "${BOLD}נתיב: ${NC}"
            read -r key_path
            
            if [[ -f "$key_path" ]]; then
                echo -ne "\n${WHITE}איך לקרוא למפתח? ${NC}"
                read -r key_name
                key_name=${key_name:-"imported_$(date +%Y%m%d)"}
                
                cp "$key_path" "$KEYS_DIR/$key_name"
                chmod 600 "$KEYS_DIR/$key_name"
                
                # בדיקה אם יש גם מפתח ציבורי
                if [[ -f "${key_path}.pub" ]]; then
                    cp "${key_path}.pub" "$KEYS_DIR/${key_name}.pub"
                else
                    ssh-keygen -y -f "$KEYS_DIR/$key_name" > "$KEYS_DIR/${key_name}.pub"
                fi
                
                success "המפתח יובא בהצלחה!"
            else
                error "קובץ לא נמצא"
            fi
            ;;
            
        2)
            echo -e "\n${WHITE}הדבק את המפתח הפרטי (סיים עם CTRL+D):${NC}"
            local key_content=$(cat)
            
            echo -ne "\n${WHITE}איך לקרוא למפתח? ${NC}"
            read -r key_name
            key_name=${key_name:-"imported_$(date +%Y%m%d)"}
            
            echo "$key_content" > "$KEYS_DIR/$key_name"
            chmod 600 "$KEYS_DIR/$key_name"
            ssh-keygen -y -f "$KEYS_DIR/$key_name" > "$KEYS_DIR/${key_name}.pub"
            
            success "המפתח יובא בהצלחה!"
            ;;
            
        3)
            echo -e "\n${WHITE}הקלד URL של המפתח:${NC}"
            echo -ne "${BOLD}URL: ${NC}"
            read -r url
            
            echo -ne "\n${WHITE}איך לקרוא למפתח? ${NC}"
            read -r key_name
            key_name=${key_name:-"imported_$(date +%Y%m%d)"}
            
            if curl -s "$url" -o "$KEYS_DIR/$key_name"; then
                chmod 600 "$KEYS_DIR/$key_name"
                ssh-keygen -y -f "$KEYS_DIR/$key_name" > "$KEYS_DIR/${key_name}.pub"
                success "המפתח יובא בהצלחה!"
            else
                error "לא הצלחתי להוריד את המפתח"
            fi
            ;;
    esac
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    keys_menu
}

# ניקוי מפתחות ישנים
clean_old_keys() {
    print_header
    echo -e "${TRASH} ${BOLD}ניקוי מפתחות ישנים${NC}\n"
    
    local old_count=0
    local unused_count=0
    
    echo -e "${CYAN}סורק מפתחות...${NC}\n"
    
    for key in "$KEYS_DIR"/*_key "$SSH_DIR"/id_*; do
        if [[ -f "$key" ]] && [[ "$key" != *.pub ]]; then
            local key_name=$(basename "$key")
            local age_days=$(( ($(date +%s) - $(stat -f %m "$key" 2>/dev/null || stat -c %Y "$key")) / 86400 ))
            
            # בדיקה אם המפתח בשימוש
            local in_use=false
            for server_id in "${!SERVER_CACHE[@]}"; do
                source "${SERVER_CACHE[$server_id]}"
                if [[ "$KEY_PATH" == "$key" ]]; then
                    in_use=true
                    break
                fi
            done
            
            if [[ $age_days -gt 365 ]]; then
                ((old_count++))
                echo -e "  ${YELLOW}${WARNING}${NC} $key_name - ${YELLOW}$age_days ימים${NC}"
            fi
            
            if [[ "$in_use" == "false" ]]; then
                ((unused_count++))
                echo -e "  ${DIM}✗${NC} $key_name - ${DIM}לא בשימוש${NC}"
            fi
        fi
    done
    
    if [[ $old_count -eq 0 ]] && [[ $unused_count -eq 0 ]]; then
        success "אין מפתחות ישנים או לא בשימוש!"
    else
        echo -e "\n${WHITE}נמצאו:${NC}"
        [[ $old_count -gt 0 ]] && echo -e "  • $old_count מפתחות מעל שנה"
        [[ $unused_count -gt 0 ]] && echo -e "  • $unused_count מפתחות לא בשימוש"
        
        echo -e "\n${YELLOW}מה לעשות?${NC}"
        echo -e "  ${BOLD}[1]${NC} מחק מפתחות לא בשימוש"
        echo -e "  ${BOLD}[2]${NC} ארכב מפתחות ישנים"
        echo -e "  ${BOLD}[3]${NC} נקה הכל"
        echo -e "  ${BOLD}[0]${NC} ביטול\n"
        
        echo -ne "${BOLD}בחירה: ${NC}"
        read -r action
        
        case "$action" in
            1) clean_unused_keys ;;
            2) archive_old_keys ;;
            3) clean_all_old_keys ;;
        esac
    fi
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    keys_menu
}

# המשך מהתחלה מהירה
quick_start() {
    print_header
    echo -e "${GREEN}${BOLD}${ROCKET} התחלה מהירה${NC}\n"
    
    echo -e "${WHITE}מה תרצה לעשות?${NC}\n"
    echo -e "  ${BOLD}[1]${NC} ${KEY} להתחבר לשרת חדש ${GREEN}(פשוט וקל)${NC}"
    echo -e "  ${BOLD}[2]${NC} ${LOCK} לתקן בעיית חיבור"
    echo -e "  ${BOLD}[3]${NC} ${SPARKLES} ליצור מפתח חדש"
    echo -e "  ${BOLD}[4]${NC} ${ARROW} מעבר מהיר בין שרתים"
    echo -e "  ${BOLD}[0]${NC} חזור\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    case $choice in
        1) easy_server_setup ;;
        2) fix_connection ;;
        3) create_key_wizard ;;
        4) server_switcher ;;
        0) main_menu ;;
        *) quick_start ;;
    esac
}

# בדיקת חיבור מתקדמת
check_connection() {
    print_header
    echo -e "${GLOBE} ${BOLD}בדיקת חיבור לשרת${NC}\n"
    
    echo -e "${WHITE}הקלד פרטי שרת לבדיקה:${NC}"
    echo -ne "\n${BOLD}כתובת IP/דומיין: ${NC}"
    read -r test_host
    
    echo -ne "${BOLD}פורט [22]: ${NC}"
    read -r test_port
    test_port=${test_port:-22}
    
    echo -e "\n${CYAN}בודק...${NC}\n"
    
    # בדיקת ping
    echo -ne "  ${DIM}Ping...${NC} "
    if ping -c 1 -W 2 "$test_host" &>/dev/null; then
        echo -e "${GREEN}${CHECK}${NC}"
    else
        echo -e "${RED}${CROSS}${NC}"
    fi
    
    # בדיקת פורט
    echo -ne "  ${DIM}Port $test_port...${NC} "
    if nc -z -w 2 "$test_host" "$test_port" 2>/dev/null; then
        echo -e "${GREEN}${CHECK}${NC}"
    else
        echo -e "${RED}${CROSS}${NC}"
    fi
    
    # בדיקת SSH
    echo -ne "  ${DIM}SSH Service...${NC} "
    if timeout 3 ssh -o ConnectTimeout=2 -o BatchMode=yes \
        -o StrictHostKeyChecking=no -p "$test_port" \
        "test@$test_host" 2>&1 | grep -q "Permission denied"; then
        echo -e "${GREEN}${CHECK}${NC}"
    else
        echo -e "${YELLOW}${WARNING}${NC}"
    fi
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    tools_menu
}

# המרת מפתח
convert_key() {
    print_header
    echo -e "${KEY} ${BOLD}המרת מפתח RSA ל-ED25519${NC}\n"
    
    echo -e "${WHITE}בחר מפתח להמרה:${NC}\n"
    
    local count=0
    declare -a key_list
    
    for key in "$KEYS_DIR"/*_key "$SSH_DIR"/id_rsa*; do
        if [[ -f "$key" ]] && [[ "$key" != *.pub ]]; then
            local key_type=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $4}')
            if [[ "$key_type" == "(RSA)" ]]; then
                ((count++))
                key_list[$count]="$key"
                echo -e "  ${BOLD}[$count]${NC} $(basename $key) ${DIM}$key_type${NC}"
            fi
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        info "אין מפתחות RSA להמרה"
    else
        echo -ne "\n${BOLD}בחר מפתח [1-$count]: ${NC}"
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -le $count ]]; then
            local old_key="${key_list[$choice]}"
            local new_key="${old_key}_ed25519"
            
            loading "ממיר מפתח"
            
            # יצירת מפתח חדש
            ssh-keygen -t ed25519 -f "$new_key" -N "" -q
            
            success "המפתח הומר בהצלחה!"
            echo -e "\n${WHITE}מפתח חדש: $new_key${NC}"
            echo -e "${YELLOW}${WARNING} אל תשכח לעדכן את השרתים עם המפתח החדש!${NC}"
        fi
    fi
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    tools_menu
}

# טיפים מתקדמים
show_tips() {
    print_header
    echo -e "${DIAMOND} ${BOLD}טיפים מתקדמים${NC}\n"
    
    local tips=(
        "השתמש ב-SSH Agent כדי לא להקליד סיסמה כל פעם"
        "הוסף 'ControlMaster auto' לקונפיג לחיבורים מהירים"
        "השתמש ב-~/.ssh/config לקיצורי דרך"
        "צור מפתח נפרד לכל שרת לאבטחה מקסימלית"
        "השתמש ב-fail2ban בשרת למניעת ניסיונות פריצה"
        "הפעל 2FA בשרת לאבטחה נוספת"
        "השתמש ב-ProxyJump לגישה דרך bastion host"
        "הגדר Port Forwarding עם -L או -R"
        "השתמש ב-sshfs להרכבת תיקיות מרוחקות"
        "צור tunnel עם -D ל-SOCKS proxy"
    )
    
    echo -e "${WHITE}${SPARKLES} טיפים אקראיים:${NC}\n"
    
    # בחירת 5 טיפים אקראיים
    for i in {1..5}; do
        local rand=$((RANDOM % ${#tips[@]}))
        echo -e "  ${BOLD}$i.${NC} ${tips[$rand]}"
        unset tips[$rand]
        tips=("${tips[@]}")
    done
    
    echo -e "\n${CYAN}${INFO} קיצורי מקלדת שימושיים ב-SSH:${NC}"
    echo -e "  ${BOLD}~.${NC}  - ניתוק מיידי"
    echo -e "  ${BOLD}~^Z${NC} - השהיית החיבור"
    echo -e "  ${BOLD}~&${NC}  - רקע לחיבור"
    echo -e "  ${BOLD}~?${NC}  - הצגת כל הקיצורים"
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    tools_menu
}

# הצגת גיבויים
list_backups() {
    print_header
    echo -e "${FOLDER} ${BOLD}גיבויים קיימים${NC}\n"
    
    local count=0
    for backup in "$BACKUP_DIR"/*.tar.gz*; do
        if [[ -f "$backup" ]]; then
            ((count++))
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -f %Sm -t "%d/%m/%Y %H:%M" "$backup" 2>/dev/null || \
                        stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1-2)
            
            echo -e "  ${BOLD}[$count]${NC} $(basename $backup)"
            echo -e "      ${DIM}גודל: $size | תאריך: $date${NC}"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        info "אין גיבויים"
    fi
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    backup_menu
}

# שחזור מגיבוי
restore_backup() {
    print_header
    echo -e "${UNLOCK} ${BOLD}שחזור מגיבוי${NC}\n"
    
    local count=0
    declare -a backup_list
    
    for backup in "$BACKUP_DIR"/*.tar.gz*; do
        if [[ -f "$backup" ]]; then
            ((count++))
            backup_list[$count]="$backup"
            echo -e "  ${BOLD}[$count]${NC} $(basename $backup)"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        info "אין גיבויים לשחזור"
    else
        echo -ne "\n${BOLD}בחר גיבוי [1-$count]: ${NC}"
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -le $count ]]; then
            local backup_file="${backup_list[$choice]}"
            
            warning "זה ידרוס קבצים קיימים!"
            echo -ne "${BOLD}להמשיך? (כן/לא) [לא]: ${NC}"
            read -r confirm
            
            if [[ "$confirm" == "כן" ]]; then
                loading "משחזר גיבוי"
                
                # בדיקה אם מוצפן
                if [[ "$backup_file" == *.enc ]]; then
                    echo -e "\n${LOCK} הקלד סיסמה לפענוח:"
                    openssl enc -aes-256-cbc -d -in "$backup_file" | tar -xzf - -C "$HOME"
                else
                    tar -xzf "$backup_file" -C "$HOME"
                fi
                
                success "הגיבוי שוחזר!"
                
                # רענון מטמון
                CACHE_LOADED=false
                SERVER_CACHE=()
                load_servers_cache
            fi
        fi
    fi
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    backup_menu
}

# ייצוא קונפיגורציה
export_config() {
    print_header
    echo -e "${CLOUD} ${BOLD}ייצוא להעברה${NC}\n"
    
    local export_file="$HOME/ssh_manager_export_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    loading "מכין חבילת ייצוא"
    
    tar -czf "$export_file" \
        -C "$HOME" \
        ".ssh/keys" \
        ".ssh/.server_*.conf" \
        ".ssh/config" \
        ".ssh/update_scripts" \
        2>/dev/null
    
    success "החבילה מוכנה!"
    echo -e "\n${WHITE}קובץ: $export_file${NC}"
    echo -e "${DIM}העבר את הקובץ למחשב החדש והרץ:${NC}"
    echo -e "${YELLOW}tar -xzf $(basename $export_file) -C \$HOME${NC}"
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    backup_menu
}

# פונקציות מקוריות שנשארו
easy_server_setup() {
    print_header
    echo -e "${GREEN}${BOLD}${ROCKET} הגדרת שרת חדש - מדריך פשוט${NC}\n"
    
    # שלב 1 - שם
    echo -e "${CYAN}${BOLD}שלב 1/4:${NC} ${WHITE}איך נקרא לשרת?${NC}"
    echo -e "${DIM}(למשל: השרת-שלי, n8n, waha, chatwoot)${NC}"
    echo -ne "\n${BOLD}שם: ${NC}"
    read -r server_name
    
    [[ -z "$server_name" ]] && server_name="שרת-חדש"
    local server_id=$(echo "$server_name" | tr ' ' '_' | sed 's/[^a-zA-Z0-9_-]//g')
    
    # שלב 2 - כתובת
    echo -e "\n${CYAN}${BOLD}שלב 2/4:${NC} ${WHITE}מה הכתובת?${NC}"
    echo -e "${DIM}(IP כמו 192.168.1.1 או דומיין כמו example.com)${NC}"
    echo -ne "\n${BOLD}כתובת: ${NC}"
    read -r server_host
    
    # שלב 3 - משתמש
    echo -e "\n${CYAN}${BOLD}שלב 3/4:${NC} ${WHITE}עם איזה משתמש להתחבר?${NC}"
    echo -e "${DIM}(לרוב: root, ubuntu, או המשתמש שקיבלת)${NC}"
    echo -ne "\n${BOLD}משתמש [root]: ${NC}"
    read -r server_user
    server_user=${server_user:-root}
    
    # שלב 4 - פורט
    echo -e "\n${CYAN}${BOLD}שלב 4/4:${NC} ${WHITE}איזה פורט?${NC}"
    echo -e "${DIM}(רוב השרתים: 22, לפעמים: 2222)${NC}"
    echo -ne "\n${BOLD}פורט [22]: ${NC}"
    read -r server_port
    server_port=${server_port:-22}
    
    # סיכום
    print_line
    echo -e "${GREEN}${BOLD}${CHECK} סיכום ההגדרות:${NC}\n"
    echo -e "  ${WHITE}שם:${NC}     $server_name"
    echo -e "  ${WHITE}כתובת:${NC}  $server_host"
    echo -e "  ${WHITE}משתמש:${NC}  $server_user"
    echo -e "  ${WHITE}פורט:${NC}   $server_port"
    print_line
    
    echo -e "\n${YELLOW}מה עכשיו?${NC}"
    echo -e "  ${BOLD}[1]${NC} ${GREEN}המשך${NC} - צור מפתח והתחבר"
    echo -e "  ${BOLD}[2]${NC} תקן פרטים"
    echo -e "  ${BOLD}[0]${NC} ביטול\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    case $choice in
        1)
            save_server "$server_id" "$server_host" "$server_user" "$server_port" "$server_name"
            # רענון מטמון
            SERVER_CACHE[$server_id]="$SSH_DIR/.server_${server_id}.conf"
            create_and_connect "$server_id"
            ;;
        2) easy_server_setup ;;
        0) main_menu ;;
    esac
}

# שאר הפונקציות המקוריות נשארות כמו שהן
save_server() {
    local id="$1"
    local host="$2"
    local user="$3"
    local port="$4"
    local name="${5:-$id}"
    
    cat > "$SSH_DIR/.server_${id}.conf" <<EOF
SERVER_ID="$id"
SERVER_NAME="$name"
SERVER_HOST="$host"
SERVER_USER="$user"
SERVER_PORT="$port"
KEY_PATH="$KEYS_DIR/${id}_key"
CREATED="$(date '+%Y-%m-%d %H:%M')"
EOF
    
    success "השרת '$name' נשמר"
}

load_server() {
    local server_file="$SSH_DIR/.server_${1}.conf"
    if [[ -f "$server_file" ]]; then
        source "$server_file"
        return 0
    else
        error "שרת לא נמצא: $1"
        return 1
    fi
}

create_and_connect() {
    local server_id="$1"
    
    print_header
    echo -e "${KEY} ${BOLD}יוצר מפתח חדש...${NC}\n"
    
    local key_path="$KEYS_DIR/${server_id}_key"
    
    # יצירת מפתח
    loading "יוצר מפתח מאובטח"
    ssh-keygen -t ed25519 -f "$key_path" -N "" -q -C "${server_id}@$(hostname)"
    
    success "מפתח נוצר בהצלחה!"
    
    # הצגת המפתח
    echo -e "\n${YELLOW}${KEY} המפתח הציבורי שלך:${NC}"
    print_line "─"
    echo -e "${GREEN}"
    cat "${key_path}.pub"
    echo -e "${NC}"
    print_line "─"
    
    # הוספה לשרת
    echo -e "\n${WHITE}${BOLD}איך להוסיף את המפתח לשרת?${NC}\n"
    echo -e "  ${BOLD}[1]${NC} יש לי סיסמה ${GREEN}(אוטומטי)${NC}"
    echo -e "  ${BOLD}[2]${NC} יש לי גישה בדרך אחרת"
    echo -e "  ${BOLD}[3]${NC} אעשה את זה בעצמי\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r method
    
    case $method in
        1) auto_add_key "$server_id" ;;
        2) manual_add_key "$server_id" ;;
        3) 
            info "העתק את המפתח למעלה והוסף אותו ל:"
            echo -e "${YELLOW}~/.ssh/authorized_keys${NC} בשרת"
            ;;
    esac
    
    echo -e "\n${BOLD}לחץ Enter להמשך...${NC}"
    read -r
    test_and_save "$server_id"
}

auto_add_key() {
    local server_id="$1"
    load_server "$server_id"
    
    echo -e "\n${YELLOW}${LOCK} מתחבר עם סיסמה...${NC}"
    echo -e "${DIM}(הקלד את הסיסמה של $SERVER_USER@$SERVER_HOST)${NC}\n"
    
    if ssh-copy-id -i "${KEY_PATH}.pub" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" 2>/dev/null; then
        success "המפתח נוסף בהצלחה!"
        return 0
    else
        error "לא הצלחתי להוסיף אוטומטית"
        manual_add_key "$server_id"
    fi
}

manual_add_key() {
    local server_id="$1"
    load_server "$server_id"
    
    local public_key=$(cat "${KEY_PATH}.pub")
    
    echo -e "\n${YELLOW}${INFO} הוראות להוספה ידנית:${NC}\n"
    echo -e "${WHITE}1. התחבר לשרת בדרך שיש לך${NC}"
    echo -e "${WHITE}2. הרץ את הפקודות הבאות:${NC}\n"
    
    print_line "─"
    echo -e "${GREEN}mkdir -p ~/.ssh"
    echo -e "echo '$public_key' >> ~/.ssh/authorized_keys"
    echo -e "chmod 600 ~/.ssh/authorized_keys${NC}"
    print_line "─"
    
    echo -e "\n${DIM}העתק והדבק את הפקודות בשרת${NC}"
}

test_and_save() {
    local server_id="$1"
    load_server "$server_id"
    
    echo -e "\n${CYAN}${GLOBE} בודק חיבור...${NC}"
    
    if ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
        -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
        "echo ''" 2>/dev/null; then
        
        success "מעולה! החיבור עובד!"
        
        # יצירת קיצור דרך
        setup_alias "$server_id"
        
        # עדכון מטמון
        STATUS_CACHE[$server_id]="online"
        
        echo -e "\n${GREEN}${SPARKLES} ${BOLD}הכל מוכן!${NC}"
        echo -e "\nעכשיו תוכל להתחבר עם:"
        echo -e "${YELLOW}${BOLD}ssh $server_id${NC}"
        
    else
        warning "החיבור לא עובד עדיין"
        echo -e "\n${WHITE}אפשרויות:${NC}"
        echo -e "  ${BOLD}[1]${NC} נסה שוב"
        echo -e "  ${BOLD}[2]${NC} הצג הוראות ידניות"
        echo -e "  ${BOLD}[0]${NC} המשך בכל זאת\n"
        
        echo -ne "${BOLD}בחירה: ${NC}"
        read -r choice
        
        case $choice in
            1) test_and_save "$server_id" ;;
            2) manual_add_key "$server_id" ;;
        esac
    fi
}

setup_alias() {
    local server_id="$1"
    load_server "$server_id"
    
    local ssh_config="$SSH_DIR/config"
    
    # מחיקת ערך ישן
    if grep -q "Host $server_id" "$ssh_config" 2>/dev/null; then
        sed -i.bak "/Host $server_id/,/^$/d" "$ssh_config"
    fi
    
    # הוספת קונפיגורציה
    cat >> "$ssh_config" <<EOF

# $SERVER_NAME
Host $server_id
    HostName $SERVER_HOST
    User $SERVER_USER
    Port $SERVER_PORT
    IdentityFile $KEY_PATH
    StrictHostKeyChecking no
    PasswordAuthentication no
EOF
}

# שאר הפונקציות הבסיסיות
fix_connection() {
    print_header
    echo -e "${YELLOW}${GEAR} ${BOLD}תיקון בעיות חיבור${NC}\n"
    
    echo -e "${WHITE}בחר את הבעיה:${NC}\n"
    echo -e "  ${BOLD}[1]${NC} Permission denied"
    echo -e "  ${BOLD}[2]${NC} Connection refused"
    echo -e "  ${BOLD}[3]${NC} Connection timeout"
    echo -e "  ${BOLD}[4]${NC} Host key verification failed"
    echo -e "  ${BOLD}[0]${NC} חזור\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    case $choice in
        1)
            info "בעיית Permission denied:"
            echo "• וודא שהמפתח הציבורי נוסף לשרת"
            echo "• בדוק את ההרשאות של ~/.ssh (צריך 700)"
            echo "• וודא שהמשתמש נכון"
            ;;
        2)
            info "בעיית Connection refused:"
            echo "• וודא שהשרת פועל"
            echo "• בדוק שהפורט נכון"
            echo "• וודא שאין חומת אש חוסמת"
            ;;
        3)
            info "בעיית Connection timeout:"
            echo "• בדוק את הכתובת IP/דומיין"
            echo "• וודא שאתה מחובר לרשת"
            echo "• בדוק חומת אש"
            ;;
        4)
            info "בעיית Host key verification:"
            echo -e "\nהרץ את הפקודה:"
            echo -e "${YELLOW}ssh-keygen -R [כתובת_השרת]${NC}"
            ;;
        0) quick_start ;;
    esac
    
    echo -e "\n${BOLD}לחץ Enter להמשך...${NC}"
    read -r
    quick_start
}

create_key_wizard() {
    print_header
    echo -e "${KEY} ${BOLD}יצירת מפתח חדש${NC}\n"
    
    # שם המפתח
    echo -e "${WHITE}איך לקרוא למפתח?${NC}"
    echo -e "${DIM}(למשל: personal, work, main)${NC}"
    echo -ne "\n${BOLD}שם: ${NC}"
    read -r key_name
    key_name=${key_name:-"key_$(date +%Y%m%d_%H%M%S)"}
    
    # רמת אבטחה
    echo -e "\n${WHITE}רמת אבטחה:${NC}\n"
    echo -e "  ${BOLD}[1]${NC} ${GREEN}רגילה${NC} - בלי סיסמה (נוח)"
    echo -e "  ${BOLD}[2]${NC} ${YELLOW}גבוהה${NC} - עם סיסמה (מאובטח)"
    echo -ne "\n${BOLD}בחירה [1]: ${NC}"
    read -r security
    security=${security:-1}
    
    local key_path="$KEYS_DIR/$key_name"
    local passphrase=""
    
    if [[ "$security" == "2" ]]; then
        echo -e "\n${YELLOW}הקלד סיסמה למפתח:${NC}"
        read -s -p "סיסמה: " passphrase
        echo
    fi
    
    # יצירת המפתח
    loading "יוצר מפתח"
    ssh-keygen -t ed25519 -f "$key_path" -N "$passphrase" -q -C "$key_name@$(hostname)"
    
    success "המפתח נוצר!"
    
    # הצגת המפתח
    echo -e "\n${WHITE}המפתח הציבורי:${NC}"
    print_line "─"
    echo -e "${GREEN}"
    cat "${key_path}.pub"
    echo -e "${NC}"
    print_line "─"
    
    echo -e "\n${BOLD}לחץ Enter להמשך...${NC}"
    read -r
    keys_menu
}

keys_menu() {
    print_header
    echo -e "${KEY} ${BOLD}המפתחות שלי${NC}\n"
    
    # רשימת מפתחות
    local count=0
    for key in "$KEYS_DIR"/*_key "$SSH_DIR"/id_*; do
        if [[ -f "$key" ]] && [[ "$key" != *.pub ]]; then
            ((count++))
            local key_name=$(basename "$key")
            local key_info=$(ssh-keygen -l -f "$key" 2>/dev/null)
            
            echo -e "  ${BOLD}[$count]${NC} ${KEY} $key_name"
            echo -e "      ${DIM}$key_info${NC}"
            echo
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        info "אין מפתחות"
    fi
    
    echo -e "\n${WHITE}פעולות:${NC}\n"
    echo -e "  ${BOLD}[1]${NC} צור מפתח חדש"
    echo -e "  ${BOLD}[2]${NC} ייבא מפתח"
    echo -e "  ${BOLD}[3]${NC} נקה מפתחות ישנים"
    echo -e "  ${BOLD}[0]${NC} חזור\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    case $choice in
        1) create_key_wizard ;;
        2) import_key ;;
        3) clean_old_keys ;;
        0) main_menu ;;
        *) keys_menu ;;
    esac
}

tools_menu() {
    print_header
    echo -e "${GEAR} ${BOLD}כלים וטיפים${NC}\n"
    
    echo -e "  ${BOLD}[1]${NC} ${SPARKLES} נקה known_hosts"
    echo -e "  ${BOLD}[2]${NC} ${LOCK} תקן הרשאות SSH"
    echo -e "  ${BOLD}[3]${NC} ${ROCKET} הפעל SSH Agent"
    echo -e "  ${BOLD}[4]${NC} ${GLOBE} בדוק חיבור לשרת"
    echo -e "  ${BOLD}[5]${NC} ${KEY} המר מפתח RSA ל-ED25519"
    echo -e "  ${BOLD}[6]${NC} ${DIAMOND} טיפים מתקדמים"
    echo -e "  ${BOLD}[0]${NC} חזור\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    case $choice in
        1) clean_known_hosts ;;
        2) fix_permissions ;;
        3) start_ssh_agent ;;
        4) check_connection ;;
        5) convert_key ;;
        6) show_tips ;;
        0) main_menu ;;
        *) tools_menu ;;
    esac
}

clean_known_hosts() {
    warning "זה ימחק את כל השרתים השמורים"
    echo -ne "\n${BOLD}להמשיך? (כן/לא) [לא]: ${NC}"
    read -r confirm
    
    if [[ "$confirm" == "כן" ]] || [[ "$confirm" == "y" ]]; then
        cp "$SSH_DIR/known_hosts" "$SSH_DIR/known_hosts.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null
        > "$SSH_DIR/known_hosts"
        success "נוקה! (גיבוי נשמר)"
    fi
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    tools_menu
}

fix_permissions() {
    loading "מתקן הרשאות"
    
    chmod 700 "$SSH_DIR" 2>/dev/null
    chmod 600 "$SSH_DIR"/* 2>/dev/null
    chmod 644 "$SSH_DIR"/*.pub 2>/dev/null
    chmod 644 "$SSH_DIR/config" 2>/dev/null
    chmod 700 "$KEYS_DIR" 2>/dev/null
    chmod 600 "$KEYS_DIR"/* 2>/dev/null
    
    success "ההרשאות תוקנו!"
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    tools_menu
}

start_ssh_agent() {
    echo -e "\n${CYAN}${ROCKET} מפעיל SSH Agent...${NC}\n"
    
    eval "$(ssh-agent -s)"
    
    local added=0
    for key in "$KEYS_DIR"/*_key "$SSH_DIR"/id_*; do
        if [[ -f "$key" ]] && [[ "$key" != *.pub ]]; then
            echo -ne "מוסיף $(basename $key)... "
            if ssh-add "$key" 2>/dev/null; then
                echo -e "${GREEN}${CHECK}${NC}"
                ((added++))
            else
                echo -e "${YELLOW}${WARNING} דרושה סיסמה${NC}"
            fi
        fi
    done
    
    success "נוספו $added מפתחות ל-Agent"
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    tools_menu
}

security_check() {
    print_header
    echo -e "${SHIELD} ${BOLD}בדיקת אבטחה${NC}\n"
    
    local score=100
    local issues=0
    
    loading "סורק את המערכת"
    echo
    
    # בדיקת הרשאות
    echo -ne "  בודק הרשאות... "
    if [[ $(stat -f %A "$SSH_DIR" 2>/dev/null || stat -c %a "$SSH_DIR") == "700" ]]; then
        echo -e "${GREEN}${CHECK}${NC}"
    else
        echo -e "${RED}${CROSS}${NC}"
        ((issues++))
        ((score-=20))
    fi
    
    # בדיקת מפתחות ללא סיסמה
    echo -ne "  בודק מפתחות... "
    local unprotected=0
    for key in "$KEYS_DIR"/*_key "$SSH_DIR"/id_*; do
        if [[ -f "$key" ]] && [[ "$key" != *.pub ]]; then
            if ssh-keygen -y -P "" -f "$key" &>/dev/null; then
                ((unprotected++))
            fi
        fi
    done
    
    if [[ $unprotected -eq 0 ]]; then
        echo -e "${GREEN}${CHECK}${NC}"
    else
        echo -e "${YELLOW}${WARNING} $unprotected ללא סיסמה${NC}"
        ((issues++))
        ((score-=10))
    fi
    
    # בדיקת גיל מפתחות
    echo -ne "  בודק גיל מפתחות... "
    local old_keys=0
    for key in "$KEYS_DIR"/*_key "$SSH_DIR"/id_*; do
        if [[ -f "$key" ]] && [[ "$key" != *.pub ]]; then
            local age=$(( ($(date +%s) - $(stat -f %m "$key" 2>/dev/null || stat -c %Y "$key")) / 86400 ))
            if [[ $age -gt 365 ]]; then
                ((old_keys++))
            fi
        fi
    done
    
    if [[ $old_keys -eq 0 ]]; then
        echo -e "${GREEN}${CHECK}${NC}"
    else
        echo -e "${YELLOW}${WARNING} $old_keys מעל שנה${NC}"
        ((issues++))
        ((score-=5))
    fi
    
    # ציון
    echo
    print_line "─"
    
    if [[ $score -ge 90 ]]; then
        echo -e "${GREEN}${SHIELD} ציון אבטחה: ${score}/100 - מצוין!${NC}"
    elif [[ $score -ge 70 ]]; then
        echo -e "${YELLOW}${SHIELD} ציון אבטחה: ${score}/100 - סביר${NC}"
    else
        echo -e "${RED}${SHIELD} ציון אבטחה: ${score}/100 - דורש שיפור${NC}"
    fi
    
    if [[ $issues -gt 0 ]]; then
        echo -e "\n${YELLOW}${INFO} נמצאו $issues נושאים לשיפור${NC}"
    fi
    
    echo -e "\n${BOLD}לחץ Enter להמשך...${NC}"
    read -r
    main_menu
}

backup_menu() {
    print_header
    echo -e "${SAVE} ${BOLD}גיבוי ושחזור${NC}\n"
    
    echo -e "  ${BOLD}[1]${NC} ${SAVE} גבה הכל עכשיו"
    echo -e "  ${BOLD}[2]${NC} ${FOLDER} הצג גיבויים קיימים"
    echo -e "  ${BOLD}[3]${NC} ${UNLOCK} שחזר מגיבוי"
    echo -e "  ${BOLD}[4]${NC} ${CLOUD} ייצא להעברה למחשב אחר"
    echo -e "  ${BOLD}[0]${NC} חזור\n"
    
    echo -ne "${BOLD}בחירה: ${NC}"
    read -r choice
    
    case $choice in
        1) create_backup ;;
        2) list_backups ;;
        3) restore_backup ;;
        4) export_config ;;
        0) main_menu ;;
        *) backup_menu ;;
    esac
}

create_backup() {
    print_header
    echo -e "${SAVE} ${BOLD}יוצר גיבוי...${NC}\n"
    
    local backup_name="ssh_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name.tar.gz"
    
    loading "אוסף קבצים"
    
    # יצירת גיבוי
    tar -czf "$backup_path" \
        -C "$HOME" \
        ".ssh/keys" \
        ".ssh/.server_*.conf" \
        ".ssh/config" \
        ".ssh/update_scripts" \
        2>/dev/null
    
    success "הגיבוי נוצר!"
    echo -e "  ${FOLDER} $backup_path"
    
    echo -e "\n${YELLOW}להצפין את הגיבוי?${NC}"
    echo -ne "${BOLD}(כן/לא) [כן]: ${NC}"
    read -r encrypt
    encrypt=${encrypt:-כן}
    
    if [[ "$encrypt" == "כן" ]] || [[ "$encrypt" == "y" ]]; then
        echo -e "\n${LOCK} הקלד סיסמה להצפנה:"
        openssl enc -aes-256-cbc -salt -in "$backup_path" -out "${backup_path}.enc"
        rm "$backup_path"
        success "הגיבוי הוצפן!"
        warning "אל תשכח את הסיסמה!"
    fi
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    backup_menu
}

show_help() {
    print_header
    echo -e "${INFO} ${BOLD}עזרה${NC}\n"
    
    echo -e "${WHITE}${BOLD}מה זה SSH?${NC}"
    echo "פרוטוקול מאובטח להתחברות לשרתים מרוחקים."
    echo "משתמשים במפתחות במקום סיסמאות - יותר בטוח!"
    
    echo -e "\n${WHITE}${BOLD}איך זה עובד?${NC}"
    echo "1. יוצרים זוג מפתחות (ציבורי ופרטי)"
    echo "2. מוסיפים את הציבורי לשרת"
    echo "3. מתחברים עם הפרטי"
    
    echo -e "\n${WHITE}${BOLD}החידושים בגרסה 4.0:${NC}"
    echo "• ${LIGHTNING} טעינה מהירה עם מטמון"
    echo "• ${ARROW} מעבר מהיר בין שרתים"
    echo "• ${UPDATE} עדכון אוטומטי של שרתים"
    echo "• ${ROCKET} ממשק משופר וידידותי"
    
    echo -e "\n${WHITE}${BOLD}טיפים חשובים:${NC}"
    echo "• ${RED}לעולם${NC} אל תשתף מפתח פרטי"
    echo "• גבה מפתחות באופן קבוע"
    echo "• החלף מפתחות אחת לשנה"
    echo "• השתמש ב-~ למעבר מהיר בין שרתים"
    
    echo -e "\n${BOLD}לחץ Enter...${NC}"
    read -r
    main_menu
}

goodbye() {
    print_header
    echo -e "${GREEN}${SPARKLES} ${BOLD}תודה שהשתמשת ב-SSH Manager Pro 4.0!${NC}\n"
    echo -e "${DIM}פותח עם ❤️ למשתמשי SSH${NC}\n"
    echo "להתראות! 👋"
    echo
    exit 0
}

# הפעלת התוכנית
trap 'echo -e "\n${YELLOW}להתראות!${NC}"; exit 0' INT TERM

# ברוכים הבאים בפעם הראשונה
if [[ ! -f "$SSH_DIR/.ssh_manager_welcome_v4" ]]; then
    print_header
    echo -e "${GREEN}${SPARKLES} ${BOLD}ברוך הבא ל-SSH Manager Pro 4.0!${NC}\n"
    echo -e "${WHITE}כלי מתקדם לניהול מפתחות וחיבורי SSH${NC}"
    echo -e "${DIM}גרסה 4.0 - עברית מלאה עם שיפורי ביצועים${NC}\n"
    
    echo -e "${CYAN}${INFO} מה חדש בגרסה 4.0?${NC}"
    echo "  ${LIGHTNING} טעינה מהירה במיוחד"
    echo "  ${ARROW} מעבר חלק בין שרתים"
    echo "  ${UPDATE} עדכון אוטומטי לשרתים"
    echo "  ${SPARKLES} ממשק משופר וידידותי"
    
    echo -e "\n${BOLD}לחץ Enter להתחיל...${NC}"
    read -r
    touch "$SSH_DIR/.ssh_manager_welcome_v4"
fi

# לולאה ראשית
while true; do
    main_menu
done
