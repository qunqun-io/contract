pragma solidity ^0.4.18;

import {SafeMath} from "./SafeMath.sol";

contract ERC20 {
    address public owner;
    function allowance(address _owner, address _spender) public view returns (uint256);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);
}

contract QunQunCommunity {
    
    using SafeMath for uint256;

    struct Community {
        string name;
        bool isExist;
        uint8 status; //0: shut, 1: running, 2: for_sale
        address owner;
        address manager; //manager has the same privilege as owner
        uint256 salePrice; // sales price
        uint256 timestamp;
        uint256 number; //auto increment number
        string extendInfo; //may be a ipfs link
    }
    
    uint256 public lastBlockNumber = 0;
    uint256 public lastCommunityNumber = 10000;
    uint256 public blockInterval = 24; // 24 blocks is about 6 minutes
    uint256 public setUpFee = 49.99 ether; //init price 49.99QUN
    uint256 public exchangeFeePercent = 5; //sale Community fee
    address public qunTokenContractAddress;
    address public contractOwner;

    mapping (bytes32 => Community) public communities; //community list, site name as key
    
    event Create(address indexed _from, address indexed _owner, string _name);
    event Transfer(address indexed _from, address indexed _to, bytes32 _name);
    
    function QunQunCommunity(address _tokenContractAddress) public{
        contractOwner = msg.sender;
        lastBlockNumber = block.number;
        qunTokenContractAddress = _tokenContractAddress;
    }

    /**
    * try create new community
    */
    function createSite(string _name, address _owner, address _manager) public returns (bool success) {
        require(block.number - lastBlockNumber >= blockInterval);
        require(bytes(_name).length <= 64);
        bytes32 nameHash = keccak256(_name);
        //check the key is exist
        require(communities[nameHash].isExist == false);
        ERC20 qunTokenContract = ERC20(qunTokenContractAddress);
        //check balances
        require(qunTokenContract.allowance(msg.sender, address(this)) >= setUpFee);
        if(_owner == 0x0){
            _owner = msg.sender;
        }
        //set community info
        communities[nameHash] = Community({
            name: _name,
            isExist: true,
            status: 1,
            owner: _owner,
            manager: _manager,
            salePrice: 0,
            timestamp: block.timestamp,
            number: lastCommunityNumber + 1,
            extendInfo: ""
        });
        lastCommunityNumber += 1;
        //transfer set up fee
        qunTokenContract.transferFrom(msg.sender, contractOwner, setUpFee);
        lastBlockNumber = block.number;
        Create(msg.sender, _owner, _name);
        return true;
    }
    
    
    modifier checkAuth(bytes32 _name){
        //is owner or manager
        require(communities[_name].owner == msg.sender || communities[_name].manager == msg.sender);
        _;
    }
    

    /**
    * sale community
    */
    function setForSale(bytes32 _name, uint256 _price) checkAuth(_name) public returns (bool success) {
        require(_price >= setUpFee);
        //set status to sale
        communities[_name].status = 2;
        communities[_name].salePrice = _price;
        return true;
    }

    /**
    * cancel sale
    */
    function cancelSale(bytes32 _name) checkAuth(_name) public returns (bool success) {
        //set status to running
        communities[_name].status = 1;
        communities[_name].salePrice = 0;
        return true;
    }
    
    /**
    * shut down site
    */
    function shutDown(bytes32 _name) checkAuth(_name) public returns (bool) {
        //set status to shut down
        communities[_name].status = 0;
        return true;
    }
    
    /**
    * open site
    */
    function openAgain(bytes32 _name) checkAuth(_name) public returns (bool) {
        //set status to running
        communities[_name].status = 1;
        return true;
    }

    /**
    * change sales price
    */
    function changeSalePrice(bytes32 _name, uint256 _price) checkAuth(_name) public returns (bool) {
        //set new price
        communities[_name].salePrice = _price;
        return true;
    }
    

    /**
    * buy community
    */
    function buy(bytes32 _name, address _owner, address _manager) public returns (bool) {
        //check the community is on offer
        require(communities[_name].status == 2);
        if(_owner == 0x0){
            _owner = msg.sender;
        }
        ERC20 qunTokenContract = ERC20(qunTokenContractAddress);
        //check buyer balances
        require(qunTokenContract.allowance(msg.sender, address(this)) >= communities[_name].salePrice);
        //transfer money to owner
        uint256 income = communities[_name].salePrice.mul(100 - exchangeFeePercent).div(100);
        qunTokenContract.transferFrom(msg.sender, communities[_name].owner, income);
        //transfer exchange fee to qun platform
        if(income < communities[_name].salePrice){
            qunTokenContract.transferFrom(msg.sender, contractOwner, communities[_name].salePrice.sub(income));
        }
        Transfer(communities[_name].owner, _owner, _name);
        //change owner
        communities[_name].owner = _owner;
        communities[_name].manager = _manager;
        //reset sale info
        communities[_name].status = 1;
        return true;
    }
    
    function ownerOf(bytes32 _name) public view returns (address) {
        return communities[_name].owner;
    }
    
    function extendInfo(bytes32 _name) public view returns (string){
        return communities[_name].extendInfo;
    }
    
    
    /**
    * set manager
    */
    function approve(address _to, bytes32 _name) checkAuth(_name) public returns (bool){
        communities[_name].manager = _to;
        return true;
    }
    
    
    /**
    * direct transfer community owner
    */
    function transfer(address _to, bytes32 _name) public returns (bool){
        require(communities[_name].owner == msg.sender);
        ERC20 qunTokenContract = ERC20(qunTokenContractAddress);
        uint256 lastPrice = 0;
        if(communities[_name].salePrice > setUpFee){
            lastPrice = communities[_name].salePrice;
        }else{
            lastPrice = setUpFee;
        }
        qunTokenContract.transferFrom(msg.sender, contractOwner, lastPrice.mul(exchangeFeePercent).div(100));
        Transfer(communities[_name].owner, _to, _name);
        communities[_name].owner = _to;
        return true;
    }
    
    modifier onlyContractOwner(){
        require(contractOwner == msg.sender);
        _;
    }
    
    function changeSetUpFee(uint256 newFee) onlyContractOwner public returns (bool){
        setUpFee = newFee;
        return true;
    }
    
    function changeBlockInterval(uint256 newInterval)  onlyContractOwner public returns (bool){
        blockInterval = newInterval;
        return true;
    }
    
    function changeExchangeFeePercent(uint256 newFeePercent) onlyContractOwner public returns (bool){
        exchangeFeePercent = newFeePercent;
        return true;
    }

}