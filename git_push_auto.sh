#!/bin/bash

# AUTORIA: Paulo Hernani | Assistência: Gemini
# FLUXO: Menu -> Configura -> Autentica -> Limpa -> Sincroniza/Commit Base -> Commit -> Push

VERSION="56" # V56: Adicionada opção de Logout seguro do GH CLI no final do script.

NC='\033[0m'       
RED='\033[0;31m'   
GREEN='\033[0;32m' 
YELLOW='\033[1;33m' 
BLUE='\033[0;34m'  
CYAN='\033[0;36m'  

BRANCH_NAME="main"
LARGE_FILE_SIZE_MB=50
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/Pauloh2206/script-auto-push/refs/heads/main/git_push_auto.sh"

GIT_USERNAME_STORE=""
GIT_PASSWORD_STORE=""

# ==========================================================
# FUNÇÕES DE VERIFICAÇÃO E LIMPEZA
# ==========================================================

function check_dependencies() {
    local missing_deps=()
    local deps=("git" "curl" "cmp" "gh") # Adicionado GH CLI

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then 
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}❌ ERRO FATAL: Dependências ausentes: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}🚨 Instale as dependências necessárias (Termux/Linux):${NC}"
        echo -e "${CYAN}   - Git: pkg install git${NC}"
        echo -e "${CYAN}   - Curl: pkg install curl${NC}"
        echo -e "${CYAN}   - Coreutils (para cmp): pkg install coreutils${NC}"
        echo -e "${CYAN}   - GH CLI: pkg install gh (ou consulte o site do GitHub para outras distros)${NC}"
        exit 1
    fi
}

function check_for_update() {
    local REMOTE_FILE
    if ! REMOTE_FILE=$(mktemp); then
        echo -e "${RED}❌ ERRO CRÍTICO: Não foi possível criar arquivo temporário. Prosseguindo com V${VERSION}.${NC}"
        return 1
    fi
    
    trap "rm -f $REMOTE_FILE" EXIT INT

    echo -e "${BLUE}🔎 Verificando por atualizações do próprio script (Timeout: 20s)... Versão local: V${VERSION}${NC}"
    
    if curl --max-time 20 -s "$REMOTE_SCRIPT_URL" > "$REMOTE_FILE"; then
        
        if [ -s "$REMOTE_FILE" ]; then 
            
            local REMOTE_VERSION
            REMOTE_VERSION=$(grep '^VERSION=' "$REMOTE_FILE" | head -n 1 | cut -d'"' -f 2)
            UPDATE_PROCEED=0

            if [ -z "$REMOTE_VERSION" ]; then
                if ! cmp -s "$0" "$REMOTE_FILE"; then
                    echo -e "${YELLOW}⚠️ Aviso: Não foi possível extrair a versão remota. Usando comparação de arquivo (cmp).${NC}"
                    UPDATE_PROCEED=1
                fi
            elif [ "$REMOTE_VERSION" -gt "$VERSION" ]; then
                echo -e "${YELLOW}🚨 ATUALIZAÇÃO DISPONÍVEL!${NC}"
                echo -e "${YELLOW}   Uma nova versão (V${REMOTE_VERSION}) foi detectada. Você está na V${VERSION}.${NC}"
                UPDATE_PROCEED=1
            else
                echo -e "${GREEN}✅ Script já está na versão mais recente (V${VERSION}).${NC}"
            fi

            if [ "$UPDATE_PROCEED" -eq 1 ]; then
                read -r -p "$(echo -e "${YELLOW}Deseja ATUALIZAR AGORA? (S/n): ${NC}")" UPDATE_CHOICE
                
                if [[ "$UPDATE_CHOICE" =~ ^[Ss]$ ]]; then
                    mv "$REMOTE_FILE" "$0"
                    chmod +x "$0"
                    echo -e "${GREEN}🚀 Script atualizado para a versão mais recente (V${REMOTE_VERSION:-0}).${NC}"
                    echo -e "${GREEN}✅ Re-executando o script para aplicar as mudanças e prosseguir automaticamente...${NC}"
                    trap - EXIT INT 
                    exec bash "$0" --auto-start 
                else
                    echo -e "${YELLOW}⚠️ Atualização ignorada. Prosseguindo com V${VERSION}.${NC}"
                fi
            fi
            
        else
            echo -e "${RED}❌ ERRO DE ARQUIVO: O download falhou ou o arquivo remoto está vazio. Prosseguindo com V${VERSION}.${NC}"
        fi
    else
        echo -e "${RED}❌ ERRO DE REDE: Não foi possível verificar atualizações (Timeout ou falha de conexão). Prosseguindo com V${VERSION}.${NC}"
    fi
    
    trap - EXIT INT
}

