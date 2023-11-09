// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

contract Parameters {

  // ---------------- Goerli ----------------
  address GOERLI_OWNER  = 0xEd6715D2172BFd50C2DBF608615c2AB497904803;
  address GOERLI_ORACLE = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
  uint    GOERLI_MIN_MINT_DYAD_DEPOSIT = 1e18; // $1

  // ---------------- Mainnet ----------------
  address MAINNET_OWNER  = 0xEd6715D2172BFd50C2DBF608615c2AB497904803;
  address MAINNET_ORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  uint    MAINNET_MIN_MINT_DYAD_DEPOSIT = 5000e18; // $5k
}
