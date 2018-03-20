pragma solidity ^0.4.18;

import {SafeMath} from "./SafeMath.sol";

contract Random {
    function random(uint256 _num) public returns (uint256 randomNumber);
}

contract ERC721 {
    
    uint256[] public tokens;
    mapping (address => uint256) ownerTokenCount;
    
    // methods
    function totalSupply() public view returns (uint256 total);
    function balanceOf(address _owner) public view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) external view returns (address owner);
    function transfer(address _to, uint256 _tokenId) external;
    function tokenMetadata(uint256 _tokenId) public constant returns (string infoUrl);

    // Events
    event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);
}

contract QunQunCommunity is ERC721 {
    
    using SafeMath for uint256;

    struct Community {
        uint256 id; //auto increment number
        string name;
        address owner;
        uint8 status; //0: shut, 1: running, 2: for_sale
        uint256 timestamp;
        string infoUrl; //may be a ipfs link
    }
    
    struct Lottery {
        uint256 totalNum;
        uint256 luckyNumber;
        uint8 status; //0: not init, 1: has set up
    }
    
    uint256 public lastBlockNumber = 0;
    uint256 public lastLotteryRound = 0;
    uint256 public lastCommunityNumber = 10000; //community or token id
    uint256 public blockInterval = 24; // 24 blocks is about 6 minutes
    uint256 public setUpFee = 49.99 ether; //init price 49.99QUN
    uint256 public exchangeFeePercent = 5; //sale Community fee
    address public lotteryContractAddress;
    address public contractOwner;

    mapping (bytes32 => Community) public communities; //community list, site name as key
    mapping (uint256 => bytes32) public idNameMap;
    mapping (uint256 => Lottery) public lotteryInfo; //round => luckyNumber
    
    event Create(uint256 indexed  _id, string _name, address indexed _owner);
    
    function QunQunCommunity() public{
        contractOwner = msg.sender;
        lastBlockNumber = block.number;
    }
    
    modifier onlyContractOwner(){
        require(contractOwner == msg.sender);
        _;
    }
    
    /**
     * because the high cost of miner fee
     * change the qualification of create site to a lottery game
    */
    function lottery(uint256 _round, uint256 _num) onlyContractOwner public returns(uint256 luckyNumber){
        require(block.number - lastBlockNumber >= blockInterval);
        require(_round > lastLotteryRound); //require _round not replicate
        Random random = Random(lotteryContractAddress);
        luckyNumber = random.random(_num);
        // save lucky number
        lotteryInfo[_round] = Lottery({
            totalNum: _num,
            luckyNumber: luckyNumber,
            status: 0
        });
        lastLotteryRound = _round;
        lastBlockNumber = block.number;
        return luckyNumber;
    }

    /**
    * set community info
    */
    function setUp(uint256 _round, string _name, address _owner) onlyContractOwner public returns (bool success) {
        // judge qualification
        require(lotteryInfo[_round].luckyNumber > 0 && lotteryInfo[_round].status == 0);
        require(bytes(_name).length <= 64);
        require(_owner != address(0));
        bytes32 nameHash = keccak256(_name);
        //check the name is exist
        require(communities[nameHash].id == 0);
        //set community info
        uint256 community_id = lastCommunityNumber + 1;
        communities[nameHash] = Community({
            id: community_id,
            name: _name,
            owner: _owner,
            status: 1,
            timestamp: block.timestamp,
            infoUrl: ""
        });
        lastCommunityNumber = community_id;
        lastBlockNumber = block.number;
        lotteryInfo[_round].status = 1;
        tokens.push(community_id);
        ownerTokenCount[_owner]++;
        idNameMap[community_id] = nameHash;
        //event
        emit Create(community_id, _name, _owner);
        return true;
    }
    
    function setExtendInfo(string _name, string _info) onlyContractOwner public returns (bool){
        communities[keccak256(_name)].infoUrl = _info;
        return true;
    }
    
    /*** ERC721 IMPLEMENTATION ***/
    
    // Required methods
    
    function totalSupply() public view returns (uint256 total){
        return tokens.length;
    }
    
    function balanceOf(address _owner) public view returns (uint256 balance){
        return ownerTokenCount[_owner];
    }
    
    modifier whenTokenExist(uint256 _tokenId){
        bytes32 nameHash = idNameMap[_tokenId];
        require(nameHash != bytes32(0));
        _;
    }

    modifier isTokenOwner(uint256 _tokenId){
        bytes32 nameHash = idNameMap[_tokenId];
        require(nameHash != bytes32(0));
        require(msg.sender == communities[nameHash].owner);
        _;
    }
    
    function ownerOf(uint256 _tokenId) whenTokenExist(_tokenId) external view returns (address owner){
        return communities[idNameMap[_tokenId]].owner;
    }
    
    function transfer(address _to, uint256 _tokenId) onlyContractOwner external{
        require(_to != address(0));
        bytes32 nameHash = idNameMap[_tokenId];
        require(nameHash != bytes32(0));
        address _owner =  communities[nameHash].owner;
        communities[nameHash].owner = _to;
        ownerTokenCount[_owner]--;
        ownerTokenCount[_to]++;
        emit Transfer(_owner, _to, _tokenId);
    }
    
    
    //optional
    function tokenMetadata(uint256 _tokenId) whenTokenExist(_tokenId) public constant returns (string infoUrl){
        return communities[idNameMap[_tokenId]].infoUrl;   
    }
    

    /*** SYSTEM FUNCTIONS ***/
    
    function changeContractOwner(address newOwner) onlyContractOwner public returns (bool){
        contractOwner = newOwner;
        return true;
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
    
    function changeLotteryContractAddress(address newContractAddress) onlyContractOwner public returns (bool){
        lotteryContractAddress = newContractAddress;
        return true;
    }

}