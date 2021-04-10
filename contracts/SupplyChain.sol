pragma solidity ^0.6.0;

import "https://github.com/smartcontractkit/chainlink/blob/develop/evm-contracts/src/v0.6/ChainlinkClient.sol";
import "./Supplier.sol";

struct Item {
    bytes32 uid;
    bool inTransit;
    address currentHolder;
    address[] holderHistory;
    address payable creator; // original account that added the item
    address[] history; // ordered list of addresses that used the item
    string title; // item name
}

contract SupplyChain is ChainlinkClient {
    mapping(bytes32 => Item) public itemCollection;
    bytes32[] public allItems;
    uint256 public numItems;
    
    // vars for coordinating callback function:
    enum CALLBACK_FLAG { TRACK, MOVE, ADD, TRANSFER, NONE }
    CALLBACK_FLAG private callbackFlag;
    address payable private lastCaller; // so we can store who the original caller is

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    uint256 private DEFAULT_PENALTY = 1;
    
    /**
     * Network: Kovan
     * Oracle: Chainlink - 
     * Job ID: Chainlink - 
     * Fee: 0.1 LINK
     */
    constructor() public {
        setPublicChainlinkToken();
        oracle = ;
        jobId = "";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        callbackFlag = CALLBACK_FLAG.NONE;
    }
    

    function moveItem() public {
        callbackFlag = CALLBACK_FLAG.TRANSFER;
        lastCaller = msg.sender;
        requestItemStatus();
    }
    
    function moveItemCB(bytes32 _uid) private {
        callbackFlag = CALLBACK_FLAG.NONE;
        assert(inSupplyChain(_uid));
        assert(!itemCollection[_uid].inTransit);
        itemCollection[_uid].inTransit = true;
        itemCollection[_uid].currentHolder = lastCaller;
        itemCollection[_uid].holderHistory.push(lastCaller);
        itemCollection[_uid].supplierContract = new Supplier(lastCaller);
    }

    function transferItem() public {
        callbackFlag = CALLBACK_FLAG.TRANSFER;
        lastCaller = msg.sender;
        requestItemStatus();
    }
    
    function transferItemCB(bytes32 _uid) private {
        callbackFlag = CALLBACK_FLAG.NONE;
        assert(inSupplyChain(_uid));
        assert(itemCollection[_uid].inTransit);
        assert(itemCollection[_uid].currentHolder == lastCaller);
        itemCollection[_uid].inTransit = false;
        itemCollection[_uid].currentHolder = address(this);
        itemCollection[_uid].feesCollected += itemCollection[_uid].rentalContract.totalChargedFees();
        // close the Rental contract
        itemCollection[_uid].rentalContract.closeRental(itemCollection[_uid].contributor);
    }

    /**
     * Track item
     */
    
    function track() public {
        callbackFlag = CALLBACK_FLAG.TRACK;
        lastCaller = msg.sender;
        requestItemStatus();
    }
    
    function trackCB(bytes32 _uid) private {
        callbackFlag = CALLBACK_FLAG.NONE;
        assert(inSupplyChain(_uid));
        assert(itemCollection[_uid].inTransit);
        assert(itemCollection[_uid].currentHolder == lastCaller);
        itemCollection[_uid].inTransit = false;
        itemCollection[_uid].currentHolder = address(this);
        itemCollection[_uid].rentalContract.closeRental(itemCollection[_uid].contributor);
    }

    /**
     * Contribute new book
     */
    
    function contribute(string memory title) public {
        callbackFlag = CALLBACK_FLAG.CONTRIBUTE;
        lastCaller = msg.sender;
        lastTitle = title;
        requestItemStatus();
    }
    
    function contributeCB(bytes32 _uid) private {
        callbackFlag = CALLBACK_FLAG.NONE;
        // makes sure we have a valid uid
        assert(_uid != 0x0);
        // makes sure that book not already in collction
        assert(!inSuuplyChain(_uid));
        // adds book to collection
        numBooks += 1;
        allItems.push(_uid);
        itemCollection[_uid].uid = _uid;
        itemCollection[_uid].contributor = lastCaller;
        itemCollection[_uid].currentHolder = address(this);
        itemCollection[_uid].rented = false;
        itemCollection[_uid].title = lastTitle;
    }
    
    /**
     * Helper function that returns if _uid is contained in allItems 
     */
    function inSupplyChain(bytes32 _uid) public view returns (bool) {
        for(uint256 i = 0; i< allItems.length; i++) {
            if (allItems[i] == _uid) return true;            
        }
        return false;
    }
}
