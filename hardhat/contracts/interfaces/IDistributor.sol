// SPDX-License-Identifier: GNU-GPL v3.0 or later

pragma solidity >=0.8.0;

import "./IRegistryProvider.sol";
import '@openzeppelin/contracts/utils/introspection/IERC165.sol';

/**
 * @title Provider interface for Revest FNFTs
 */
interface IDistributor {

    function claim() external returns (uint amountTransferred);

    function user_epoch_of(address _addr) external view returns (uint epoch);

    function tokens_per_week(uint index) external view returns (uint tokensPerDay);

    function start_time() external view returns (uint startTime);

    function last_token_time() external view returns (uint lastTime);//Call with index 0

    function time_cursor() external view returns (uint timeCursor);

    function time_cursor_of(address addr) external view returns (uint timeCursor);

    function ve_supply(uint index) external view returns (uint supply);

}
