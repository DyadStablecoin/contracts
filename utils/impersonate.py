from web3 import Web3

ADDRESS = "0xDeD796De6a14E255487191963dEe436c45995813" # address to impersonate
RPC     = "http://127.0.0.1:8545"

if __name__ == "__main__":
  web3 = Web3(Web3.HTTPProvider(RPC))
  web3.provider.make_request("anvil_impersonateAccount", [ADDRESS])  