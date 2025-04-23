// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8;

library SubscriptionStorage {
    uint8 constant NUMBER_OF_TOKENS_PER_REWARD = 25;

    enum Pools {
        oneWeekPool,
        twoWeeksPool,
        threeWeeksPool
    }

    error TimeHasNotFinished();

    // Events to track staking actions
    event Staked(address indexed user, uint256 amount, uint8 poolId);
    event RewardClaimed(
        address indexed user,
        uint8 nft,
        bool convertTokenToNft
    );

    struct Stake {
        uint256 amountStaked;
        uint256 stakedAt;
        uint256 finishesAt;
        uint8 nftReward;
        Pools poolType;
        bool claimed;
    }

    struct Layout {
        mapping(address => uint) users;
        mapping(address => Stake) stakes;
        address owner;
        address token;
        Pools pools;
    }

    function storage_() external pure returns (Layout storage l) {
        assembly {
            l.slot := 1
        }
    }
}
