// pragma solidity ^0.8.0;

// import "../interfaces/IERC20.sol";
// import "../libraries/StakeAppStorage.sol";

// contract Staking {
//     function stake(uint _amount, uint8 _poolId) external {
//         require(_poolId <= 2, "invalid pool");
//         IERC20 naira = IERC20(stakingStorage().token);
//         require(naira.balanceOf(msg.sender) > _amount, "insufficient tokens");

//         naira.transferFrom(msg.sender, address(this), _amount);

//         uint8[3] memory nftForPool = [1, 2, 3];
//         uint256[3] memory duration;
//         duration[0] = block.timestamp + (7 * 24 * 60 * 60); // 1 week
//         duration[1] = block.timestamp + (14 * 24 * 60 * 60); // 2 weeks
//         duration[2] = block.timestamp + (21 * 24 * 60 * 60); // 3 weeks

//         uint8 numberOfNft = nftForPool[_poolId];
//         uint256 _finishesAt = duration[_poolId];
//         StakeAppStorage.Pools _poolType = StakeAppStorage.Pools(_poolId);

//         stakingStorage().stakes[msg.sender] = StakeAppStorage.Stake({
//             amountStaked: _amount,
//             stakedAt: block.timestamp,
//             finishesAt: _finishesAt,
//             nftReward: numberOfNft,
//             claimed: false,
//             poolType: _poolType
//         });

//         emit StakeAppStorage.Staked(msg.sender, _amount, _poolId);
//     }

//     function stakingStorage()
//         internal
//         pure
//         returns (StakeAppStorage.Layout storage s)
//     {
//         s = StakeAppStorage.storaged();
//     }
// }

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8;

contract E {}
