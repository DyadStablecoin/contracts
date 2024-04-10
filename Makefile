include .env

ifdef FILE
  matchFile = --match-contract $(FILE)
endif
ifdef FUNC
  matchFunction = --match $(FUNC)
endif

test = forge test $(matchFile) $(matchFunction)
# fork-block-number = --fork-block-number 18941929 #16386958

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

build:
	forge build --via-ir

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

# deploy vault on goerli
gdeployVault:
	forge script script/deploy/Deploy.Vault.Goerli.s.sol --rpc-url $(GOERLI_RPC) --sender $(PUBLIC_KEY) --broadcast --verify -i 1 -vvvv

# deploy vault on mainnet
mdeployVault:
	forge script script/deploy/Deploy.Vault.Mainnet.s.sol --rpc-url $(MAINNET_RPC) --sender 0x4794d0E92E4C01AF3473839749826394a7FB770A --broadcast --verify -i 1 -vvvv

transferWsteth:
	forge script script/mock/transfer.wsteth.s.sol   --rpc-url http://127.0.0.1:8545 --broadcast --sender 0x176F3DAb24a159341c0509bB36B833E7fdd0a132 --unlocked
	
# deploy staking contracts on goerli
gdeployStaking:
	forge script script/deploy/Deploy.Staking.Goerli.s.sol --rpc-url $(SEPOLIA_RPC) --sender $(PUBLIC_KEY) --broadcast --verify -i 1 -vvvv
	
# deploy on sepolia
sdeploy:
	forge script script/deploy/Deploy.All.Sepolia.s.sol --rpc-url $(SEPOLIA_RPC) --sender 0x475F89AFe082b1e769789d70e045041c029fC8D3 --broadcast --verify -i 1 -vvvv --via-ir
	
# deploy on mainnet
# mdeployKerosine:
# 	forge script script/deploy/Deploy.Mainnet.Kerosine.s.sol --rpc-url $(MAINNET_RPC) --sender 0x475F89AFe082b1e769789d70e045041c029fC8D3 --broadcast --verify -i 1 -vvvv --via-ir
	
# deploy kerosine on mainnet
mdeployKerosine:
	forge script script/deploy/Deploy.Kerosine.Mainnet.s.sol --rpc-url $(MAINNET_RPC) --sender 0xEEB785F7700ab3EBbD084CE22f274b4961950d9A --broadcast --verify -i 1 -vvvv --via-ir --optimize
	
# deploy kerosine on mainnet
mdeployStaking:
	forge script script/deploy/Deploy.Staking.sol --rpc-url $(MAINNET_RPC) --sender 0xEEB785F7700ab3EBbD084CE22f274b4961950d9A --broadcast --verify -i 1 -vvvv --via-ir --optimize
	
# deploy kerosine vaults on mainnet
mdeployKeroseneVaults:
	forge script script/deploy/Deploy.Kerosene.Vaults.s.sol --rpc-url $(MAINNET_RPC) --sender 0xEEB785F7700ab3EBbD084CE22f274b4961950d9A --broadcast --verify -i 1 -vvvv --via-ir --optimize

mDeployV2:
	forge script script/deploy/Deploy.V2.s.sol --rpc-url $(MAINNET_RPC) --sender 0xEEB785F7700ab3EBbD084CE22f274b4961950d9A --broadcast --verify -i 1 -vvvv --via-ir --optimize

forkTestV2:
	forge test --match-contract V2 --fork-url $(MAINNET_RPC) --fork-block-number 19621640 -vvvv
