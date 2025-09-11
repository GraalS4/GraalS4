#!/bin/bash

# ====================================================================
# 🎮 SCRIPT AUTOMAZIONE SERVER MINECRAFT CODESPACES
# ====================================================================
# Questo script automatizza completamente l'avvio del server e 
# fornisce sempre l'indirizzo aggiornato ai tuoi amici
# ====================================================================

set -e  # Esci se qualsiasi comando fallisce

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configurazione
SERVER_NAME="🎮 Server Minecraft di $(whoami)"
MINECRAFT_DIR="minecraft-server"
SERVER_INFO_FILE="server-info.txt"
DISCORD_WEBHOOK_URL=""  # Opzionale: inserisci webhook Discord per notifiche

# ====================================================================
# FUNZIONI UTILITY
# ====================================================================

print_banner() {
    echo -e "${PURPLE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                🎮 MINECRAFT SERVER CODESPACES 🎮          ║"
    echo "║                    Automazione Completa                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
    echo "----------------------------------------"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# ====================================================================
# FUNZIONI PRINCIPALI
# ====================================================================

check_requirements() {
    print_section "Controllo Requisiti"
    
    # Controlla Java
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        print_success "Java installato: $JAVA_VERSION"
    else
        print_error "Java non trovato. Installazione in corso..."
        sudo apt update
        sudo apt install -y openjdk-17-jdk
        print_success "Java installato con successo"
    fi

    # Controlla directory server
    if [ ! -d "$MINECRAFT_DIR" ]; then
        print_warning "Directory server non trovata. Creazione in corso..."
        mkdir -p "$MINECRAFT_DIR"
    fi
}

setup_forge_server() {
    print_section "Configurazione Server Forge"
    
    cd "$MINECRAFT_DIR"
    
    # Scarica Forge installer se non esiste
    if [ ! -f "forge-1.20.1-47.4.0-installer.jar" ]; then
        print_info "Download Forge Installer..."
        wget -q "https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.0/forge-1.20.1-47.4.0-installer.jar"
        print_success "Forge Installer scaricato"
    fi
    
    # Installa server se non esiste run.sh
    if [ ! -f "run.sh" ]; then
        print_info "Installazione server Forge..."
        java -jar forge-1.20.1-47.4.0-installer.jar --installServer > /dev/null 2>&1
        print_success "Server Forge installato"
    fi
    
    # Accetta EULA
    echo "eula=true" > eula.txt
    print_success "EULA accettato"
    
    # Configura parametri JVM ottimizzati
    cat > user_jvm_args.txt << 'EOF'
-Xms4G
-Xmx12G
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=4
-XX:SurvivorRatio=32
-XX:MaxTenuringThreshold=1
EOF
    print_success "Parametri JVM configurati (4-12GB RAM)"
    
    # Configura server.properties
    cat > server.properties << 'EOF'
server-port=25565
gamemode=survival
difficulty=normal
max-players=20
online-mode=false
enable-command-block=true
motd=§6🎮 Server Minecraft su GitHub Codespaces §r§7| §aBenvenuti!
view-distance=12
spawn-protection=0
allow-flight=false
enable-rcon=false
enforce-whitelist=false
pvp=true
level-type=minecraft\:normal
level-seed=
generate-structures=true
spawn-monsters=true
spawn-animals=true
spawn-npcs=true
EOF
    print_success "Configurazione server completata"
    
    cd ..
}

start_minecraft_server() {
    print_section "Avvio Server Minecraft"
    
    cd "$MINECRAFT_DIR"
    
    # Controlla se il server è già in esecuzione
    if pgrep -f "java.*forge" > /dev/null; then
        print_warning "Server già in esecuzione. Riavvio in corso..."
        pkill -f "java.*forge"
        sleep 3
    fi
    
    # Rimuovi lock file se esiste
    [ -f "world/session.lock" ] && rm -f world/session.lock
    
    print_info "Avvio server in background..."
    nohup ./run.sh nogui > server.log 2>&1 &
    SERVER_PID=$!
    
    print_success "Server avviato con PID: $SERVER_PID"
    
    # Aspetta che il server si avvii
    print_info "Attesa avvio server (30 secondi)..."
    sleep 30
    
    cd ..
}

configure_port_forwarding() {
    print_section "Configurazione Port Forwarding"
    
    # Usa gh CLI se disponibile
    if command -v gh &> /dev/null; then
        print_info "Configurazione automatica port forwarding..."
        gh codespace ports visibility 25565:public --codespace "$CODESPACE_NAME" 2>/dev/null || {
            print_warning "Impossibile configurare automaticamente. Configura manualmente:"
            print_info "1. Vai nella tab 'PORTE' in VSCode"
            print_info "2. Trova la porta 25565"
            print_info "3. Cambia visibilità da 'Private' a 'Public'"
        }
    else
        print_warning "gh CLI non disponibile. Configurazione manuale necessaria:"
        print_info "1. Vai nella tab 'PORTE' in VSCode"
        print_info "2. Trova la porta 25565"  
        print_info "3. Cambia visibilità da 'Private' a 'Public'"
    fi
}

get_server_info() {
    print_section "Informazioni Server"
    
    # Ottieni informazioni del server
    local codespace_url=""
    local public_ip=""
    
    # Prova a ottenere URL Codespace
    if command -v gh &> /dev/null && [ -n "$CODESPACE_NAME" ]; then
        codespace_url=$(gh codespace ports --codespace "$CODESPACE_NAME" 2>/dev/null | grep 25565 | awk '{print $2}' | sed 's/https:\/\///' || echo "")
    fi
    
    # Ottieni IP pubblico
    public_ip=$(curl -s ifconfig.me 2>/dev/null || echo "N/A")
    
    # Crea file informazioni server
    cat > "$SERVER_INFO_FILE" << EOF
🎮 INFORMAZIONI SERVER MINECRAFT
================================

📍 INDIRIZZO PRINCIPALE (Raccomandato):
   Server: $codespace_url
   Porta: 25565

📍 INDIRIZZO IP ALTERNATIVO:
   IP: $public_ip
   Porta: 25565
   Nota: Potrebbe non funzionare a causa del firewall

🕒 Ultimo aggiornamento: $(date)
🖥️ Codespace: $CODESPACE_NAME

⚠️ IMPORTANTE:
- L'indirizzo principale cambia ad ogni riavvio del Codespace
- Esegui questo script ogni volta che riavvii il Codespace
- Condividi sempre l'indirizzo più recente con i tuoi amici

🔧 STATO SERVER:
- RAM: 4-12GB allocati
- CPU: Condivisi
- Versione: Forge 1.20.1-47.4.0
- Online: $(pgrep -f "java.*forge" > /dev/null && echo "✅ SI" || echo "❌ NO")
================================
EOF

    print_success "Informazioni server salvate in: $SERVER_INFO_FILE"
    
    # Mostra informazioni
    cat "$SERVER_INFO_FILE"
    
    # Salva per script rapido
    if [ -n "$codespace_url" ]; then
        echo "$codespace_url" > server-address.txt
        print_success "Indirizzo rapido salvato in: server-address.txt"
    fi
}

send_discord_notification() {
    if [ -n "$DISCORD_WEBHOOK_URL" ] && command -v curl &> /dev/null; then
        local server_address=$(cat server-address.txt 2>/dev/null || echo "N/A")
        
        curl -H "Content-Type: application/json" \
             -d "{\"content\": \"🎮 **Server Minecraft avviato!**\n📍 Indirizzo: \`$server_address:25565\`\n🕒 $(date)\"}" \
             "$DISCORD_WEBHOOK_URL" &>/dev/null
        
        print_success "Notifica Discord inviata"
    fi
}

create_helper_scripts() {
    print_section "Creazione Script Helper"
    
    # Script per ottenere indirizzo server
    cat > get-server-address.sh << 'EOF'
#!/bin/bash
echo "🎮 INDIRIZZO SERVER MINECRAFT"
echo "=============================="
if [ -f "server-info.txt" ]; then
    grep -A 10 "INDIRIZZO PRINCIPALE" server-info.txt
else
    echo "❌ Server non configurato. Esegui: ./setup-minecraft.sh"
fi
echo "=============================="
EOF
    chmod +x get-server-address.sh
    
    # Script per riavviare server
    cat > restart-server.sh << 'EOF'
#!/bin/bash
echo "🔄 Riavvio server..."
cd minecraft-server
pkill -f "java.*forge" 2>/dev/null || true
sleep 3
rm -f world/session.lock
nohup ./run.sh nogui > server.log 2>&1 &
echo "✅ Server riavviato!"
sleep 10
cd ..
./get-server-address.sh
EOF
    chmod +x restart-server.sh
    
    # Script per fermare server
    cat > stop-server.sh << 'EOF'
#!/bin/bash
echo "🛑 Fermando server..."
pkill -f "java.*forge" 2>/dev/null && echo "✅ Server fermato" || echo "❌ Nessun server attivo"
EOF
    chmod +x stop-server.sh
    
    # Script per vedere log
    cat > view-logs.sh << 'EOF'
#!/bin/bash
echo "📄 LOG SERVER (ultimi 50 righe):"
echo "================================="
if [ -f "minecraft-server/server.log" ]; then
    tail -50 minecraft-server/server.log
else
    echo "❌ File di log non trovato"
fi
EOF
    chmod +x view-logs.sh
    
    print_success "Script helper creati:"
    print_info "  • get-server-address.sh - Mostra indirizzo server"
    print_info "  • restart-server.sh - Riavvia server"
    print_info "  • stop-server.sh - Ferma server"
    print_info "  • view-logs.sh - Mostra log server"
}

create_devcontainer_config() {
    print_section "Configurazione Devcontainer"
    
    mkdir -p .devcontainer
    
    cat > .devcontainer/devcontainer.json << 'EOF'
{
    "name": "Minecraft Server",
    "image": "mcr.microsoft.com/devcontainers/universal:2",
    "postStartCommand": "bash setup-minecraft.sh --auto",
    "forwardPorts": [25565],
    "portsAttributes": {
        "25565": {
            "label": "Minecraft Server",
            "protocol": "tcp",
            "visibility": "public"
        }
    },
    "customizations": {
        "vscode": {
            "settings": {
                "terminal.integrated.defaultProfile.linux": "bash"
            },
            "extensions": [
                "ms-vscode.vscode-terminal"
            ]
        }
    }
}
EOF
    
    print_success "Configurazione devcontainer creata"
    print_info "Il server si avvierà automaticamente al prossimo avvio del Codespace"
}

# ====================================================================
# FUNZIONE PRINCIPALE
# ====================================================================

main() {
    print_banner
    
    # Parsing argomenti
    AUTO_MODE=false
    if [[ "$1" == "--auto" ]]; then
        AUTO_MODE=true
        print_info "Modalità automatica attivata"
    fi
    
    # Esecuzione step
    check_requirements
    setup_forge_server
    start_minecraft_server
    configure_port_forwarding
    
    # Aspetta un po' per il port forwarding
    if [[ "$AUTO_MODE" == false ]]; then
        print_info "Aspetta 10 secondi per il port forwarding..."
        sleep 10
    fi
    
    get_server_info
    send_discord_notification
    create_helper_scripts
    
    if [[ "$AUTO_MODE" == false ]]; then
        create_devcontainer_config
    fi
    
    # Messaggio finale
    echo -e "\n${GREEN}🎉 CONFIGURAZIONE COMPLETATA! 🎉${NC}"
    echo -e "${YELLOW}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│             COMANDI UTILI:                  │${NC}"
    echo -e "${YELLOW}├─────────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}│  ./get-server-address.sh  - Indirizzo       │${NC}"
    echo -e "${YELLOW}│  ./restart-server.sh      - Riavvia         │${NC}"
    echo -e "${YELLOW}│  ./stop-server.sh         - Ferma           │${NC}"
    echo -e "${YELLOW}│  ./view-logs.sh           - Log server      │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────┘${NC}"
    
    if [ -f "server-address.txt" ]; then
        echo -e "\n${PURPLE}📍 INDIRIZZO PER I TUOI AMICI:${NC}"
        echo -e "${GREEN}$(cat server-address.txt):25565${NC}"
    fi
    
    echo -e "\n${BLUE}ℹ️ Il file 'server-info.txt' contiene tutte le informazioni${NC}"
    echo -e "${BLUE}ℹ️ Condividi questo file con i tuoi amici!${NC}"
}

# ====================================================================
# AVVIO SCRIPT
# ====================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi