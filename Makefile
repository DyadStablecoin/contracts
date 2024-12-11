include .env

ifdef FILE
  matchFile = --match-contract $(FILE)
endif
ifdef FUNC
  matchFunction = --match-test $(FUNC)
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
	forge script script/mock/transfer.wsteth.s.sol \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast \
		--sender 0x2fEb1512183545f48f6b9C5b4EbfCaF49CfCa6F3 \
		--unlocked \
		--legacy
	
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
	forge clean
	forge test $(matchFile) $(matchFunction) \
		--fork-url $(MAINNET_RPC) \
		--fork-block-number 19621640 \
		-vvv

testV2:
	forge clean
	forge test \
		--match-contract V2 \
		--fork-url $(MAINNET_RPC) \
		--fork-block-number 19621640 \
		-vv

deployV2:
	forge clean
	forge script script/deploy/Deploy.V2.s.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0xEEB785F7700ab3EBbD084CE22f274b4961950d9A \
		--broadcast \
		--verify \
		-i 1 \
		-vvvv \
		--legacy \
		--via-ir \
		--optimize

deployKeroseneVaultV2:
	forge clean
	forge script script/deploy/Deploy.KeroseneVaultV2.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0xe1d3244073f45a8f1Ed28b31975755c85181161C \
		--broadcast \
		--verify \
		-i 1 \
		-vvvv \
		--via-ir \
		--optimize

anvilFork:
	anvil --chain-id 31337 --fork-url $(MAINNET_RPC) --auto-impersonate --gas-price 0

deployV3:
	forge clean
	forge script script/deploy/DeployVaultManagerV3.s.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0x3a37e58345Eb6c67503766d60a33d7EAFBFfA4af \
		--broadcast \
		-i 1 \
		-vvvv \
		--via-ir \
		--optimize
		# --verify \

testV3:
	forge clean
	forge test \
		--match-test test_Deployment \
		--fork-url $(MAINNET_RPC) \
		--fork-block-number 20182948 \
		-vv
		# --match-contract V3 \
			
verify:
	forge verify-contract 0x5c1a3f77EE504bd802bd72dA68Fa7B4Bafe0Fd79 --etherscan-api-key $(ETHERSCAN_API_KEY) src/core/VaultManagerV3.sol:VaultManagerV3 --compiler-version 0.8.20

deployV4:
	forge clean
	forge script script/deploy/Deploy.DyadXP.s.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0x4F8c7f56815D5D6101565B281525bAC9b468346B \
		--broadcast \
		-i 1 \
		-vvvv \
		--via-ir \
		--verify \
		--optimize

deployWeETH:
	forge clean
	forge script script/deploy/Deploy.weETH.Vault.s.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0xaf17f6E53f6CC15AD685cF548A0d48d38462B23e \
		--broadcast \
		--via-ir \
		--verify \
		--optimize \
		-i 1 \
		-vvvv

deployApxETH:
	forge clean
	forge script script/deploy/Deploy.apxETH.Vault.s.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0xaf17f6E53f6CC15AD685cF548A0d48d38462B23e \
		--broadcast \
		--via-ir \
		--verify \
		--optimize \
		-i 1 \
		-vvvv

deployUSDe:
	forge clean
	forge script script/deploy/Deploy.sUSDeVault.Mainnet.s.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0xaf17f6E53f6CC15AD685cF548A0d48d38462B23e \
		--broadcast \
		-i 1 \
		-vvvv \
		--via-ir \
		--verify \
		--optimize

deployV5:
	forge clean
	forge script script/deploy/Deploy.VaultManagerV5.s.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0x9180397941B0d63C3B7CdEE9Dd904D4E4c1DE117 \
		--broadcast \
		-i 1 \
		-vvvv \
		--via-ir \
		--verify \
		--optimize

deployStaking:
	forge clean
	forge script script/deploy/Deploy.Staking.s.sol \
		--rpc-url $(MAINNET_RPC) \
		--sender 0x43f95890eB5ABE84E5C6d28d84cFcA4c87C486a0 \
		--broadcast \
		-i 1 \
		-vvvv \
		--via-ir \
		--verify \
		--optimize