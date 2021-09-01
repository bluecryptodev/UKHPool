// Govance token
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    uint256 public INITIAL_SUPPLY = 100000;

    constructor() ERC20("Test Token", "MYT") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
