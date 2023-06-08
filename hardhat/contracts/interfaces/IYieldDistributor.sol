// SPDX-License-Identifier: GNU-GPL v3.0 or later

pragma solidity >=0.8.0;


interface IYieldDistributor {

    function earned(address account) external view returns (uint256);

    function getYield() external returns (uint256 yield0);

    function yields(address) external view returns (uint256 yield0);

    function checkpoint() external;

    function checkpointOtherUser(address user_addr) external;

}
