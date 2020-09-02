// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface ITimeAllyManager {
    
    function isStakingContractValid(address _stakingContract) external view returns (bool);

    function getTotalActiveStaking(uint256 _month) external view returns (uint256);
}