function perform_git_cleanup() {
    echo -e "${BLUE}⚙️ Executando Limpeza Proativa do Git (git gc --prune=now)...${NC}"
    if git gc --prune=now 2>/dev/null; then
        echo -e "${GREEN}✅ Limpeza (Garbage Collection) concluída. Repositório otimizado.${NC}"
    else
        echo -e "${YELLOW}⚠️ Falha na limpeza do Git, mas prosseguindo.${NC}"
    fi

    if git status 2>&1 | grep -q "You are currently rebasing"; then
        echo -e "${BLUE}⚙️ Abortando Rebase Pendente (git rebase --abort)...${NC}"
        git rebase --abort 2>/dev/null
        echo -e "${GREEN}✅ Rebase abortado. Estado limpo.${NC}"
    fi

    if git status 2>&1 | grep -q "You have unmerged paths"; then
        echo -e "${BLUE}⚙️ Abortando Merge Pendente (git merge --abort)...${NC}"
        git merge --abort 2>/dev/null
        echo -e "${GREEN}✅ Merge abortado. Estado limpo.${NC}"
    fi
}

function main_menu() {
    
    while true; do
        echo -e "\n${YELLOW}=========================================================="
        echo -e "        MENU INICIAL - AUTOMAÇÃO GIT (V${VERSION})          "
        echo -e "       ${CYAN}Autor: Paulo Hernani | Assistência: Gemini${NC}"
        echo -e "${YELLOW}=========================================================="
        echo -e "${CYAN}Escolha uma opção:${NC}"
        echo -e "1) ${GREEN}INICIAR PUSH/SINCRONIZAÇÃO${NC} (🆗)"
        echo -e "2) ${BLUE}VERIFICAR E ATUALIZAR SCRIPT${NC} (🔄)"
        echo -e "3) ${RED}SAIR${NC} (❌)"
        
        read -r -p "$(echo -e "${YELLOW}Opção (1, 2 ou 3) [1]: ${NC}")" MENU_CHOICE
        MENU_CHOICE=${MENU_CHOICE:-1} 

        case "$MENU_CHOICE" in
            1)
                echo -e "${GREEN}✅ Prosseguindo com o script...${NC}"
                break 
                ;;
            2)
                check_for_update 
                echo -e "${GREEN}✅ Verificação concluída. Retornando ao menu para prosseguir.${NC}"
                ;; 
            3)
                echo -e "${RED}❌ Operação cancelada pelo usuário.${NC}"
                # A função 'goodbye_and_logout' será chamada no final. Se sair aqui, não precisa do logout, mas o exit interrompe o fluxo.
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opção inválida. Escolha 1, 2 ou 3.${NC}"
                ;;
        esac
    done
    echo -e "${YELLOW}----------------------------------------------------------${NC}"
}

function goodbye_and_logout() {
    echo -e "\n${YELLOW}=========================================================="
    echo -e "          FIM DO PROCESSO GIT INTERATIVO (V${VERSION})          "
    echo -e "=========================================================="
    echo -e "${GREEN}✅ AUTOR: Paulo Hernani${NC}"
    echo -e "${GREEN}🤝 ASSISTÊNCIA NO SCRIPT: Gemini${NC}"
    echo -e "${CYAN}📷 Siga no Instagram: @eu_paulo_ti${NC}"
    echo -e "${YELLOW}----------------------------------------------------------${NC}"

    # ==========================================================
    # DESLOGAR DO GH CLI (OPCIONAL)
    # ==========================================================
    echo -e "\n${CYAN}🚨 SAÍDA SEGURA DO GH CLI${NC}"
    read -r -p "$(echo -e "${YELLOW}Deseja deslogar do GitHub CLI ('gh auth logout') AGORA? (s/N) [N]: ${NC}")" LOGOUT_CHOICE
    LOGOUT_CHOICE=${LOGOUT_CHOICE:-N}

    if [[ "$LOGOUT_CHOICE" =~ ^[Ss]$ ]]; then
        echo -e "${BLUE}⚙️ Deslogando do GitHub CLI...${NC}"
        if gh auth logout; then
            echo -e "${GREEN}✅ Deslogado com sucesso! Suas credenciais foram removidas do sistema.${NC}"
        else
            echo -e "${RED}❌ ERRO ao deslogar. Tente rodar 'gh auth logout' manualmente.${NC}"
        fi
    else
        echo -e "${GREEN}✅ Credenciais mantidas para o próximo uso.${NC}"
    fi

    echo -e "${YELLOW}==========================================================${NC}"
    exit 0
}

