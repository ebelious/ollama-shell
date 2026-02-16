#!/usr/bin/env bash
# Packages: pup jq fzf bash python html2text curl ollama
# Add the OLLAMA_HOST to .bashrc or w.e and source it  'source $HOME/.bashrc'
# 
# Gobal Vars
source ~/.bashrc
CONF_DIR=$HOME/.config/ollama
V_MODEL=$HOME/.config/ollama/ollama_versions.txt
CONFIG=$HOME/.config/ollama/ollama.conf
D_SERVER=$(cat $CONFIG | grep server | sed "s/\"//g"| cut -d '=' -f2)
D_MODEL=$(cat $CONFIG | grep model | sed "s/\"//g"| cut -d '=' -f2)
L_MODEL=$HOME/.config/ollama/ollama_pullable.txt
PORT=11434
OLLAMA_CVER=$(ollama -v | awk {'print $4'})
LREL=$(curl -s https://api.github.com/repos/ollama/ollama/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'| sed 's/v//g')
###################################################################
# Get and Set Ollama server
fn_server(){
echo -ne "\e[1;1H\e[2K\e[35m[Quit]\e[0m \e[33m[Server]\e[0m \e[32m[Select]\e[0m"
echo -ne ""
echo -ne "\e[8;1H\e[J\e[3;34mexample: 10.2.2.5 or hostname\e\n[0m"
read -p "Enter Ollama Server: " IP
case $IP in
    q|Q) main;;
esac
sed -i "s/server=.*$/server="$IP"/g" $CONFIG
}
###################################################################
# Get and Select LLms from Server
fn_llms(){ 
LIST=($(ollama ls | awk 'NR>=2 {print $1}' | sort ))
if [ ${#LIST[@]} -eq 0 ];then
    echo -e "\e[31mCannot find Models\e[0m"
    sleep 1
    main
fi
# Get The Numbers
echo -ne "\e[1;1H\e[2K\e[35m[Quit]\e[0m \e[33m[Models]\e[0m \e[32m[Select]\e[0m"
echo -ne "\e[8;1H\e[J"  
for i in "${!LIST[@]}"; do
     echo -e "\e[33m[$((i+1))]\e[0m ${LIST[$i]}"
done
# Selection Statmentï
read -p $'\nSelect the model number: ' OPTION
# If Q/q → restart
if [[ "$OPTION" == "q" || "$OPTION" == "Q" ]]; then
    main && return
fi
if [[ "$OPTION" == "d" || "$OPTION" == "D" ]]; then
    fn_delete && return
fi
if [[ "$OPTION" == "p" || "$OPTION" == "P" ]]; then
    fn_pull && return
fi
if [[ "$OPTION" == "i" || "$OPTION" == "I" ]]; then
    fn_info && return
fi
# If not a valid number → invalie
if ! [[ "$OPTION" =~ ^[0-9]+$ ]] || (( OPTION < 1 || OPTION > ${#LIST[@]} )); then
    echo -ne "\e[31mInvalid Selection\e[0m"
    sleep 1
    fn_llms
fi
SELECTED=${LIST[$((OPTION -1))]}
sed -i "s/model=.*$/model="$SELECTED"/g" $CONFIG
source $CONFIG
}

###################################################################
# Pulls doen LLms from ollama
fn_pull() {
    PULL=$(cat "$L_MODEL" | fzf --prompt "[base model] ")
    fn_spin "\e[8;1H\e[J\e[32m[\e[0m\e[36m\e[0m\e[32m]\e[0m \e[34mGathering Versions\e[0m\r" & pid=$!

    truncate -s0 "$V_MODEL"
    curl -s "https://ollama.com/library/${PULL}/tags" \
        | grep -oP "(?<=<a href=\"/library/${PULL}:)[^\"]+" \
        | sort -u \
        | grep -v '^$' \
        | while read -r tag; do
            echo "${PULL}:${tag}" >> "$V_MODEL"
        done

    kill "$pid" 2>/dev/null

    VER=$(cat "$V_MODEL" | fzf --prompt "[model version] ")

    # Exit if user cancels
    if [[ -z "$VER" || "$VER" =~ ^[Qq]$ ]]; then
        main
    fi

    # Proper model existence check
    setterm --cursor off
    if ollama ls | awk '{print $1}' | grep -Fxq "${VER}"; then
        echo -ne "\e]8;1H\e[J\e[2;34mThis model already exists. Not Downloading.\e[0m\n"
        sleep 2
        main
    fi

    # Ask before pulling
    echo -ne "\e[8;1H\e[JAre you sure you want to pull \e[36m[$VER]\e[0m?\n\n"
    echo -ne "\e[33m[\e[0m\e[36mY\e[0m\e[33m]\e[0m yes\n"
    echo -ne "\e[33m[\e[0m\e[36mN\e[0m\e[33m]\e[0m no\n\r"

    read -r OPTION

    if [[ ! "$OPTION" =~ ^[Yy]$ ]]; then
        main
    fi

    echo -ne "\e[8;1H\e[J"
    ollama pull "$VER"
    if [[ $? -ne 0 ]]; then
        sleep 3
        main
    fi

    echo -ne "\e[8;1H\e[JSet \e[36m[ $VER ]\e[0m as the new Default Model?\n\n"
    echo -ne "\e[33m[\e[0m\e[36mY\e[0m\e[33m]\e[0m yes\n"
    echo -ne "\e[33m[\e[0m\e[36mN\e[0m\e[33m]\e[0m no\n\r"

    read -r OPTION

    if [[ "$OPTION" =~ ^[Yy]$ ]]; then
        sed -i "s/model=.*$/model=$VER/g" "$CONFIG"
    else
        main
    fi
}
###################################################################
# Animation for loading
#fn_spin(){
#spinn=( '\\' '|' '/' '-' )
#while [ 1 ] ;do
#    for i in "${spinn[@]}";do
#              echo -ne "\e[9;2H\e[J\e[32m[\e[0m\e[0;36m$i\e[0m\e[0;32m]\e[0m \e[33mUpdating List\e[0m\r "
#        sleep 0.175
#    done
# done
#}
fn_spin() {
    local message="$1"
    spinn=( '\\' '|' '/' '-' )

    while : ; do
        for i in "${spinn[@]}"; do
            echo -ne "\e[32m[\e[0m\e[0;36m$i\e[0m\e[0;32m]\e[0m \e[33m${message}\e[0m\r"
            sleep 0.175
        done
    done
}

###################################################################
# This will curl the ollama library and remove any unwanted items in the list
fn_update() {
fn_spin "\e[8;1H\e[J\e[35mUpdating List...\e[0m" & pid=$!
truncate -s0 $L_MODEL
curl -s https://ollama.com/library | grep -oP 'href="/library/\K[^"/]+' | sort -u >> $L_MODEL
kill $pid
F_CHECK=$(stat $L_MODEL | grep Size | awk {'print $2'})
if [[ $F_CHECK == 0 ]];then
echo -ne "\e[32m[\e[0m\e[31m\e[0m\e[32m]\e[0m \e[31mError Updating List\e[0m"
fi
echo -ne "\e[32m[\e[0m\e[36m\e[0m\e[32m]\e[0m \e[34mDone Updating List\e[0m"
sleep 1
}
###################################################################
# Gets the most recent Oollama version
fn_release(){
if [[ ${LREL} != ${OLLAMA_CVER} ]];then
    echo -e "\e[2;35mOllama Version $LREL is available!"
fi
}
###################################################################
# Update Ollama
fn_upollama(){
#echo -n "$LREL" | od -c
#echo -n "$OLLAMA_CVER" | od -c
if [[ "$LREL" == "$OLLAMA_CVER" ]]; then
    echo -ne "\e[8;1H\e[J\e[3;36m$OLLAMA_CVER is the lateset release\e[0m"
    sleep 2
    main
fi    
#echo -ne "\e[8;1H\e[J\e[31mAre you sure you want to update ollama to \e[36m$LREL\e[0m?\n\n\e[33m[\e[0m\e[36mY\e[0m\e[33m]\e[0m yes\n\e[33m[\e[0m\e[36mN\e[0m\e[33m]\e[0m no\n"

read CONFIRM
if [[ "$CONFIM" == "y" || "$CONFIRM" == "y" ]];then
    curl -fsSL https://ollama.com/install.sh | sh
    main
else
    main
fi
}
###################################################################
# Pulls llm pages from ollama
fn_info(){
clear
SEL=$(cat $L_MODEL | fzf)
curl -s https://ollama.com/library/$SEL \
  | python3 -m html2text --ignore-links --ignore-images --body-width 0 \
  | awk '/^## Readme/{flag=1; next} /^Write Preview/ && flag{exit} flag' \
  | awk '{
      if ($0 ~ /^## /)               # Heading level 2
        print "\033[1;34m" $0 "\033[0m";
      else if ($0 ~ /^### /)         # Heading level 3
        print "\033[1;32m" $0 "\033[0m";
      else if ($0 ~ /^[0-9]+\./)     # Numbered list item
        print "\033[1;33m" $0 "\033[0m";  # Yellow
      else
        print $0
    }' \
  | less -R --wordwrap
}
###################################################################
# Deleted LLms
fn_delete(){ 
LIST=($(ollama ls | awk 'NR>=2 {print $1}' | sort ))
if [ ${#LIST[@]} -eq 0 ];then
    echo -e "\e[31mCannot find Models\e[0m"
    sleep 1
    main
fi
# Get The Numbers
echo -ne "\e[1;1H\e[2K\e[35m[Quit]\e[0m \e[33m[Models]\e[0m \e[31m[Delete]\e[0m"
echo -ne "\e[8;1H\e[J"  
for i in "${!LIST[@]}"; do
     echo -e "\e[33m[$((i+1))]\e[0m ${LIST[$i]}"
done
# Selection Statmentï
read -p $'\nSelect the model number: ' OPTION
# If Q/q → restart
if [[ "$OPTION" == "q" || "$OPTION" == "Q" ]]; then
    main && return
fi
if [[ "$OPTION" == "m" || "$OPTION" == "M" ]]; then
    fn_llms && return
fi
if [[ "$OPTION" == "p" || "$OPTION" == "P" ]]; then
    fn_pull && return
fi
if [[ "$OPTION" == "i" || "$OPTION" == "I" ]]; then
    fn_info && return
fi

# If not a valid number → invalie
if ! [[ "$OPTION" =~ ^[0-9]+$ ]] || (( OPTION < 1 || OPTION > ${#LIST[@]} )); then
    echo -e "\e[31mInvalid Selection\e[0m"
    sleep 1
    fn_delete
fi
SELECTED="${LIST[$((OPTION - 1))]}"
echo -e "\e[8;1H\e[J\e[31mAre you sure you want to delete\e[0m \e[36m[ $SELECTED ]\e[0m ?\n\n\e[33m[\e[0m\e[36mY\e[0m\e[33m]\e[0m yes\n\e[33m[\e[0m\e[36mN\e[0m\e[33m]\e[0m no\n"
read CONFIRM
if [[ "$CONFIM" == "y" || "$CONFIRM" == "y" ]];then
    ollama rm "$SELECTED"
    fn_delete
else
    fn_delete
fi
}
###################################################################
# formating for header on main
fn_center(){
# Colors and Styles
    local text="$1"
    local color="$2"
    local width=$(tput cols)
    local len=${#text}
    local pad=$(( (width - len) / 2 ))
printf "%*s${color}%s\033[0m\n" "$pad" "" "$text"
}
###################################################################
# default run option
fn_default(){
clear
if ! ollama run $D_MODEL; then
sleep 3
fi
}
###################################################################
# checks for server config
fn_scheck(){
if [[ -z $D_SERVER ]];then
echo -e "\e[8;1H\e[J\e[3;31mNote: configure server first\e[0m"
sleep 1
fn_server
main
fi
}
###################################################################
# checks for models and creates error message
fn_mcheck(){
if [[ -z $D_SERVER ]];then
 echo -e "\e[8;1H\e[J\e[3;31mNote: configure server first\e[0m"
fi
LIST=($(ollama ls | awk 'NR>=2 {print $1}' | sort ))
if [ ${#LIST[@]} -eq 0 ];then
    echo -e "\e[3;31mCannot find Models\e[0m"
fi
if [[ -z "$OLLAMA_HOST" ]]; then
    echo -e "\e[3;31mOLLAMA_HOST variable is not set\e[0m"
fi
}
###################################################################
# Checks for all needed files
fn_fcheck(){ # Update this to your desired directory
files=("ollama.conf" "ollama_pullable.txt" "ollama_versions.txt")
for file in "${files[@]}"; do
    if [ ! -f "$CONF_DIR/$file" ]; then
        echo -e "\e[3;35mCreating file:\e[0m $file"
        touch "$CONF_DIR/$file"  # Create the file if it does not exist
    fi
done
}
###################################################################
# reloads conf file
fn_reload() {
    D_SERVER=$(grep '^server=' "$CONFIG" | cut -d '=' -f2 | tr -d '"')
    D_MODEL=$(grep '^model='  "$CONFIG" | cut -d '=' -f2 | tr -d '"')
    OLLAMA_HOST="http://$D_SERVER:$PORT"
}
###################################################################
# Main
# Sourcing OLLAMA_HOST var
main(){
setterm --cursor off
# Checks
echo -e "\e[1;1H\e[J\e[3;32m Running Checks...\e[0m"
fn_reload
fn_fcheck
fn_scheck
fn_mcheck
# Display
echo -ne "\e[1;1H\e[J\e[35m[Quit]\e[0m \e[33m[Main]\e[0m\n"
echo -ne "\e[3;15H\e[J\e[33mServer:\e[0m $D_SERVER    \e[33m Model:\e[0m $D_MODEL    \e[33mVersion:\e[0m $OLLAMA_CVER\e[0m"  | column
echo
fn_center "[Current]" "\e[34m"
printf '=%.0s' $(seq 1 $(tput cols))
echo
echo
echo -e "\e[33m[\e[0m\e[36mY\e[0m\e[33m]\e[0m  Use Current"
echo -e "\e[33m[\e[0m\e[36mS\e[0m\e[33m]\e[0m  Set New Server"
echo -e "\e[33m[\e[0m\e[36mM\e[0m\e[33m]\e[0m  Set New Model"
echo -e "\e[33m[\e[0m\e[36mP\e[0m\e[33m]\e[0m  Pull New Model"
echo -e "\e[33m[\e[0m\e[36mR\e[0m\e[33m]\e[0m  Refresh Model List"
echo -e "\e[33m[\e[0m\e[36mI\e[0m\e[33m]\e[0m  Model Info"
echo -e "\e[33m[\e[0m\e[36mU\e[0m\e[33m]\e[0m  Update Ollama"
echo -e "\e[33m[\e[0m\e[36mD\e[0m\e[33m]\e[0m  Delete Model"
echo
read -p "Select:  " DEF
echo
case "$DEF" in
    Y|y) fn_default && return && main;;
    S|s) fn_server && return && main;;
    M|m) fn_llms && return && main;;
    P|p) fn_pull && return && main;;
    R|r) fn_update && return && main;;
    I|i) fn_info && return && main;;
    U|u) fn_upollama && return && main;;
    D|d) fn_delete && return && main;;  
    Q|q) exit 0;;  
    *) main;; 
esac
}
###################################################################
# Running hte Script
fn_release
main
