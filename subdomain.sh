#!/bin/bash
shopt -s expand_aliases
source ~/.sub_alias
figlet "MRX_B15H4L" | lolcat


# net(){
#     ping -c 1 google.com &>/dev/null
#     if [ $? -ne 0 ]; then
#         printf "Network problem identified." >> /var/www/html/sc.html
#         sleep 60
#         ping -c 1 google.com &>/dev/null
#         while [ $? -ne 0 ]; do
#             sleep 60
#             printf "." >> /var/www/html/sc.html
#             ping -c 1 google.com &>/dev/null
#         done
#     fi
# }

intialize() {
    echo "Checking if dependencies installed........" 
    cd ~/wordlist || exit
    if [ ! -f permutations_list.txt ]; then
        wget https://gist.githubusercontent.com/six2dez/ffc2b14d283e8f8eff6ac83e20a3c4b4/raw/8f9fa10e35ddc5f3ef4496b72da5c5cad3f230bf/permutations_list.txt &>/dev/null
    fi
    if [ ! -f subdomains.txt ]; then
        wget https://raw.githubusercontent.com/assetnote/commonspeak2-wordlists/master/subdomains/subdomains.txt
    fi
    echo "done"
    echo "Updating resolvers....."
    rm resolvers.txt
    wget https://raw.githubusercontent.com/bp0lr/dmut-resolvers/main/resolvers.txt &>/dev/null
    echo "done"
}

passive() {
    for i in $(cat $1)
    do
        findomain -t "$i" --external-subdomains -o &>/dev/null &
        assetfinder --subs-only "$i" | sort -u > "$i.assetfinder.txt" &
    done
    wait
}
bruteforce() {
    for i in $(cat $1)
    do
        if ( dig @8.8.8.8 -t A "wildcardtestbyabbishal.$i" | grep -q 'NXDOMAIN' ); then 
            puredns bruteforce ~/wordlist/subdomains.txt "$i" -r ~/wordlist/resolvers.txt --write "$i.tmp" &>/dev/null &

        else
            echo "wildcard.$i" >> "$output"
            sed -i '/"$i"/d' "$1"
        fi
    done
    wait

}

dnsg() {
    for i in $(cat $1)
    do
        if ( dig @8.8.8.8 -t A "wildcardtestbyabbishal.$i" | grep -q 'NXDOMAIN' ); then 
            echo "$i" | dnsgen -w ~/wordlist/permutations_list.txt - | puredns resolve -r ~/wordlist/resolvers.txt --write "$i.tmp" &>/dev/null &
        fi
    done
    wait
}


if [ $# -ne 1 ]
  then
    echo "Usage: $0 subdomain_list"
    exit
fi
if [ -d ~/"recon/$1" ]; then
    echo "Directory Exist Maybe already scanned....."
else
    echo "Creating Directory....."
    mkdir -p ~/recon/$1/
    mkdir -p /var/www/html/scans/$1/
fi
if [ ! -f $1 ]; then
    echo "subdomain_list not exist"
    exit
else
    cp $1 ~/recon/$1/target_list
fi

intialize
output="/var/www/html/scans/$1/subdomains.txt"

cd ~/recon/$1/ || exit

echo "Retriving subdomains with Passively......"
split -l 5 --additional-suffix=.split target_list
for s in ~/recon/$1/*.split
do
    passive $s
    #net
done
rm *.split
sort *.txt -u | puredns resolve -r ~/wordlist/resolvers.txt --write "$1.fd" &>/dev/null &
echo "Resolving Those subdomains....."
wait
sort "$1.fd" target_list -u > "$1.new0"
rm *.txt
echo "Resolving done."
counter=0
new=$(wc -l < "$1.new$counter")
printf "%d New Subdomains Found\n" $new
sort "$1.new$counter" > "$output"
while [ $new -ge 1 ]; do
    ((counter=counter+1))
    printf "Bruteforce level %d starting.....\n" $counter
    split -l 10 --additional-suffix=.split "$1.new$(($counter-1))"
    total=$(sort "$1.new$(($counter-1))" | wc -l)
    scanned=0
    for s in ~/recon/$1/*.split
    do
        bruteforce $s
        ((scanned=scanned+10))
        if [ $scanned -lt $total ]; then
            printf "<b>Bruteforce level %d Running.</b><br>Total %d Domains scanned out of %d<br>" $counter $scanned $total > /var/www/html/sc.html
        else
            printf "<b>Bruteforce level %d Completed.</b><br>Total %d Domains scanned.<br>" $counter $total > /var/www/html/sc.html
        fi
        #net
    done
    sort *.tmp -u > "$1.brute$counter"
    rm *.tmp

    scanned=0
    printf "DnsGen level %d starting.....\n" $counter
    for s in ~/recon/$1/*.split
    do
        dnsg $s
        ((scanned=scanned+10))
        if [ $scanned -lt $total ]; then
            printf "<b>DnsGen level %d Running.</b><br>Total %d Domains scanned out of %d<br>" $counter $scanned $total > /var/www/html/sc.html
        else
            printf "<b>DnsGen level %d Completed.</b><br>Total %d Domains scanned.<br>" $counter $total > /var/www/html/sc.html
        fi
        #net
    done
    sort *.tmp -u > "$1.gen$counter"
    printf "DnsGen level %d Completed.\n" $counter


    sort "$1.brute$counter" "$1.gen$counter" -u | sort > "$1.tmp"
    sort "$output" > "$1.old"
    comm "$1.old" "$1.tmp" -13 > "$1.new$counter"
    rm *.tmp *.split
    new=$(wc -l < "$1.new$counter")
    printf "%d New Subdomains Found\n" $new

    sort "$1.new$counter" >> "$output"
done

cd "/var/www/html/scans/$1/" || exit
echo "checking for possible takeovers....."
dnsreaper subdomains.txt --out dnsreaper.txt &>/dev/null &
takeover -l subdomains.txt -o takeover.txt &>/dev/null &
dnsx -l subdomains.txt -cname -ns -resp -o dnsx.txt &>/dev/null &
wait
echo "Starting Nuclei....."
naabu -l subdomains.txt -ec -silent | httpx -silent -o httpx.txt &>/dev/null

eyewitness httpx.txt --user-agent "Hackerone" -d eye &>/dev/null
nuclei -l httpx.txt -o nuclei.txt -silent &>/dev/null
echo "Scan completed"
curl "https://api.telegram.org/bot6102545432:AAHLTE0SdQ7neK5Q2D2gmrGheDJc8ew6uN8/sendMessage?chat_id=847743133&text=All+Scan+Completed+for+$1" &>/dev/null
