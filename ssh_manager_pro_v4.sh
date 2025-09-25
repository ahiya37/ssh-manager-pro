#!/bin/bash

# מנהל SSH מגניב - גרסת מק
# פשוט, כיפי, עובד!

# צבעים
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# אמוג'ים
ROCKET="🚀"
KEY="🔑"
UPDATE="🔄"
CHECK="✅"
COMPUTER="💻"
FIRE="🔥"
SPARKLES="✨"
LIGHTNING="⚡"
PARTY="🎉"
STAR="⭐"

# הגדרות
SSH_DIR="$HOME/.ssh"
KEYS_DIR="$SSH_DIR/keys"

# פונקציות עיצוב
print_header() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${FIRE} ${BOLD}מנהל השרתים המגניב שלך${NC} ${FIRE}  ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
    echo ""
}

# תפריט ראשי
main_menu() {
    print_header
    
    echo -e "${WHITE}${BOLD}מה נעשה היום?${NC}\n"
    
    echo -e "  ${GREEN}${BOLD}[1]${NC} ${ROCKET} להתחבר מהר לשרת"
    echo -e "  ${BLUE}${BOLD}[2]${NC} ${UPDATE} לעדכן שרתים"
    echo -e "  ${PURPLE}${BOLD}[3]${NC} ${COMPUTER} לראות את כל השרתים"
    echo -e "  ${YELLOW}${BOLD}[4]${NC} ${SPARKLES} להוסיף שרת חדש"
    echo -e "  ${CYAN}${BOLD}[5]${NC} ${KEY} ליצור מפתח חדש"
    echo -e "  ${WHITE}${BOLD}[6]${NC} ${LIGHTNING} מעבר מהיר בין שרתים"
    echo -e "  ${RED}${BOLD}[0]${NC} יציאה\n"
    
    echo -ne "${BOLD}הבחירה שלך: ${NC}"
    read -r choice
    
    case $choice in
        1) quick_connect ;;
        2) update_servers ;;
        3) show_all_servers ;;
        4) add_new_server ;;
        5) create_new_key ;;
        6) server_switcher ;;
        0) goodbye ;;
        *) main_menu ;;
    esac
}

# חיבור מהיר
quick_connect() {
    print_header
    echo -e "${GREEN}${ROCKET} ${BOLD}בוא נתחבר לשרת!${NC}\n"
    
    count=0
    declare -a servers
    
    for conf in "$SSH_DIR"/.server_*.conf; do
        if [[ -f "$conf" ]]; then
            source "$conf"
            ((count++))
            servers[$count]="$conf"
            
            echo -e "  ${BOLD}${GREEN}[$count]${NC} ${STAR} ${WHITE}$SERVER_NAME${NC}"
            echo -e "      ${CYAN}$SERVER_USER@$SERVER_HOST${NC}"
            echo ""
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}אופס! אין לך שרתים עדיין${NC}"
        echo -e "${WHITE}רוצה להוסיף? לחץ ${GREEN}4${NC} בתפריט הראשי${NC}\n"
        read -p "לחץ אנטר לחזור..."
        main_menu
        return
    fi
    
    echo -ne "${BOLD}איזה שרת? (1-$count): ${NC}"
    read -r num
    
    if [[ $num -ge 1 && $num -le $count ]]; then
        source "${servers[$num]}"
        echo -e "\n${GREEN}${ROCKET} ${BOLD}ממריאים ל-$SERVER_NAME!${NC}\n"
        sleep 1
        ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST"
        
        echo -e "\n${CYAN}חזרת! מה עכשיו?${NC}"
        echo -e "${BOLD}[1]${NC} להתחבר שוב"
        echo -e "${BOLD}[2]${NC} לשרת אחר"
        echo -e "${BOLD}[0]${NC} לתפריט ראשי"
        
        read -r after
        case $after in
            1) quick_connect ;;
            2) server_switcher ;;
            *) main_menu ;;
        esac
    else
        quick_connect
    fi
}

