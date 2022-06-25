/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";

contract C250GoldPresale2 is ERC20, Ownable {
    using SafeMath for uint256;

    address payable sales;

    constructor(address payable _sales) ERC20("C250GoldTicket2", "C250GTICKET2") {
      _mint(_sales, 10043*1e18);
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

    uint256 rate;
    uint256 divisor;
    function setRate(uint256 _rate, uint256 _divisor) external onlyOwner {
      rate = _rate;
      divisor = _divisor;
    }

    uint256 constant MINIMUM_BUY = 10 * 1e18;
    
    function buy() payable external {
      require(rate > 0, "Not started");
      require(totalSupply() < 100000*1e18, "Sales limit reached");
      require(msg.value >= MINIMUM_BUY, "Please send 10 MATIC and above");
      require(!completed, "Presale is over");

      sales.transfer(msg.value);
      uint256 tickets = (msg.value.mul(rate).div(divisor));
      _mint(msg.sender, tickets);
    }

    function claim() external {
      require(balanceOf(msg.sender) > 0, "Nothing to claim");
      require(completed, "Presale is still running");

      uint256 amount = balanceOf(msg.sender);
      _burn(msg.sender, amount);
      ERC20(token).transfer(msg.sender, amount.mul(2));
    }
}
