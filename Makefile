include .env


deploy:
	forge script --chain base scripts/Deploy.s.sol:Deploy --rpc-url $(SEPOLIA_RPC_URL) --broadcast --verify -vvvv --interactives 1

abigen:
	node scripts/generateDiamondABI.js
