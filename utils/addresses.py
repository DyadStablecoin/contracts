import json

P = "../broadcast/Deploy.Goerli.s.sol/5/run-latest.json"

f = open(P)
d = json.load(f)

# there are some dups that we need to filter out
contractNames = []
for k in d["transactions"]:
    contractName = k["contractName"]
    if  contractName not in contractNames:
        print(contractName.ljust(12), k["contractAddress"])
        contractNames.append(contractName)


