/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract C250GoldPresale is ERC20, Ownable {

    address payable sales;

    constructor(address payable _sales) ERC20("C360GoldTicket", "C250GTICKET") {
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
      if(totalSupply() <= 2000*1e8) return 50;
      if(totalSupply() <= 5000*1e8) return 75;
      return 85;
    }

    uint256 constant MINIMUM_BUY = 10*1e18;

    function buy() payable external {
      require(msg.value == MINIMUM_BUY, "Please send 10 MATIC and above");

      sales.transfer(msg.value);
      _mint(msg.sender, msg.value.mul(currentRate()));
    }

    function claim() external {
      require(totalSupply() < 100000*1e18, "Sales limit reached");
      require(balanceOf(msg.sender) > 0, "Nothing to claim");
      require(completed, "Presale is still running");

      uint256 amount = balanceOf(msg.sender);
      _burn(msg.sender, amount);
      ERC20(token).transfer(msg.sender, amount);
    }
}