# עדכון שרתים
update_servers() {
    print_header
    echo -e "${BLUE}${UPDATE} ${BOLD}בוא נעדכן שרתים!${NC}\n"
    
    count=0
    declare -a servers
    
    for conf in "$SSH_DIR"/.server_*.conf; do
        if [[ -f "$conf" ]]; then
            source "$conf"
            ((count++))
            servers[$count]="$conf"
            
            # זיהוי סוג שרת
            local type="${WHITE}כללי${NC}"
            [[ "$SERVER_NAME" == *n8n* ]] || [[ "$SERVER_NAME" == *N8N* ]] && type="${PURPLE}N8N${NC}"
            [[ "$SERVER_NAME" == *waha* ]] || [[ "$SERVER_NAME" == *WAHA* ]] && type="${GREEN}WAHA${NC}"
            [[ "$SERVER_NAME" == *chatwoot* ]] || [[ "$SERVER_NAME" == *Chatwoot* ]] && type="${BLUE}Chatwoot${NC}"
            
            echo -e "  ${BOLD}[$count]${NC} $SERVER_NAME - $type"
        fi
    done
    
    echo -e "\n${BOLD}[A]${NC} ${FIRE} לעדכן את כולם!"
    echo -e "${BOLD}[0]${NC} חזרה"
    
    echo -ne "\n${BOLD}מה לעדכן? ${NC}"
    read -r choice
    
    if [[ "$choice" == "A" ]] || [[ "$choice" == "a" ]]; then
        update_all_servers
    elif [[ "$choice" == "0" ]]; then
        main_menu
    elif [[ $choice -ge 1 && $choice -le $count ]]; then
        source "${servers[$choice]}"
        echo -e "\n${UPDATE} מעדכן את ${BOLD}$SERVER_NAME${NC}..."
        
        # זיהוי אוטומטי וביצוע עדכון
        if [[ "$SERVER_NAME" == *n8n* ]] || [[ "$SERVER_NAME" == *N8N* ]]; then
            echo -e "${PURPLE}מעדכן N8N...${NC}"
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
                "npm update -g n8n && pm2 restart n8n || docker pull n8nio/n8n && docker restart n8n"
        elif [[ "$SERVER_NAME" == *waha* ]] || [[ "$SERVER_NAME" == *WAHA* ]]; then
            echo -e "${GREEN}מעדכן WAHA...${NC}"
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
                "docker pull devlikeapro/waha && docker-compose restart"
        elif [[ "$SERVER_NAME" == *chatwoot* ]] || [[ "$SERVER_NAME" == *Chatwoot* ]]; then
            echo -e "${BLUE}מעדכן Chatwoot...${NC}"
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
                "cd chatwoot && git pull && bundle install && systemctl restart chatwoot.target"
        else
            echo -e "${WHITE}עדכון כללי...${NC}"
            ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
                "apt update && apt upgrade -y"
        fi
        
        echo -e "\n${GREEN}${CHECK} העדכון הושלם!${NC}"
        read -p "לחץ אנטר להמשך..."
        update_servers
    fi
}

# עדכון כל השרתים
update_all_servers() {
    for conf in "$SSH_DIR"/.server_*.conf; do
        if [[ -f "$conf" ]]; then
            source "$conf"
            echo -e "\n${UPDATE} מעדכן ${BOLD}$SERVER_NAME${NC}..."
            
            if [[ "$SERVER_NAME" == *n8n* ]]; then
                ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST" \
                    "npm update -g n8n && pm2 restart n8n" 2>/dev/null || echo "דילוג..."
            fi
            
            echo -e "${GREEN}${CHECK}${NC}"
        fi
    done
    
    echo -e "\n${PARTY} ${BOLD}כל השרתים עודכנו!${NC}"
    read -p "לחץ אנטר להמשך..."
    main_menu
}

# הצג את כל השרתים
show_all_servers() {
    print_header
    echo -e "${PURPLE}${COMPUTER} ${BOLD}השרתים שלך:${NC}\n"
    
    count=0
    for conf in "$SSH_DIR"/.server_*.conf; do
        if [[ -f "$conf" ]]; then
            source "$conf"
            ((count++))
            
            # בדיקת סטטוס
            if timeout 2 ssh -o BatchMode=yes -o ConnectTimeout=1 \
                -i "$KEY_PATH" -p "$SERVER_PORT" \
                "$SERVER_USER@$SERVER_HOST" true 2>/dev/null; then
                status="${GREEN}● פעיל${NC}"
            else
                status="${RED}● לא פעיל${NC}"
            fi
            
            echo -e "${BOLD}$count.${NC} $status ${WHITE}$SERVER_NAME${NC}"
            echo -e "   ${CYAN}$SERVER_USER@$SERVER_HOST:$SERVER_PORT${NC}"
            echo ""
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}אין שרתים עדיין${NC}"
    fi
    
    read -p "לחץ אנטר לחזור..."
    main_menu
}

