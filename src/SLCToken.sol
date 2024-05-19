// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SLCToken is ERC20, Ownable {
    uint256 private constant PRECISION = 1e18;
    uint256 public initialSupply = 1000000 * PRECISION;

    constructor() ERC20("SLC Token", "SLC") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
