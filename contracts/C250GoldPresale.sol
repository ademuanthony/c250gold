/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";

contract C250GoldPresale is ERC20, Ownable {
    using SafeMath for uint256;

    address payable sales;

    constructor(address payable _sales) ERC20("C250GoldTicket", "C250GTICKET") {
      sales = _sales;
    }

    address token;
    function setTokenAddress(address _token) external onlyOwner {
      token = _token;
    }

    bool completed;
    function complete() external onlyOwner{
      require(token != address(0), "Token address not set");
      completed = true;
    }

    function currentRate() public view returns(uint256) {
      if(totalSupply() <= 20000*1e18) return 50 * 1e16;
      if(totalSupply() <= 50000*1e18) return 75 * 1e16;
      return 85 * 1e16;
    }

    uint256 constant MINIMUM_BUY = 10 * 1e18;
    // 1*1e18x = 50*1e16y
    // (50*1e16 * 2*1e18) / 1e18
    function buy() payable external {
      require(totalSupply() < 100000*1e18, "Sales limit reached");
      require(msg.value >= MINIMUM_BUY, "Please send 10 MATIC and above");

      sales.transfer(msg.value);
      uint256 tickets = (msg.value.mul(currentRate())).div(1e18);
      _mint(msg.sender, tickets);
    }

    function claim() external {
      require(balanceOf(msg.sender) > 0, "Nothing to claim");
      require(completed, "Presale is still running");

      uint256 amount = balanceOf(msg.sender);
      _burn(msg.sender, amount);
      ERC20(token).transfer(msg.sender, amount);
    }
}