# ==========================================================
# INÍCIO DO FLUXO
# ==========================================================
check_dependencies

if [ "$1" == "--auto-start" ]; then
    echo -e "\n${GREEN}✅ Início Automático (V${VERSION}) ativado após atualização. Prosseguindo...${NC}"
else
    main_menu
fi

# NOVO: Seleção da Branch Principal
echo -e "\n${CYAN}⚙️ SELEÇÃO DA BRANCH PRINCIPAL:${NC}"
echo -e "1) ${GREEN}main${NC} (Padrão moderno do GitHub)"
echo -e "2) ${YELLOW}master${NC} (Padrão anterior)"
read -r -p "$(echo -e "${YELLOW}Escolha a opção (1 ou 2) [1]: ${NC}")" BRANCH_CHOICE
BRANCH_CHOICE=${BRANCH_CHOICE:-1}

if [ "$BRANCH_CHOICE" == "2" ]; then
    BRANCH_NAME="master"
else
    BRANCH_NAME="main"
fi
echo -e "${GREEN}✅ Branch principal definida como: ${CYAN}$BRANCH_NAME${NC}"
echo -e "${YELLOW}----------------------------------------------------------${NC}"
sleep 1


echo -e "\n${YELLOW}=========================================================="
echo -e "           INÍCIO DO ENVIO SIMPLIFICADO AO GITHUB (V${VERSION})           "
echo -e "${YELLOW}=========================================================="
echo -e "${NC}"

sleep 2

# 0. PRÉ-VERIFICAÇÃO E INICIALIZAÇÃO GIT (OTIMIZADO)
# ----------------------------------------------------------
echo -e "\n${YELLOW}🚨 Você deve estar DENTRO da pasta raiz do seu projeto. Diretório: ${CYAN}$(pwd)${NC}"
read -r -p "$(echo -e "${YELLOW}CONFIRMA que está na pasta do projeto? (S/n): ${NC}")" CONFIRMATION
if [[ ! "$CONFIRMATION" =~ ^[Ss]$ && ! -z "$CONFIRMATION" ]]; then echo -e "${RED}❌ Operação cancelada.${NC}"; goodbye_and_logout; fi

if [ ! -d ".git" ]; then
    echo -e "${BLUE}⚙️ Inicializando Git (git init)...${NC}"
    git init || { echo -e "${RED}❌ ERRO NA INICIALIZAÇÃO.${NC}"; goodbye_and_logout; }
    echo -e "${GREEN}✅ Repositório Git inicializado.${NC}"
else
    echo -e "${GREEN}✅ Repositório Git (.git) já inicializado.${NC}"
fi

echo -e "${BLUE}⚙️ Definindo branch local como '$BRANCH_NAME'...${NC}"
git branch -M $BRANCH_NAME 2>/dev/null

if [ $? -ne 0 ]; then
    if git status 2>&1 | grep -q "dubious ownership"; then
        CURRENT_DIR=$(pwd)
        echo -e "${RED}\n❌ ERRO DETECTADO: Dubious ownership.${NC}"
        echo -e "${BLUE}   APLICANDO SOLUÇÃO: Adicionando diretório à lista de segurança...${NC}"
        git config --global --add safe.directory "$CURRENT_DIR"
        git branch -M $BRANCH_NAME || { echo -e "${RED}❌ ERRO FATAL: Falha ao definir a branch.${NC}"; goodbye_and_logout; }
        echo -e "${GREEN}✅ Branch definida após correção de propriedade.${NC}"
    else
        echo -e "${RED}❌ ERRO FATAL ao definir a branch principal.${NC}"; goodbye_and_logout
    fi
