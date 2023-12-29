// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts@v4.9.0/access/Ownable.sol";
import "@openzeppelin/contracts@v4.9.0/token/ERC20/IERC20.sol";

interface IMasterPool {
    function transferCommission(address _to, uint256 amount) external returns(bool);
}

contract MasterPool is Ownable  {
    
    address public usdt;
    address public refContract;

    constructor(address _usdt) payable {
        usdt = _usdt;
    }

    function setController(address _address) external onlyOwner {
        refContract = _address;
    }

    function SetUsdt(address _usdt) external onlyOwner {
        usdt = _usdt;
    }

    modifier onlyController {
        require(msg.sender == refContract, "Only Controller");
        _;
    }

    function widthdraw(uint256 amount) external onlyOwner {
        require(usdt != address(0), "Invalid usdt");
        IERC20(usdt).transfer(msg.sender, amount);
    }   

    // Only Controller
    function transferCommission(address _to, uint256 amount) external onlyController returns(bool) {
        return IERC20(usdt).transfer(_to, amount);
    }
}