// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardsERC20Mock is ERC20 {
    uint8 dec;

    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance,
        uint8 _decimals
    )
        payable
        ERC20(name, symbol)
    {
        _mint(initialAccount, initialBalance);
        dec = _decimals;
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function decimals() public view override returns (uint8) {
        return dec;
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }
}