# הוסף שרת חדש
add_new_server() {
    print_header
    echo -e "${YELLOW}${SPARKLES} ${BOLD}בוא נוסיף שרת חדש!${NC}\n"
    
    echo -ne "${WHITE}איך נקרא לו? ${NC}"
    read -r server_name
    
    echo -ne "${WHITE}מה הכתובת? (IP או דומיין): ${NC}"
    read -r server_host
    
    echo -ne "${WHITE}איזה משתמש? [root]: ${NC}"
    read -r server_user
    server_user=${server_user:-root}
    
    echo -ne "${WHITE}איזה פורט? [22]: ${NC}"
    read -r server_port
    server_port=${server_port:-22}
    
    # יצירת ID
    server_id=$(echo "$server_name" | tr ' ' '_' | sed 's/[^a-zA-Z0-9_-]//g')
    key_path="$KEYS_DIR/${server_id}_key"
    
    # יצירת מפתח
    echo -e "\n${KEY} ${BOLD}יוצר מפתח חדש...${NC}"
    ssh-keygen -t ed25519 -f "$key_path" -N "" -q
    
    # שמירת הגדרות
    cat > "$SSH_DIR/.server_${server_id}.conf" <<EOF
SERVER_ID="$server_id"
SERVER_NAME="$server_name"
SERVER_HOST="$server_host"
SERVER_USER="$server_user"
SERVER_PORT="$server_port"
KEY_PATH="$key_path"
CREATED="$(date '+%Y-%m-%d %H:%M')"
EOF
    
    echo -e "\n${GREEN}${CHECK} ${BOLD}מעולה! השרת נוסף!${NC}"
    echo -e "\n${YELLOW}המפתח הציבורי שלך:${NC}"
    echo -e "${CYAN}$(cat ${key_path}.pub)${NC}"
    echo -e "\n${WHITE}תוסיף אותו לשרת ב-~/.ssh/authorized_keys${NC}"
    
    read -p "לחץ אנטר להמשך..."
    main_menu
}

# יצירת מפתח חדש
create_new_key() {
    print_header
    echo -e "${KEY} ${BOLD}יצירת מפתח חדש${NC}\n"
    
    echo -ne "${WHITE}שם למפתח: ${NC}"
    read -r key_name
    key_name=${key_name:-"key_$(date +%Y%m%d)"}
    
    key_path="$KEYS_DIR/$key_name"
    
    echo -e "\n${SPARKLES} יוצר מפתח..."
    ssh-keygen -t ed25519 -f "$key_path" -N "" -q
    
    echo -e "\n${GREEN}${CHECK} המפתח נוצר!${NC}"
    echo -e "\n${WHITE}המפתח הציבורי:${NC}"
    echo -e "${CYAN}$(cat ${key_path}.pub)${NC}"
    
    read -p "לחץ אנטר להמשך..."
    main_menu
}

# מעבר בין שרתים
server_switcher() {
    print_header
    echo -e "${LIGHTNING} ${BOLD}מעבר מהיר בין שרתים${NC}\n"
    
    count=0
    declare -a servers
    
    for conf in "$SSH_DIR"/.server_*.conf; do
        if [[ -f "$conf" ]]; then
            source "$conf"
            ((count++))
            servers[$count]="$conf"
            echo -e "  ${BOLD}[$count]${NC} $SERVER_NAME"
        fi
    done
    
    echo -ne "\n${BOLD}לאיזה שרת? ${NC}"
    read -r num
    
    if [[ $num -ge 1 && $num -le $count ]]; then
        source "${servers[$num]}"
        echo -e "\n${ROCKET} עוברים ל-${BOLD}$SERVER_NAME${NC}!\n"
        ssh -i "$KEY_PATH" -p "$SERVER_PORT" "$SERVER_USER@$SERVER_HOST"
        server_switcher
    else
        main_menu
    fi
}

# יציאה
goodbye() {
    echo -e "\n${PARTY} ${BOLD}להתראות! תודה שהשתמשת!${NC}"
    echo -e "${SPARKLES} נתראה בפעם הבאה! ${SPARKLES}\n"
    exit 0
}

# התחלה
main_menu
