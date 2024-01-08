include .env

ifdef FILE
  matchFile = --match-contract $(FILE)
endif
ifdef FUNC
  matchFunction = --match $(FUNC)
endif

test = forge test $(matchFile) $(matchFunction)
fork-block-number = --fork-block-number 18941929 #16386958

# test locally
t:
	$(test) -vv 
tt:
	$(test) -vvv 
ttt:
	$(test) -vvvv 

# test on fork
ft:
	$(test) -vv   --fork-url $(RPC) $(fork-block-number)
ftt:
	$(test) -vvv  --fork-url $(RPC) $(fork-block-number)
fttt:
	$(test) -vvvv --fork-url $(RPC)	$(fork-block-number)

# deploy on goerli
gdeploy:
	forge script script/deploy/Deploy.Goerli.s.sol --rpc-url $(GOERLI_RPC) --sender $(PUBLIC_KEY) --broadcast --verify -i 1 -vvvv

# deploy on mainnet
mdeploy:
	forge script script/deploy/Deploy.Mainnet.s.sol --rpc-url $(MAINNET_RPC) --sender $(PUBLIC_KEY) --broadcast --verify -i 1 -vvvv

pdeploy:
	forge script script/deploy/Deploy.Payments.s.sol --rpc-url $(MAINNET_RPC) --sender 0x7FCeD590Ae09843F32F6118382f67cC01CFcf511 --broadcast --verify -i 1 -vvvv

read:
	forge script script/Read.s.sol --rpc-url $(GOERLI_RPC) --fork-block-number 8416091

ldeploy:
	forge script script/deploy/Deploy.Mainnet.s.sol --fork-url http://localhost:8545 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast --verify -i 1 -vvvv

gdeployVault:
	forge script script/deploy/Deploy.Vault.Goerli.s.sol --rpc-url $(GOERLI_RPC) --sender $(PUBLIC_KEY) --broadcast --verify -i 1 -vvvv
