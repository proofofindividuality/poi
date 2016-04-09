contract poi {
    
    address currentPOItokens;
    address currentRound;
    address depositGovernanceContract;
    address previousDepositGovernance;	    
    
    
    uint genesisblock;
    uint roundLength;
    uint nextRound;
    
    uint depositSize;
    uint groupSize;
    
    function poi (){
        genesisblock = block.number;
        roundLength = 28 days;
        depositSize = 10;
	groupSize = 5;
	
        nextRound = genesisblock;
        scheduleRound();
    }

    
    
    function scheduleRound() {
        if(block.number < nextRound) throw;
        if(currentRound != 0) registration(currentRound).endRound();
        currentRound = new registration(depositSize, registrationPeriod, hangoutCountdown, groupSize);
        
        nextRound += roundLength;
    }

    function issuePOIs(address[] verifiedUsers) {
        if(msg.sender != currentRound) throw;
        if(currentPOItokens != 0) generatePOIs(currentPOItokens).depricatePOIs;
        currentPOItokens = new generatePOIs(verifiedUsers);
        
        // now that the a new POI round has begun and the deposits have been returned,
        // launch a new depositGovernanceContract
        // if a new depositSize has been agreed on, the old depositGovernanceContract will automatically
        // invoke the newDepositSize() function (see below) 
        
        newDepositGovernanceContract();
    }
    
    function newDepositGovernanceContract() internal{
        if(depositGovernanceContract != 0) {
        	depositGovernance(depositGovernanceContract).processProposals();
        	previousDepositGovernance = depositGovernanceContract; // processProposals() will take a few minutes, so use a temporary address, previousDepositGovernance, for newDepositSize() for now
        }
        depositGovernanceContract = new depositGovernance();
        /* deposits paid into voting for depositSizes should be deducatable from the deposit required to register */
        /* that's not implemented yet. stub on https://gist.github.com/resilience-me/0afcb1d692bb815de9ed */
    }

    function newDepositSize(uint newDepositSize){
    if(msg.sender != previousDepositGovernance) throw;
        depositSize = newDepositSize;
    }
    
    function verifyPOI (address v) returns (string){
	    if (generatePOIs(currentPOItokens).balanceOf(v)==0){
		    return "account does not have a valid POI";
	    }
    	else return "account has a valid POI";
    }      
    
}
