pragma solidity ^0.4.18;

import {SafeMath} from "./SafeMath.sol";
import {QunQunToken} from "./QunQunToken.sol";

contract QunQunTokenIssue {

    address public tokenContractAddress;
    uint16  public lastRate = 950; // the second year inflate rate is 950/10000
    uint256 public lastBlockNumber;
    uint256 public lastYearTotalSupply = 15 * 10 ** 26; //init issue
    uint8   public inflateCount = 0;
    bool    public isFirstYear = true; //not inflate in 2018

    function QunQunTokenIssue (address _tokenContractAddress) public{
        tokenContractAddress = _tokenContractAddress;
        lastBlockNumber = block.number;
    }

    function getRate() internal returns (uint256){
        if(inflateCount == 10){
            // decreasing 0.5% per year until the overall inflation rate reaches 1%.
            if(lastRate > 100){
                lastRate -= 50;
            }
            // reset count
            inflateCount = 0;
        }
        // inflate 1/10 each time
        return SafeMath.div(lastRate, 10);
    }

    // anyone can call this function
    function issue() public  {
        //ensure first year can not inflate
        if(isFirstYear){
            // 2102400 blocks is about one year, suppose it takes 15 seconds to generate a new block
            require(SafeMath.sub(block.number, lastBlockNumber) > 2102400);
            isFirstYear = false;
        }
        // 210240 blocks is about one tenth year, ensure only 10 times inflation per year
        require(SafeMath.sub(block.number, lastBlockNumber) > 210240);
        QunQunToken tokenContract = QunQunToken(tokenContractAddress);
        //adjust total supply every year
        if(inflateCount == 10){
            lastYearTotalSupply = tokenContract.totalSupply();
        }
        uint256 amount = SafeMath.div(SafeMath.mul(lastYearTotalSupply, getRate()), 10000);
        require(amount > 0);
        tokenContract.issue(amount);
        lastBlockNumber = block.number;
        inflateCount += 1;
    }
}