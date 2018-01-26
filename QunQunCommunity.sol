pragma solidity ^0.4.18;


import {QunQunToken} from "./QunQunToken.sol";


contract QunQunCommunity {

    //community struct
    struct siteInfo {
        string name;
        bytes32 status;
        bool is_exist;
        address owner;
        uint256 price;
        uint256 timestamp;
    }
    
    uint256 public lastBlockNumber = 0;
    uint16  public siteCreateBlockInterval = 24; // 24 blocks is about 6 minutes
    uint256 public siteCreatePrice = 4999 * 10 ** 16; //init price 49.99QUN
    address public tokenContractAddress;
    address public owner;

    mapping (bytes32 => siteInfo) public site_info; //community list
    
    
    function QunQunCommunity(address _tokenContractAddress) public{
        owner = msg.sender;
        lastBlockNumber = block.number;
        tokenContractAddress = _tokenContractAddress;
    }

    /**
    * try create new community
    */
    function createSite(address site_owner, bytes32 site_key, string site_name) public returns (bool success) {
        require(block.number - lastBlockNumber > siteCreateBlockInterval);
        //check the key is exist
        require(site_info[site_key].is_exist == false);
        QunQunToken tokenContract = QunQunToken(tokenContractAddress);
        //check balances
        require(tokenContract.allowance(msg.sender, address(this)) >= siteCreatePrice);
        //set community info
        site_info[site_key].is_exist = true;
        site_info[site_key].owner = site_owner;
        site_info[site_key].status = "running";
        site_info[site_key].name = site_name;
        site_info[site_key].timestamp = block.timestamp;
        //transfer QUN
        tokenContract.transferFrom(msg.sender, tokenContract.owner(), siteCreatePrice);
        lastBlockNumber = block.number;
        return true;
    }

    /**
    * sale community
    */
    function setForSale(bytes32 site_key, uint256 price) public returns (bool success) {
        //check owner
        require(site_info[site_key].owner == msg.sender);
        //set status to sale
        site_info[site_key].status = "for_sale";
        site_info[site_key].price = price;
        return true;
    }

    /**
    * cancel sale
    */
    function cancelSale(bytes32 site_key) public returns (bool success) {
        //check owner
        require(site_info[site_key].owner == msg.sender);
        //set status to running
        site_info[site_key].status = "running";
        return true;
    }

    /**
    * change sales price
    */
    function changePrice(bytes32 site_key, uint256 price) public returns (bool success) {
        //check the community is on offer
        require(site_info[site_key].status == "for_sale");
        //check owner
        require(site_info[site_key].owner == msg.sender);
        //set status to running
        site_info[site_key].price = price;
        return true;
    }

    /**
    * buy community
    */
    function buySite(bytes32 site_key) public returns (bool success) {
        //check the community is on offer
        require(site_info[site_key].status == "for_sale");
        QunQunToken tokenContract = QunQunToken(tokenContractAddress);
        //check buyer balances
        require(tokenContract.allowance(msg.sender, address(this)) >= site_info[site_key].price);
        //transfer money
        tokenContract.transferFrom(msg.sender, site_info[site_key].owner, site_info[site_key].price);
        //change owner
        site_info[site_key].owner = msg.sender;
        //reset sale info
        site_info[site_key].status = "running";
        site_info[site_key].price = 0;
        return true;
    }

}