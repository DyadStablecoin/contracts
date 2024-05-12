from web3 import Web3

RPC = "http://127.0.0.1:8545"

IMPERSONATOR = "0x9fbB12Ea7DC6dE6503b35dA4389DB3aecf8E4282"

ANVIL_PUBLIC_KEY = "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
ANVIL_PRIVATE_KEY = "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"

# NOTE: !!!Make sure to set the recipient in the forge script!!!!
if __name__ == "__main__":
  web3 = Web3(Web3.HTTPProvider(RPC))

  amount_in_wei = web3.toWei(1, 'ether')  

  transaction = {
      'to':       IMPERSONATOR,
      'value':    amount_in_wei,
      'gas':      21000,  
      'gasPrice': web3.toWei('50', 'gwei'),  # Gas price (in Gwei)
      'nonce':    web3.eth.get_transaction_count(ANVIL_PUBLIC_KEY),
      'chainId':  web3.eth.chain_id
  }

  signed_tx = web3.eth.account.sign_transaction(transaction, ANVIL_PRIVATE_KEY)
  tx_hash = web3.eth.send_raw_transaction(signed_tx.rawTransaction)
  print("Sending ETH to:", IMPERSONATOR)

  balance = web3.eth.get_balance(IMPERSONATOR)
  print("Balance of", IMPERSONATOR, "is", balance)

  web3.provider.make_request("anvil_impersonateAccount", [IMPERSONATOR])  
  print("Impersonating:", IMPERSONATOR)

  # Can we call `make transfer` from here?
  import subprocess

  # this will call the forge script that will transfer the tokens
  subprocess.run(["make", f"IMPERSONATOR={IMPERSONATOR}", "transfer"])
