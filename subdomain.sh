#!/bin/bash
shopt -s expand_aliases
source ~/.bash_alias
set -e
figlet "MRX_B15H4L" | lolcat
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
if [ -d "recon/$1" ]; then
    echo "Directory Exist Maybe already scanned....."
else
    echo "Creating Directory....."
    mkdir recon/$1/
    mkdir recon/$1/upload
    mkdir /var/www/html/results/$1
fi
if [ ! -f $1 ]; then
    echo "subdomain_list not exist"
    rm -r recon/$1
    exit
else
    cp $1 recon/$1/target_list
fi

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
cd ~/recon/$1/

echo "Retriving subdomains with findomain......"
split -l 5 --additional-suffix=.split target_list
for s in ~/recon/$1/*.split
do
    findom $s
done
rm *.split
sort *.txt -u | puredns resolve -r ~/wordlist/resolvers.txt --write "$1.tmp" &>/dev/null &
echo "Resolving findomain subdomains....."
wait
sort "$1.tmp" > "$1.fd"
rm *.tmp
echo "Resolving done."
new=$(sort "$1.fd" | wc -l)
printf "%d New Subdomains Found\n" $new

echo "Bruteforce level 1 starting....."
split -l 5 --additional-suffix=.split "$1.fd"
for s in ~/recon/$1/*.split
do
    bruteforce $s
done
rm *.split
echo "level 1 complete"
sort *.tmp -u > "$1.tmp"
sort "$1.tmp" > "$1.brute1"
rm *.tmp

comm "$1.fd" "$1.brute1" -13 > "$1.tmp"
new=$(sort "$1.tmp" | wc -l)
printf "%d New Subdomains Found\n" $new
if [ $new -ge 1 ]
then
    echo "Bruteforce level 2 starting....."
    split -l 5 --additional-suffix=.split "$1.tmp"
    for s in ~/recon/$1/*.split
    do
        bruteforce $s
    done
    rm *.split
    echo "level 2 complete"
    sort *.tmp -u | sort > "$1.brute2"
    rm *.tmp

    comm "$1.brute1" "$1.brute2" -13 > "$1.tmp"
    new=$(sort "$1.tmp" | wc -l)
    printf "%d New Subdomains Found\n" $new
    if [ $new -ge 1 ]
    then
        echo "Bruteforce level 3 starting....."
        
        split -l 5 --additional-suffix=.split "$1.tmp"
        for s in ~/recon/$1/*.split
        do
            bruteforce $s
        done
        rm *.split
        echo "level 3 complete"
        sort *.tmp -u > "$1.brute3"
        rm *.tmp
    fi
fi
sort "$1.fd" "$1.brute"* -u | sort > "$1.sub"
echo "Starting DnsGen level 1"
split -l 5 --additional-suffix=.split "$1.sub"
for s in ~/recon/$1/*.split
do
    dnsg $s
done
sort *.tmp -u > "$1.tmp"
sort "$1.tmp" > "$1.gen1"
rm *.tmp
comm "$1.sub" "$1.gen1" -13 > "$1.tmp"
new=$(sort "$1.tmp" | wc -l)
if [ $new -ge 1 ]
then
    echo "Starting DnsGen level 2"
    split -l 5 --additional-suffix=.split "$1.tmp"
    for s in ~/recon/$1/*.split
    do
        dnsg $s
    done
    rm *.split
    sort *.tmp -u > "$1.tmp"
    sort "$1.tmp" > "$1.gen2"
    rm *.tmp
fi
sort "$1.gen"* -u | sort > "$1.gen"
comm "$1.sub" "$1.gen" -13 > "$1.tmp" 
new=$(sort "$1.tmp" | wc -l)
printf "%d New Subdomains Found\n" $new
if [ $new -ge 1 ]
then
    echo "Bruteforce level Ultimae starting....."
    split -l 5 --additional-suffix=.split "$1.tmp"
    for s in ~/recon/$1/*.split
    do
        bruteforce $s
    done
    rm *.split
    echo "level Ultimate complete"
    sort *.tmp -u | sort > "$1.bruteu"
    rm *.tmp

    comm "$1.gen" "$1.bruteu" -13 > "$1.tmp"
    new=$(sort "$1.tmp" | wc -l)
    printf "%d New Subdomains Found\n" $new
    if [ $new -ge 1 ]
    then
        echo "Starting DnsGen level Ultimate"
        split -l 5 --additional-suffix=.split "$1.tmp"
        for s in ~/recon/$1/*.split
        do
            dnsg $s
        done
        rm *.split
        sort *.tmp -u | sort > "$1.genu"
        rm *.tmp
        echo "DnsGen level Ultimate completed"
        new=$(sort "$1.genu" | wc -l)
        printf "%d New Subdomains Found\n" $new
    fi
fi

sort "$1.sub" "$1.gen" "$1.bruteu" "$1.genu" -u > "upload/$1.subdomain.txt"
curl "https://api.telegram.org/bot6102545432:AAHLTE0SdQ7neK5Q2D2gmrGheDJc8ew6uN8/sendMessage?chat_id=847743133&text=Subdomain Scan Completed for $1 now scanning for low-hanging bugs."
echo "checking for possible takeovers....."
dnsreaper "upload/$1.subdomain.txt" > "upload/$1.dnsreaper.txt" &
takeover -l "upload/$1.subdomain.txt" -o "upload/$1.takeover.txt" &>/dev/null &
subjack -w "upload/$1.subdomain.txt" -t 100 -timeout 30 -o "upload/$1.subjack.txt" -ssl &>/dev/null &
tko-subs -domains "upload/$1.subdomain.txt" -output "upload/$1.tko-subs.csv" &>/dev/null &
wait

echo "Starting Nuclei....."
naabu -l "upload/$1.subdomain.txt" -silent -o "upload/$1.ports.txt"
nuclei -l "upload/$1.ports.txt" -t mrx -o "upload/$1.nuclei.txt" -silent &>/dev/null

echo "Collecting Parameters....."
split -l 5 --additional-suffix=.split "upload/$1.subdomain.txt"
for s in ~/recon/$1/*.split
do
    params "$s"
done
sort output/*.tmp -u | gf interestingparams | tee "params.tmp"
param-fiilter
rm *.tmp *.split

echo "finished now uploading files"
zip $1 upload/$1.*
mv $1.zip /var/www/html/results
cp -R upload/$1.* /var/www/html/results/$1
curl "https://api.telegram.org/bot6102545432:AAHLTE0SdQ7neK5Q2D2gmrGheDJc8ew6uN8/sendMessage?chat_id=847743133&text=Scan with nuclei Completed and files uploaded for $1. Download results from http://bugcrowd.tech/results/$1/"
