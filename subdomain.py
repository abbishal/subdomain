#!/usr/bin/python
from os import makedirs,system,remove,path,getenv,chdir
from sys import argv
from wget import *
from glob import glob
from requests import get
cpath = path.exists

#functions
def wordlists():
    cpath(permutations) or download("https://gist.githubusercontent.com/six2dez/ffc2b14d283e8f8eff6ac83e20a3c4b4/raw/8f9fa10e35ddc5f3ef4496b72da5c5cad3f230bf/permutations_list.txt")
    cpath(combined) or download("https://github.com/danielmiessler/SecLists/raw/master/Discovery/DNS/combined_subdomains.txt")
    input("\nDo you want to update resolvers list? (yes)\n") == "yes" and ResolverUpdate()


def DeleteMultiple(ext):
    for i in glob(f".{ext}"):
        remove(i)

def ResolverUpdate():
    remove(resolver)
    download("https://raw.githubusercontent.com/bp0lr/dmut-resolvers/main/resolvers.txt")

def findomain(domains):
    print("Starting findomain.....")
    with open(domains) as f:
        for domain in f.readlines():
            domain = domain.strip()
            system(f"findomain -t {domain} -u {domain}.tmp &>/dev/null")
    wait()
    system("wait")
    system(f"""sort *.tmp -u | sort | puredns resolve -r {resolver} --write {target}.fd &""")
    print("Resolving subdomains")
    DeleteMultiple("tmp")
    wait
    print("Resolving finished.")
    total = system(f"sort {target}.fd | wc -l")
    print(f"Total Domains Found: {total}")

def bruteforce(target, c):
    print(f"Bruteforce Level {c} starting.....")
    system(f"split -l 100 --additional-suffix=.split {target}")
    #split
    for i in glob("*.split"):
        with open(f"{i}") as f:
            for domain in f.readlines():
                system(f"puredns bruteforce {combined} {target} -r {resolver} --write {domain}.tmp &")
        wait
    DeleteMultiple("split")
    system(f"sort *.tmp -u |sort > {target}.brute{c}")
    DeleteMultiple("tmp")
    if c == 1:
        system(f"comm {target}.fd {target}.brute1 -13 > {target}.new")
    elif c == 2:
        system(f"comm {target}.brute1 {target}.brute2 -13 > {target}.new")
    else:
        system(f"comm {target}.brute2 {target}.brute3 -13 > {target}.new")
    total = system(f"sort {target}.new | wc -l")
    print(f"Bruteforce Level {c} Completed.\n")
    print(f"Total New Subdomain Found: {total}")
    return total

def dnsgen(target, c):
    print(f"DnsGen Level {c} starting.....")
    split
    for i in glob("*.split"):
        with open(f"{i}") as f:
            for domain in f.readlines():
                system(f"echo {domain} | dnsgen -w {permutations} - | puredns resolve -r {resolver} --write {domain}.tmp &")
        wait
    DeleteMultiple("split")
    system(f"sort *.tmp -u | sort > {target}.gen{c}")
    DeleteMultiple("tmp")
    if c == 1:
        system(f"comm {target}.brute {target}.gen1 -13 > {target}.new")
    elif c == 2:
        system(f"comm {target}.gen1 {target}.gen2 -13 > {target}.new")
    else:
        system(f"comm {target}.brute2 {target}.gen3 -13 > {target}.new")
    total = system(f"sort {target}.new | wc -l")
    print(f"DnsGen Level {c} Completed.")
    print(f"Total New Subdomain Found: {total}")
    return total

#check arguments
if len(argv) != 2:
    print(f"Usage: {argv[0]} Target_list")
    exit()
cpath(argv[1]) or print("Target_list not exist") & exit()

print("Getting things ready.....")
target = argv[1]
home = getenv("HOME")
output = f"{home}/recon/{target}/uploads"
working_directory = f"{home}/recon/{target}/"
split = system(f"split -l 100 --additional-suffix=.split {target}")
resolver = f"{home}/resolvers.txt"
target_list = f"{home}/recon/{target}/target_list"
permutations = f"{home}/permutations_list.txt"
combined = f"{home}/combined_subdomains.txt"
cpath(f"{home}/recon/{target}/uploads") or makedirs(f"{home}/recon/{target}/uploads")
system(f"cp {target} {target_list}")
chdir(working_directory)


print("Checking wordlist.......")
wordlists()
findomain(target_list)
if bruteforce(f"{target}.fd", 1) >= 1:
    if bruteforce(f"{target}.new", 2) >= 1:
        bruteforce(f"{target}.new", 3)
system(f"sort {target}.fd {target}.brute* -u | sort > {target}.brute")

#dnsgen
system(f"touch {target}.gen1")
if dnsgen(f"{target}.brute", 1) >= 1:
    if dnsgen(f"{target}.new", 2) >= 1:
        dnsgen(f"{target}.new", 3)
system(f"sort {target}.brute {target}.gen* -u | sort > {output}/")
get(f"https://api.telegram.org/bot6102545432:AAHLTE0SdQ7neK5Q2D2gmrGheDJc8ew6uN8/sendMessage?chat_id=847743133&text=Subdomain Scan Completed for {target} now scanning for low-hanging bugs.")
