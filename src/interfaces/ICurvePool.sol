// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICurvePool {
    function N_COINS() external view returns (uint256);
    function add_liquidity(uint256[] calldata amounts, uint256 minMintAmount, address receiver)
        external
        returns (uint256);
    function remove_liquidity_one_coin(uint256 burnAmount, int128 i, uint256 minReceived, address receiver)
        external
        returns (uint256);
}
