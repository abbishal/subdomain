#!/bin/bash
shopt -s expand_aliases
source ~/.bash_alias
set -e
figlet "MRX_B15H4L" | lolcat

net(){
    ping -c 1 google.com &>/dev/null
    while [ $? -ne 0 ]; do
        echo "Network problem occured"
        sleep 60
        echo "Checking Network again...."
        ping -c 1 google.com &>/dev/null
    done
}
checking() {
    echo "Checking if dependencies installed........" 
    cd ~/wordlist
    if [ ! -f permutations_list.txt ]; then
        wget https://gist.githubusercontent.com/six2dez/ffc2b14d283e8f8eff6ac83e20a3c4b4/raw/8f9fa10e35ddc5f3ef4496b72da5c5cad3f230bf/permutations_list.txt &>/dev/null
    fi
    if [ ! -f combined_subdomains.txt ]; then
        wget https://github.com/danielmiessler/SecLists/raw/master/Discovery/DNS/combined_subdomains.txt &>/dev/null
    fi
    echo "done"

    echo "Updating resolvers....."
    rm resolvers.txt
    wget https://raw.githubusercontent.com/bp0lr/dmut-resolvers/main/resolvers.txt &>/dev/null
    echo "done"
}

findom() {
    for i in $(cat $1)
    do
        findomain -t "$i" --external-subdomains -o &>/dev/null &
    done
    wait
}
bruteforce() {
    for i in $(cat $1)
    do
        puredns bruteforce ~/wordlist/combined_subdomains.txt "$i" -r ~/wordlist/resolvers.txt --write "$i.tmp" &>/dev/null &
    done
    wait

}

dnsg() {
    for i in $(cat $1)
    do
        echo $i | dnsgen -w ~/wordlist/permutations_list.txt - | puredns resolve -r ~/wordlist/resolvers.txt --write "$i.tmp" &>/dev/null &
    done
    wait
}

params() {
    for i in $(cat $1)
    do
        paramspider --domain "$i" --level high --output "$i".tmp &>/dev/null &
    done
    wait
}

if [ $# -ne 1 ]
  then
    echo "Usage: $0 subdomain_list"
    exit
fi
if [ -d "~/recon/$1" ]; then
    echo "Directory Exist Maybe already scanned....."
else
    echo "Creating Directory....."
    mkdir ~/recon/$1/
    mkdir ~/recon/$1/upload
    mkdir /var/www/html/results/$1
fi
if [ ! -f $1 ]; then
    echo "subdomain_list not exist"
    rm -r ~/recon/$1
    exit
else
    cp $1 ~/recon/$1/target_list
fi

checking
cd ~/recon/$1/

echo "Retriving subdomains with findomain......"
split -l 5 --additional-suffix=.split target_list
for s in ~/recon/$1/*.split
do
    findom $s
    net
done
rm *.split
sort *.txt -u | puredns resolve -r ~/wordlist/resolvers.txt --write "$1.fd" &>/dev/null &
echo "Resolving findomain subdomains....."
wait
sort "$1.fd" > "$1.new0"
rm *.tmp
echo "Resolving done."
counter=0
new=$(wc -l < "$1.new$counter")
printf "%d New Subdomains Found\n" $new

while [ $new -ge 1 ]; do
    ((counter=counter+1))
    printf "Bruteforce level %d starting.....\n" $counter
    split -l 10 --additional-suffix=.split "$1.new$(($counter-1))"
    for s in ~/recon/$1/*.split
    do
        bruteforce $s
        net
    done
    sort *.tmp -u > "$1.brute$counter"
    rm *.tmp

    printf "DnsGen level %d starting.....\n" $counter
    for s in ~/recon/$1/*.split
    do
        dnsg $s
        net
    done
    sort *.tmp -u > "$1.gen$counter"
    printf "DnsGen level %d Completed.\n" $counter

    sort "$1.brute$counter" "$1.gen$counter" -u | sort > "$1.tmp"
    comm "$1.new$(($counter-1))" "$1.tmp" -13 > "$1.new$counter"
    rm *.tmp *.split
    new=$(wc -l < "$1.new$counter")
    printf "%d New Subdomains Found\n" $new
    
done

sort "$1.new"* -u > "upload/$1.subdomain.txt"
curl "https://api.telegram.org/bot6102545432:AAHLTE0SdQ7neK5Q2D2gmrGheDJc8ew6uN8/sendMessage?chat_id=847743133&text=Subdomain Scan Completed for $1 now scanning for low-hanging bugs."
echo "checking for possible takeovers....."
dnsreaper "upload/$1.subdomain.txt" > "upload/$1.dnsreaper.txt" &
takeover -l "upload/$1.subdomain.txt" -o "upload/$1.takeover.txt" &>/dev/null &
wait

echo "Starting Nuclei....."
naabu -l "upload/$1.subdomain.txt" -silent -o "upload/$1.naabu.txt"
nuclei -l "upload/$1.naabu.txt" -t mrx -o "upload/$1.nuclei.txt" -silent &>/dev/null

zip $1 upload/$1.*
mv $1.zip /var/www/html/results
cp -R upload/$1.* /var/www/html/results/$1
curl "https://api.telegram.org/bot6102545432:AAHLTE0SdQ7neK5Q2D2gmrGheDJc8ew6uN8/sendMessage?chat_id=847743133&text=Scan with nuclei Completed and files uploaded for $1."
