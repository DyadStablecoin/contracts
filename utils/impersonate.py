from web3 import Web3

holder = "0x176F3DAb24a159341c0509bB36B833E7fdd0a132"

def impersonate_account(web3: Web3, address: str):
    """
    Impersonate account through Anvil without needing private key
    :param address:
        Account to impersonate
    """
    web3.provider.make_request("anvil_impersonateAccount", [address])  


if __name__ == "__main__":
  PROVIDER = "http://127.0.0.1:8545"
  web3 = Web3(Web3.HTTPProvider(PROVIDER))
  impersonate_account(web3, holder)
