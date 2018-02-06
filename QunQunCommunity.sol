pragma solidity ^0.4.18;


contract ERC20 {
    address public owner;
    function allowance(address _owner, address _spender) public view returns (uint256);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);
}

contract QunQunCommunity {

    //community struct
    struct Community {
        bool is_exist;
        bytes32 key;  //community key, may be used as subdomain
        uint8 status; //0: shut, 1: running, 2: for_sale
        address owner;
        address manager; //manager has the same privilege as owner
        uint256 price; // sales price
        uint256 timestamp;
        uint256 number; //auto increment number
    }
    
    uint256 public lastBlockNumber = 0;
    uint256 public lastCommunityNumber = 10000;
    uint256 public blockInterval = 24; // 24 blocks is about 6 minutes
    uint256 public setUpPrice = 4999 * 10 ** 16; //init price 49.99QUN
    address public qunTokenContractAddress;
    address public owner;

    mapping (bytes32 => Community) public communities; //community list, site name as key
    //for save site keys, site_key and site_name both need be unique
    mapping (bytes32 => bytes32) public communityKeys;
    
    
    function QunQunCommunity(address _tokenContractAddress) public{
        owner = msg.sender;
        lastBlockNumber = block.number;
        qunTokenContractAddress = _tokenContractAddress;
    }

    /**
    * try create new community
    */
    function createSite(bytes32 siteName, address siteOwner, address siteManager) public returns (bool success) {
        require(block.number - lastBlockNumber > blockInterval);
        //check the key is exist
        require(communities[siteName].is_exist == false);
        ERC20 qunTokenContract = ERC20(qunTokenContractAddress);
        //check balances
        require(qunTokenContract.allowance(msg.sender, address(this)) >= setUpPrice);
        if(siteOwner == 0x0){
            siteOwner = msg.sender;
        }
        //set community info
        Community memory newSite =  Community({
            is_exist: true,
            key: '',
            status: 1,
            owner: siteOwner,
            manager: siteManager,
            price: 0,
            timestamp: block.timestamp,
            number: lastCommunityNumber + 1
        });
        communities[siteName] = newSite;
        lastCommunityNumber += 1;
        //transfer QUN
        qunTokenContract.transferFrom(msg.sender, qunTokenContract.owner(), setUpPrice);
        lastBlockNumber = block.number;
        return true;
    }
    
    
    modifier checkAuth(bytes32 siteName){
        //is owner or manager
        require(communities[siteName].owner == msg.sender || communities[siteName].manager == msg.sender);
        _;
    }

    /**
    * sale community
    */
    function setForSale(bytes32 siteName, uint256 price) checkAuth(siteName) public returns (bool success) {
        //set status to sale
        communities[siteName].status = 2;
        communities[siteName].price = price;
        return true;
    }

    /**
    * cancel sale
    */
    function cancelSale(bytes32 siteName) checkAuth(siteName) public returns (bool success) {
        //set status to running
        communities[siteName].status = 1;
        communities[siteName].price = 0;
        return true;
    }
    
    /**
    * shut down site
    */
    function shutDown(bytes32 siteName) checkAuth(siteName) public returns (bool) {
        //set status to shut down
        communities[siteName].status = 0;
        return true;
    }
    
    /**
    * open site
    */
    function openAgain(bytes32 siteName) checkAuth(siteName) public returns (bool) {
        //set status to running
        communities[siteName].status = 1;
        return true;
    }

    /**
    * change sales price
    */
    function changePrice(bytes32 siteName, uint256 newPrice) checkAuth(siteName) public returns (bool) {
        //check the community is on offer
        require(communities[siteName].status == 2);
        //set new price
        communities[siteName].price = newPrice;
        return true;
    }

    /**
    * buy community
    */
    function buy(bytes32 siteName, address siteOwner) public returns (bool) {
        //check the community is on offer
        require(communities[siteName].status == 2);
        if(siteOwner == 0x0){
            siteOwner = msg.sender;
        }
        ERC20 qunTokenContract = ERC20(qunTokenContractAddress);
        //check buyer balances
        require(qunTokenContract.allowance(msg.sender, address(this)) >= communities[siteName].price);
        //transfer money
        qunTokenContract.transferFrom(msg.sender, communities[siteName].owner, communities[siteName].price);
        //change owner
        communities[siteName].owner = siteOwner;
        //reset sale info
        communities[siteName].status = 1;
        communities[siteName].price = 0;
        return true;
    }
    
    /**
    * set community key, it can not change
    */
    function setCommunityKey(bytes32 siteName, bytes32 siteKey) checkAuth(siteName) public returns (bool){
        //can only once
        require(communityKeys[siteKey] == "");
        communityKeys[siteKey] = siteName;
        communities[siteName].key = siteKey;
        return true;
    }
    
    /**
    * set manager
    */
    function setManager(bytes32 siteName, address newManager) checkAuth(siteName) public returns (bool){
        communities[siteName].manager = newManager;
        return true;
    }
    
    /**
    * direct transfer community owner
    */
    function transferOwner(bytes32 siteName, address newOwner) public returns (bool){
        require(communities[siteName].owner == msg.sender);
        communities[siteName].owner = newOwner;
        return true;
    }
    
    
    function changeSetUpPrice(uint256 newPrice) public returns (bool){
        require(owner == msg.sender);
        setUpPrice = newPrice;
        return true;
    }
    
    function changeBlockInterval(uint256 newInterval) public returns (bool){
        require(owner == msg.sender);
        blockInterval = newInterval;
        return true;
    }

}