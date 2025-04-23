# Deployents

## Via Scripting

### Deploy locally

```
forge script scripts/Deploy.s.sol:MyScript --fork-url http://localhost:8545 --broadcast

```

### Deploy to Sepolia

```
# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script --chain sepolia script/NFT.s.sol:MyScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv


```

## Via Command Line

```
forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/MyContract.sol:MyContract
```