fi
echo -e "${GREEN}✅ Branch principal definida.${NC}"
echo -e "${YELLOW}----------------------------------------------------------${NC}"
sleep 2

# 1. CONFIGURAR REMOTO (URL) / CRIAR REPOSITÓRIO (Usando GH CLI)
# ----------------------------------------------------------
REMOTE_URL=$(git remote get-url origin 2>/dev/null)

if [ -n "$REMOTE_URL" ]; then
    # Repositório já existe (lógica de mudança/manutenção)
    echo -e "${GREEN}✅ Repositório remoto ATUAL: ${CYAN}$REMOTE_URL${NC}"
    read -r -p "$(echo -e "${YELLOW}Deseja ALTERAR/TROCAR este repositório? (s/N) [N]: ${NC}")" CHANGE_REPO
    
    if [[ "$CHANGE_REPO" =~ ^[Ss]$ ]]; then
        echo -e "${BLUE}⚙️ Removendo configuração do repositório antigo...${NC}"
        git remote remove origin
        REMOTE_URL="" # Limpa a variável para forçar a configuração/criação abaixo
    else
        echo -e "${GREEN}✅ Mantendo repositório atual.${NC}"
    fi
fi

# Se não tem remoto, inicia o fluxo de criação via GH CLI
if [ -z "$REMOTE_URL" ]; then
    echo -e "${CYAN}📌 PASSO 1/4: CRIAÇÃO/CONFIGURAÇÃO DO REPOSITÓRIO (GH CLI)${NC}"
    
    # 1. Tenta pegar o nome de usuário (necessário para o PULL_URL)
    GIT_USERNAME_STORE=$(gh api user -q .login 2>/dev/null)
    if [ -z "$GIT_USERNAME_STORE" ]; then
        echo -e "${RED}❌ ERRO FATAL: Falha ao obter o nome de usuário do GH CLI.${NC}"
        echo -e "${YELLOW}🚨 Execute 'gh auth login' e tente novamente.${NC}"
        goodbye_and_logout
    fi
    
    # 2. Pergunta se é para criar um novo ou adicionar URL
    while true; do
        echo -e "1) ${GREEN}CRIAR NOVO repositório no GitHub (Recomendado)${NC}"
        echo -e "2) ${YELLOW}ADICIONAR URL de um repositório existente${NC}"
        read -r -p "$(echo -e "${YELLOW}Opção (1 ou 2) [1]: ${NC}")" REMOTE_ACTION
        REMOTE_ACTION=${REMOTE_ACTION:-1}

        if [ "$REMOTE_ACTION" == "1" ]; then
            read -r -p "$(echo -e "${CYAN}✍️ Digite o NOME do novo repositório (ex: meu-projeto-novo): ${NC}")" REPO_NAME
            
            # Comando mágico: Cria o repositório, define o remoto e o PUSH
            echo -e "${BLUE}⚙️ Executando 'gh repo create ${GIT_USERNAME_STORE}/${REPO_NAME} --source=. --remote=origin --public'...${NC}"
            if gh repo create "${GIT_USERNAME_STORE}/${REPO_NAME}" --source=. --remote=origin --public --description "Auto-created by git_push_auto.sh V${VERSION}"; then
                echo -e "${GREEN}✅ Repositório criado e conectado com sucesso!${NC}"
                REMOTE_URL="https://github.com/${GIT_USERNAME_STORE}/${REPO_NAME}.git"
                break
            else
                echo -e "${RED}❌ ERRO: Falha na criação do repositório (Pode ser nome já existente ou erro de permissão).${NC}"
                echo -e "${YELLOW}Tente novamente ou escolha a opção 2.${NC}"
            fi
        
        elif [ "$REMOTE_ACTION" == "2" ]; then
            while true; do
                read -r -p "$(echo -e "${CYAN}🔗 COLE A URL HTTPS DO REPOSITÓRIO EXISTENTE: ${NC}")" NEW_REPO_URL
                NEW_REPO_URL=$(echo "$NEW_REPO_URL" | xargs)
                if [[ "$NEW_REPO_URL" =~ ^https://github.com/.*\.git$ ]]; then 
                    REMOTE_URL=$NEW_REPO_URL
                    git remote add origin "$REMOTE_URL"
                    echo -e "${GREEN}✅ Repositório conectado!${NC}"
                    break 2 # Sai dos dois loops (interno e externo)
                fi
                echo -e "${RED}🚨 URL inválida. O link deve ser HTTPS e terminar em .git.${NC}"
            done

        else
            echo -e "${RED}❌ Opção inválida.${NC}"
        fi
    done
fi

# 2. OBTENÇÃO DE CREDENCIAIS (Para PULL e PUSH) - SIMPLIFICADO PELA INTEGRAÇÃO GH CLI
# ----------------------------------------------------------
echo -e "\n${CYAN}📌 PASSO 2/4: AUTENTICAÇÃO (GH CLI)${NC}"
echo -e "${GREEN}✅ O GH CLI está autenticado. Não é necessário digitar o token novamente.${NC}"

PULL_URL="$REMOTE_URL" 

echo -e "${YELLOW}----------------------------------------------------------${NC}"
sleep 1

# 2.5. LIMPEZA PROATIVA 
# ----------------------------------------------------------
echo -e "${CYAN}📌 PASSO 2.5/4: LIMPEZA PROATIVA DO REPOSITÓRIO LOCAL${NC}"
perform_git_cleanup
echo -e "${YELLOW}----------------------------------------------------------${NC}"
sleep 1


# 3. SINCRONIZAÇÃO PROATIVA (git pull --rebase) - CORRIGIDO PARA REPOSITÓRIOS VAZIOS
# ----------------------------------------------------------
echo -e "${CYAN}📌 PASSO 3/4: SINCRONIZAÇÃO PROATIVA (git pull --rebase)${NC}"
read -p "$(echo -e "${BLUE}✅ Pressione [Enter] para sincronizar e trazer mudanças remotas...${NC}")"

STASH_NEEDED=0

if ! git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ ALERTA: Branch local ('$BRANCH_NAME') é 'Unborn'. Criando commit inicial forçado...${NC}"
    
    git add .
    
    if git commit -m "commit: Initial repository setup (Auto-generated by V${VERSION})" 2>/dev/null; then
        echo -e "${GREEN}✅ Commit inicial criado com sucesso. Branch 'nasceu'.${NC}"
    else
        echo -e "${YELLOW}⚠️ Aviso: Não havia arquivos para o commit inicial. Prosseguindo com Pull.${NC}"
    fi
else
    if git stash push -u -m "Auto-Stash antes do Pull Proativo V${VERSION}" 2>/dev/null; then
        STASH_NEEDED=1
        echo -e "${GREEN}✅ Alterações locais guardadas temporariamente (Stash).${NC}"
    else
        if git diff --quiet --exit-code --cached; then
            echo -e "${YELLOW}⚠️ Não há alterações locais ou unstaged para guardar. Prosseguindo com Pull.${NC}"
        else
            echo -e "${YELLOW}⚠️ Arquivos staged encontrados (mas sem commit). Prosseguindo com Pull.${NC}"
        fi
    fi
fi

# NOVO CHECK: Verifica se a branch principal existe no remoto antes de tentar o pull
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    
    echo -e "${BLUE}⚙️ Executando 'git pull --rebase origin $BRANCH_NAME' para sincronizar...${NC}"

    if git pull --rebase origin "$BRANCH_NAME"; then
        echo -e "${GREEN}✅ Sincronização Proativa concluída. Histórico alinhado.${NC}"
        
        if [ $STASH_NEEDED -eq 1 ]; then
            echo -e "${BLUE}⚙️ Restaurando alterações locais (Stash Pop)...${NC}"
            if ! git stash pop --index; then
                echo -e "${RED}❌ ERRO ao restaurar alterações (Stash Pop)! O Git encontrou um CONFLITO no local.${NC}"
                echo -e "${CYAN}   🚨 Ação Manual NECESSÁRIA: Você precisa resolver o conflito (removendo <<<, ===, >>>).${NC}"
                echo -e "${CYAN}   1. Edite os arquivos em conflito. 2. Use 'git add .' 3. Use 'git stash drop' para finalizar.${NC}"
                goodbye_and_logout
            fi
            echo -e "${GREEN}✅ Alterações locais restauradas. Estão prontas para o próximo commit.${NC}"
        fi

    else
        echo -e "${RED}❌ ERRO FATAL no Pull/Rebase! O Git parou devido a CONFLITOS de histórico.${NC}"
        echo -e "${CYAN}   🚨 Ação Manual NECESSÁRIA: Você deve resolver o conflito!${NC}"
        echo -e "${CYAN}   1. Edite arquivos. 2. 'git add .' 3. 'git rebase --continue'.${NC}"
        goodbye_and_logout
    fi

else
    echo -e "${YELLOW}⚠️ ALERTA: Branch remota ('$BRANCH_NAME') não encontrada no servidor.${NC}"
    echo -e "${CYAN}🚀 Assumindo que este é o PRIMEIRO ENVIO. Pulando o PULL e prosseguindo para o COMMIT/PUSH inicial...${NC}"
    
    # Restaura o stash de qualquer forma para que as alterações sejam commitadas
    if [ $STASH_NEEDED -eq 1 ]; then
        echo -e "${BLUE}⚙️ Restaurando alterações locais (Stash Pop)...${NC}"
        git stash pop --index 2>/dev/null
        echo -e "${GREEN}✅ Alterações locais restauradas para o commit inicial.${NC}"
    fi
fi

echo -e "${YELLOW}----------------------------------------------------------${NC}"
sleep 1


# 4. VERIFICAÇÕES DE SEGURANÇA E EFICIÊNCIA 
# -------------------------------------------------------------------------
echo -e "${BLUE}🔍 EXECUTANDO VERIFICAÇÕES DE SEGURANÇA E EFICIÊNCIA...${NC}"

SENSITIVE_FILES=$(git ls-files -o --exclude-standard | grep -E "\.(env|key|pem)$|^credentials\." | sed 's/^/   - /')
if [ -n "$SENSITIVE_FILES" ]; then
    
    echo -e "${RED}\n🚨 ALERTA DE SEGURANÇA: Arquivos potencialmente COMPROMETEDORES detectados!${NC}"
    echo -e "   Arquivos encontrados:\n${CYAN}${SENSITIVE_FILES}${NC}"
    
    while true; do
        echo -e "\n${YELLOW}ESCOLHA AÇÃO DE SEGURANÇA:${NC}"
        echo -e "1) ${RED}PARAR o processo${NC} (Revisão Manual/Excluir)."
        echo -e "2) ${GREEN}Adicionar ao .gitignore e Continuar${NC} (Ação Automática mais segura)."
        echo -e "3) ${YELLOW}Ignorar Alerta e Continuar${NC} (Risco: Rastreia arquivos sensíveis)."
        read -r -p "$(echo -e "${YELLOW}Opção (1, 2 ou 3) [1]: ${NC}")" SECURITY_ACTION_CHOICE
        SECURITY_ACTION_CHOICE=${SECURITY_ACTION_CHOICE:-1} 

        if [ "$SECURITY_ACTION_CHOICE" == "1" ]; then
            echo -e "${RED}❌ Operação INTERROMPIDA. Adicione os arquivos ao .gitignore ou exclua-os manualmente.${NC}"
            goodbye_and_logout

        elif [ "$SECURITY_ACTION_CHOICE" == "2" ]; then
            echo -e "${BLUE}⚙️ Adicionando arquivos sensíveis ao .gitignore e removendo do rastreamento...${NC}"
            echo "$SENSITIVE_FILES" | sed 's/^   - //' | while read -r FILE; do
                if [ -n "$FILE" ]; then
                    echo "$FILE" >> .gitignore
                    git rm --cached "$FILE" 2>/dev/null
                    echo -e "${GREEN}   - Adicionado: $FILE${NC}"
                fi
            done
            echo -e "${GREEN}✅ Arquivos ignorados. Prosseguindo.${NC}"
            break

        elif [ "$SECURITY_ACTION_CHOICE" == "3" ]; then
            echo -e "${YELLOW}⚠️ ALERTA: Você optou por continuar, permitindo o rastreamento dos arquivos sensíveis. Tome cuidado!${NC}"
            break
        else
            echo -e "${RED}❌ Opção inválida. Escolha 1, 2 ou 3.${NC}"
        fi
    done
fi

LARGE_FILES=$(find . -type f -size +${LARGE_FILE_SIZE_MB}M -print -exec du -h {} + 2>/dev/null | grep -E "\.${LARGE_FILE_SIZE_MB}M" | awk '{print $2 " (" $1 ")"}' | head -n 3)
if [ -n "$LARGE_FILES" ]; then
    echo -e "${YELLOW}\n⚠️ ALERTA DE EFICIÊNCIA: Arquivos muito grandes (>${LARGE_FILE_SIZE_MB}MB) detectados. Sugestão: Git LFS.${NC}"
    echo -e "   Arquivos encontrados (Top 3):\n${CYAN}${LARGE_FILES}${NC}"
fi

if [ ! -f ".gitignore" ]; then echo -e "${YELLOW}\n💡 SUGESTÃO: Arquivo '.gitignore' não encontrado. Crie um para evitar rastrear arquivos desnecessários.${NC}"; fi

echo -e "${GREEN}\n✅ Verificações de segurança e eficiência concluídas.${NC}"
echo -e "${YELLOW}----------------------------------------------------------${NC}"
sleep 1

# 5. ADICIONAR E COMMITAR 
# ----------------------------------------------------------

if [ -d "node_modules" ] && ! grep -q "node_modules" .gitignore 2>/dev/null; then
    echo -e "\n${BLUE}⚙️ CORREÇÃO AUTOMÁTICA: Pasta 'node_modules' detectada e não ignorada.${NC}"
    echo -e "\nnode_modules/" >> .gitignore
    git rm -r --cached node_modules 2>/dev/null
    echo -e "${GREEN}✅ 'node_modules/' adicionado ao .gitignore e removido do rastreamento.${NC}"
    echo -e "${YELLOW}----------------------------------------------------------${NC}"
fi

read -p "$(echo -e "${YELLOW}✅ Pressione [Enter] para adicionar todos os arquivos (git add .)...${NC}")"
git add .

if git status --porcelain | grep -q '^\(M\|A\|D\|R\|C\|U\|\?\?\)' ; then
    echo -e "\n${YELLOW}📝 SELEÇÃO DA MENSAGEM DO COMMIT:${NC}"
    COMMIT_OPTIONS=("feat: Nova Funcionalidade" "fix: Correção de Bug" "chore: Tarefa de Rotina/Build" "refactor: Melhoria de Código" "docs: Atualização de Documentação" "custom: Escrever Mensagem Completa")

    select COMMIT_TYPE_CHOICE in "${COMMIT_OPTIONS[@]}"; do
        case "$COMMIT_TYPE_CHOICE" in
            "feat: Nova Funcionalidade") COMMIT_PREFIX="feat"; break;;
            "fix: Correção de Bug") COMMIT_PREFIX="fix"; break;;
            "chore: Tarefa de Rotina/Build") COMMIT_PREFIX="chore"; break;;
            "refactor: Melhoria de Código") COMMIT_PREFIX="refactor"; break;;
            "docs: Atualização de Documentação") COMMIT_PREFIX="docs"; break;;
            *) COMMIT_PREFIX=""; break;;
        esac
    done

    while true; do
        if [ -n "$COMMIT_PREFIX" ]; then
            read -r -p "$(echo -e "${YELLOW}➡️ Descrição (ex: Adicionada validação): ${NC}")" COMMIT_DESCRIPTION
            COMMIT_MESSAGE="$COMMIT_PREFIX: $COMMIT_DESCRIPTION"
        else
            read -r -p "$(echo -e "${YELLOW}➡️ MENSAGEM DO COMMIT completa: ${NC}")" COMMIT_MESSAGE
        fi
        [ -n "$COMMIT_MESSAGE" ] && break || echo -e "${RED}🚨 A mensagem não pode ser vazia.${NC}"
    done

    echo -e "${BLUE}⚙️ Executando commit: ${CYAN}${COMMIT_MESSAGE}${NC}"
    git commit -m "$COMMIT_MESSAGE" || { echo -e "${RED}❌ Erro ao criar o commit.${NC}"; goodbye_and_logout; }
    echo -e "${GREEN}✅ Commit criado com sucesso.${NC}"
