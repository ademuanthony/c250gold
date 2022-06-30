/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";

import './C250GoldPresale2.sol';

contract C250GoldPresaleCoordinator is Ownable {
    using SafeMath for uint256;

    address token;
    address payable sales;
    mapping(address => address) buyers;

    uint256 public amountOut;

    constructor(address payable _sales, address _token) {
      sales = _sales;
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
    
    function buy(address referrer) payable external {
      require(rate > 0, "Not started");
      require(msg.value >= MINIMUM_BUY, "Amount too low");
      require(!completed, "Presale is over");

      sales.transfer(msg.value);
      uint256 tickets = (msg.value.mul(rate).div(divisor));
      ERC20(token).transfer(msg.sender, tickets);
      ERC20(token).transfer(referrer, tickets.div(20));
      if(buyers[referrer] != address(0)) {
        ERC20(token).transfer(buyers[referrer], tickets.div(20));
      }

      amountOut = amountOut.add(tickets);
      buyers[msg.sender] = referrer;
    }
}
