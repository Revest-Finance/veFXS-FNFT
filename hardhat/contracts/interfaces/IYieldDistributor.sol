// SPDX-License-Identifier: GNU-GPL v3.0 or later

pragma solidity >=0.8.0;


interface IYieldDistributor {

    function getYield() external returns (uint256 yield0);

}
