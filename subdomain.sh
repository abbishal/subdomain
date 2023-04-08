#!/bin/bash
figlet "MRX_B15H4L" | lolcat

bruteforce() {
    for i in $(cat $1):
    do
        puredns bruteforce ~/combined_subdomains.txt "$i" -r ~/resolvers.txt --write "$i.tmp" &>/dev/null &
    done
    wait

}

dnsg() {
    for i in $(cat $1)
    do
        echo $i | dnsgen -w ~/permutations_list.txt - | puredns resolve -r ~/resolvers.txt --write "$i.tmp" &>/dev/null &
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
    mkdir recon/$1/zips
fi
if [ ! -f $1 ]; then
    echo "subdomain_list not exist"
    rm -r recon/$1
    exit
else
    cp $1 recon/$1/target_list
fi

echo "Checking if dependencies installed........"
#for i in findomain puredns dnsgen 
cd ~/wordlist
if [ ! -f permutations_list.txt ]; then
    wget https://gist.githubusercontent.com/six2dez/ffc2b14d283e8f8eff6ac83e20a3c4b4/raw/8f9fa10e35ddc5f3ef4496b72da5c5cad3f230bf/permutations_list.txt &>/dev/null
fi
if [ ! -f combined_subdomains.txt ]; then
    wget https://github.com/danielmiessler/SecLists/raw/master/Discovery/DNS/combined_subdomains.txt &>/dev/null
fi
echo done

echo "Updating resolvers....."
rm resolvers.txt
wget https://raw.githubusercontent.com/bp0lr/dmut-resolvers/main/resolvers.txt &>/dev/null
echo done
cd ~/recon/$1/
for i in $(cat target_list)
do
    findomain -t "$i" --external-subdomains -o &>/dev/null &
done
echo "Retriving subdomains with findomain......"
wait
sort *.txt -u | puredns resolve -r ~/resolvers.txt --write "$1.tmp" &>/dev/null &
echo "Resolving findomain subdomains....."
wait
sort "$1.tmp" > "$1.fd"
rm *.tmp *.txt
echo "Resolving done."
echo "Bruteforce level 1 starting....."
split -l 50 --additional-suffix=.split "$1.fd"
for s in ~/recon/okx/*.split
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
printf "%d New Subdomains Found\n" new
if [ $new -ge 1 ]
then
    echo "Bruteforce level 2 starting....."
    split -l 50 --additional-suffix=.split "$1.tmp"
    for s in ~/recon/okx/*.split
    do
        bruteforce $s
    done
    rm *.split
    echo "level 2 complete"
    sort *.tmp -u | sort > "$1.brute2"
    rm *.tmp

    comm "$1.brute1" "$1.brute2" -13 > "$1.tmp"
    new=$(sort "$1.tmp" | wc -l)
    printf "%d New Subdomains Found\n" new
    if [ $new -ge 1 ]
    then
        echo "Bruteforce level 3 starting....."
        
        split -l 50 --additional-suffix=.split "$1.tmp"
        for s in ~/recon/okx/*.split
        do
            bruteforce $s
        done
        rm *.split
        echo "level 3 complete"
        sort *.tmp -u > "$1.brute3"
        rm *.tmp
    fi
fi
sort "$1.fd" "$1.brute*" -u > "$1.tmp"
sort "$1.tmp" > "$1.sub"
split -l 50 --additional-suffix=.split "$1.sub"
for s in ~/recon/okx/*.split
do
    dnsg $s
done
sort *.tmp -u > "$1.tmp"
sort "$1.tmp" > "$1.gen1"
rm *.tmp
comm "$1.sub" "$1.gen1" -13 > "$1.tmp"
new=$(sort "$1.tmp" | wc -l)
printf "%d New Subdomains Found\n" new
if [ $new -ge 1 ]
then
    split -l 50 --additional-suffix=.split "$1.tmp"
    for s in ~/recon/okx/*.split
    do
        dnsg $s
    done
    rm *.split
    sort *.tmp -u > "$1.tmp"
    sort "$1.tmp" > "$1.gen2"
    rm *.tmp
fi
sort "$1.sub" "$1.gen*" -u > "upload/$1.subdomain.txt"
curl "https://api.telegram.org/bot6102545432:AAHLTE0SdQ7neK5Q2D2gmrGheDJc8ew6uN8/sendMessage?chat_id=847743133&text=Subdomain Scan Completed for $1 now scanning for low-hanging bugs."
