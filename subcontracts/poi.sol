ontract poi {
    
    address public POIs;
    address public registrationContract;
    address public depositContract;

    address scheduler; // address to the alarm contract, see http://ethereum-alarm-clock.com

    uint genesisblock;
    uint nextRound;
    uint roundLength;

    uint depositSize;
    uint groupSize;

    function poi (){
        genesisblock = block.number;
        roundLength = 2 days;
        depositSize = 1 ether;
	groupSize = 5;
        nextRound = genesisblock;
	scheduler = 0x26416b12610d26fd31d227456e9009270574038f; // alarm service on morden testnet
	newRound();
    }

    function scheduleCall() internal {
	bytes4 sig = bytes4(sha3("newRound()"));
	bytes4 scheduleCallSig = bytes4(sha3("scheduleCall(bytes4,uint256)"));
	scheduler.call.value(50000000000000000)(scheduleCallSig, sig, nextRound);
    }
    
    function newRound() {
        if(block.number < nextRound) throw;
        registrationContract = new registration(roundLength, groupSize, depositSize);
        registrationContract.send(200000000000000000);
        depositContract = new depositGovernance(depositSize, registrationContract);
        nextRound += roundLength;
	scheduleCall();
    }

    function issuePOIs(address[] verifiedUsers) external {
        if(msg.sender != registrationContract) throw;
        POIs = new generatePOIs(verifiedUsers);
	endRound();
    }
    
    function endRound(){
        registration(registrationContract).killContract();
        depositGovernance(depositContract).processProposals();
    }
   
    function newDepositSize(uint newDepositSize) external {
    if(msg.sender != depositContract) throw;
        depositSize = newDepositSize;
    }
    
    function verifyPOI (address v) public returns (bool success){
	    if (generatePOIs(POIs).POIs(v) == 1) return true;
    }
    
}
