import subprocess
from web3 import Web3

RPC = "http://127.0.0.1:8545"

TOKEN_HOLDER = "0x9fbB12Ea7DC6dE6503b35dA4389DB3aecf8E4282"

ANVIL_PUBLIC_KEY = "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
ANVIL_PRIVATE_KEY = "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"

# NOTE: !!!Make sure to set the recipient in the forge script!!!!
if __name__ == "__main__":
  web3 = Web3(Web3.HTTPProvider(RPC))

  web3.provider.make_request("anvil_setBalance", [TOKEN_HOLDER, web3.toWei(1, 'ether')])  

  balance = web3.eth.get_balance(TOKEN_HOLDER)
  assert balance > 0
  print("Balance of", TOKEN_HOLDER, "is", balance)

  web3.provider.make_request("anvil_impersonateAccount", [TOKEN_HOLDER])  
  print("Impersonating token holder:", TOKEN_HOLDER)

  # calls the forge script that will transfer the tokens from the token holder
  subprocess.run(["make", f"TOKEN_HOLDER={TOKEN_HOLDER}", "transfer"])

  web3.provider.make_request("anvil_stopImpersonatingAccount", []) 
