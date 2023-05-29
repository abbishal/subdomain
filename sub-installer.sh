#!/bin/bash
figlet "MRX_B15H4L" | lolcat

installer(){
    echo "Installing Script dependencies......."
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y git make perl wget curl python3 python-is-python3 python3-pip libpcap-dev apache2 figlet lolcat tmux

    echo 'alias tmux="tmux attach || tmux"' >> "$HOME/.bashrc"

    echo "installing GO"
	sys=$(uname -m)
	LATEST=$(curl -s 'https://go.dev/VERSION?m=text')
	[ $sys == "x86_64" ] && "wget https://golang.org/dl/$LATEST.linux-amd64.tar.gz" -O golang.tar.gz &>/dev/null || wget "https://golang.org/dl/$LATEST.linux-386.tar.gz" -O golang.tar.gz &>/dev/null
	sudo tar -C /usr/local -xzf golang.tar.gz
	echo "export GOROOT=/usr/local/go" >> "$HOME/.bashrc"
	echo "export GOPATH=$HOME/go" >> "$HOME/.bashrc"
	echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >> "$HOME/.bashrc"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.profile"
    source "$HOME/.bashrc"

    echo "installing main tools"
    go install github.com/d3mondev/puredns/v2@latest &>/dev/null
    go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest &>/dev/null
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest &>/dev/null
    go install -v github.com/OWASP/Amass/v3/...@latest &>/dev/null
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest &>/dev/null
    go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest &>/dev/null
    nuclei &>/dev/null
    rm -r nuclei-templates/ssl
    grep "severity: info" nuclei-templates -r -l | xargs rm
    rm -r nuclei-templates/http/cves/20{00..17}

    mkdir ~/tools ; cd ~/tools || exit
    git clone https://github.com/abbishal/dnsReaper &>/dev/null
    pip install -r dnsReaper/requirements.txt &>/dev/null
    echo 'alias dnsreaper="python3 ~/tools/dnsReaper/main.py file --filename"' >> "$HOME/.bashrc"
    git clone https://github.com/abbishal/cname &>/dev/null
    pip install -r cname/requirements.txt &>/dev/null
    echo 'alias cname="python ~/tools/cname/cname.py"' >> "$HOME/.bashrc"
    git clone https://github.com/FortyNorthSecurity/EyeWitness &>/dev/null
    sudo EyeWitness/Python/setup/setup.sh &>/dev/null
    echo 'alias eyewitness="python ~/tools/EyeWitness/Python/EyeWitness.py --web -f"' >> "$HOME/.bashrc"
    wget https://raw.githubusercontent.com/abbishal/subdomain/main/subdomain.sh &>/dev/null
        echo "alias sub=~/tools/subdomain.sh" >> "$HOME/.bashrc"

    git clone https://github.com/blechschmidt/massdns.git &>/dev/null
    cd massdns
    make &>/dev/null
    sudo make install &>/dev/null
    cd ..

    curl -LO https://github.com/findomain/findomain/releases/latest/download/findomain-linux.zip &>/dev/null
    unzip findomain-linux.zip &>/dev/null
    chmod +x findomain
    sudo mv findomain /usr/bin/findomain
    rm findomain-linux.zip
    cd ~ || exit


    echo "Downloading Wordlists...."
    mkdir ~/wordlist ; cd ~/wordlist || exit
    wget https://gist.githubusercontent.com/six2dez/ffc2b14d283e8f8eff6ac83e20a3c4b4/raw/8f9fa10e35ddc5f3ef4496b72da5c5cad3f230bf/permutations_list.txt &>/dev/null
    wget https://raw.githubusercontent.com/assetnote/commonspeak2-wordlists/master/subdomains/subdomains.txt &>/dev/null
    wget https://raw.githubusercontent.com/bp0lr/dmut-resolvers/main/resolvers.txt &>/dev/null
    cd ~ || exit
    wget https://raw.githubusercontent.com/abbishal/subdomain/main/.sub_alias &>/dev/null
    echo "source ~/.sub_alias" >> "$HOME/.bashrc"


}