else
    echo -e "${YELLOW}⚠️ Não há alterações para commitar. Prosseguindo para o PUSH...${NC}"
fi
echo -e "${YELLOW}----------------------------------------------------------${NC}"
sleep 1

# 6. ENVIAR PARA O GITHUB (Push)
# ----------------------------------------------------------
while true; do
    PUSH_COMMAND="git push -u origin $BRANCH_NAME" 

    read -p "$(echo -e "${GREEN}✅ Pressione [Enter] para executar o PUSH...${NC}")"
    echo -e "${BLUE}📡 Iniciando o envio. Aguarde o resultado...${NC}"

    PUSH_OUTPUT=$(eval "$PUSH_COMMAND" 2>&1)
    PUSH_EXIT_CODE=$?

    if [ $PUSH_EXIT_CODE -eq 0 ]; then
        echo -e "\n${GREEN}==========================================================${NC}"
        echo -e "${GREEN}🚀 SUCESSO! SEU PROJETO ESTÁ ONLINE NO GITHUB. 🎉${NC}"
        echo -e "${GREEN}==========================================================${NC}"
        break
    else
        echo -e "\n${YELLOW}----------------------------------------------------------${NC}"
        echo -e "${CYAN}Saída Completa do Git (Diagnóstico):\n${PUSH_OUTPUT}${NC}"
        echo -e "${YELLOW}----------------------------------------------------------${NC}"

        if echo "$PUSH_OUTPUT" | grep -q "fatal: Authentication failed"; then
            echo -e "${RED}❌ FALHA NO PUSH: ERRO DE AUTENTICAÇÃO.${NC}"
            echo -e "${YELLOW}🚨 Tente rodar 'gh auth login --renew' no terminal e tente novamente.${NC}"
            goodbye_and_logout
        
        elif echo "$PUSH_OUTPUT" | grep -q "remote unpack failed" || echo "$PUSH_OUTPUT" | grep -q "did not receive expected object"; then
             echo -e "${RED}❌ FALHA NO PUSH: ERRO DE OBJETO / DESEMPACOTAMENTO.${NC}"
             while true; do
                echo -e "\n${YELLOW}ESCOLHA AÇÃO:${NC}"
                echo -e "${CYAN}1) Correção Padrão (git gc).${NC}"
                echo -e "${GREEN}2) Correção Agressiva (Recriação de Pacotes).${NC}"
                echo -e "${YELLOW}3) Tentar Novamente (Rede).${NC}"
                echo -e "4) Sair."
                
                read -r -p "$(echo -e "${YELLOW}Opção (1-4) [1]: ${NC}")" OBJECT_ERROR_CHOICE
                OBJECT_ERROR_CHOICE=${OBJECT_ERROR_CHOICE:-1} 
                
                if [ "$OBJECT_ERROR_CHOICE" == "1" ]; then git gc --prune=now && echo -e "${GREEN}✅ Limpeza concluída.${NC}" && break; fi
                if [ "$OBJECT_ERROR_CHOICE" == "2" ]; then rm -rf .git/objects/pack/* && git repack -a -d && echo -e "${GREEN}✅ Recriação concluída.${NC}" && break; fi
                if [ "$OBJECT_ERROR_CHOICE" == "3" ]; then break; fi
                if [ "$OBJECT_ERROR_CHOICE" == "4" ]; then goodbye_and_logout; fi
                echo -e "${RED}❌ Opção inválida.${NC}"
            done
            
        elif echo "$PUSH_OUTPUT" | grep -q "GH013: Repository rule violations found"; then
            echo -e "${RED}❌ FALHA NO PUSH: REJEITADO POR CONTER SEGREDO (GH013).${NC}"
            echo -e "${YELLOW}O GitHub detectou uma Chave de API em seu histórico. Remova, autorize ou use git filter-repo.${NC}"
            goodbye_and_logout

        else
            echo -e "${RED}❌ FALHA NO PUSH! Erro genérico.${NC}"
            read -r -p "$(echo -e "${YELLOW}Deseja TENTAR NOVAMENTE? (S/n) [S]: ${NC}")" RETRY_GENERIC
            if [[ ${RETRY_GENERIC:-S} =~ ^[Ss]$ ]]; then continue; else goodbye_and_logout; fi
        fi
    fi
done

# ==========================================================
# CRÉDITOS FINAIS E LOGOUT
# ==========================================================
goodbye_and_logout