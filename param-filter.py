import requests

def check(url):
    try:
        r = requests.head(url)
        if r.status_code != 404:
            with open("upload/params.txt", "a") as w:
                w.write(url)

    except requests.ConnectionError:
        pass

dup = []
with open("params.txt", "r") as p:
    for i in p.readlines():
        if i.split("?")[0] not in dup:
            check(i)
            dup.append(i.split("?")[0])
