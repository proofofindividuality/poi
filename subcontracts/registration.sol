contract registration {

    address scheduler;
    address poiContract;
    
    uint randomHour; // alternate the hour of the day that the global event occurs on
    uint public deadLine;
    uint hangoutCountdown;
    uint issuePOIsCountdown;
    
    uint groupSize;
   
    /* these are used for the registration, randomization process and to assing users into groups */
    address[] registeredUsers;
    uint256[] randomizedTemplate;
    mapping(address => bool) public registered;

    mapping(address => uint) public userGroup;
    uint groupCount;
    
    /* these are used for booting up the hangout sessions */
    address[][] hangoutGroups;
    mapping(uint => bytes32) public hangoutAddressRegistry;
    mapping (address => bool) hangoutInSession;

    /* when you issue POIs, you pass along a list of verified users */
    address[] verifiedUsers;
    
    uint depositSize;
    address depositContract;


    function registration(uint roundLength, uint groupSize, uint depositSize){
        groupSize = groupSize;
        depositSize = depositSize;
        randomHour = uint8(sha3(this))%24 + 1; // generate random number between 1 and 24
        deadLine = block.number + roundLength - randomHour - 1 hours; // leave enough time for the randomization algorithm to add users to groups
        hangoutCountdown = block.number + roundLength - randomHour; // allow hangouts to begin at the randomHour clock stroke
        issuePOIsCountdown = block.number + roundLength - randomHour + 45 minutes; // leave 30 minutes for all verified users to be submitted
        poiContract = msg.sender;
	scheduler = 0x26416b12610d26fd31d227456e9009270574038f; // alarm service on morden testnet
        scheduleShuffling();
        scheduleHangouts();
        scheduleIssuePOIs();
    }
    
    
    function register() returns (bool success) {
        if(block.number > deadLine) throw;
        if(msg.value < depositSize) throw;
        if(registered[msg.sender] == true) throw;
        registered[msg.sender] = true;
        registeredUsers.push(msg.sender);
	depositGovernance(depositContract).registrationDeposit.value(msg.value)(msg.sender);
	return true;
    }

    function scheduleShuffling() internal {
	bytes4 sig = bytes4(sha3("generateGroups()"));
	bytes4 scheduleCallSig = bytes4(sha3("scheduleCall(bytes4,uint256)"));
	scheduler.call.value(50000000000000000)(scheduleCallSig, sig, deadLine);
    }
    
    function scheduleHangouts() internal {
	bytes4 sig = bytes4(sha3("bootUpHangouts()"));
	bytes4 scheduleCallSig = bytes4(sha3("scheduleCall(bytes4,uint256)"));
	scheduler.call.value(50000000000000000)(scheduleCallSig, sig, hangoutCountdown);
    }
    
    function scheduleIssuePOIs() internal {
	bytes4 sig = bytes4(sha3("issuePOIs()"));
	bytes4 scheduleCallSig = bytes4(sha3("scheduleCall(bytes4,uint256)"));
	scheduler.call.value(50000000000000000)(scheduleCallSig, sig, issuePOIsCountdown);
    }


    function getRandomNumber(uint seed) internal returns (uint) {
    	return (uint(sha3(block.blockhash(block.number-1), seed))%100);
    }

    function generateGroups() {
        if(block.number < deadLine) throw;

/* ether-poker's algorithm for shuffling a deck of cards is used to shuffle the list of registered users */

	  uint8[2*20] memory unshuffled;

	  for (uint8 i=0; i < registeredUsers.length; i++) {
		  unshuffled[i] = i;
	  }

	  uint listIndex;

	  for (i=0; i < registeredUsers.length; i++) {
		  listIndex = getRandomNumber(i) % (registeredUsers.length - i);
		  randomizedTemplate.push(unshuffled[listIndex]);
		  unshuffled[listIndex] = unshuffled[registeredUsers.length - i - 1];
	  }
   
/* the randomized list is then used to assign users into groups */

	uint groupCount;
	uint counter;

	for(i = 0; i < randomizedTemplate.length; i++){
	    if(counter == groupSize){ groupCount++; counter = 0;}
	    userGroup[registeredUsers[randomizedTemplate[i]]] = groupCount;
            hangoutGroups[groupCount].push(registeredUsers[randomizedTemplate[i]]);
	    counter++;
	}
	
/* hangout addresses are generated and mapped to hangout groups */

	for(i = 0; i < groupCount; i++){
    	    hangoutAddressRegistry[i]= sha3(hangoutGroups[i]);
        }
    }

    function getHangoutAddress() returns(bytes32){
        if(hangoutAddressRegistry[userGroup[msg.sender]] == 0) throw;
        // maybe use http://appear.in for first version
        // hangoutURL = "http://appear.in" + hangoutAddressRegistry[userGroup[msg.sender]]
        bytes32 hangoutURL = hangoutAddressRegistry[userGroup[msg.sender]];
        return hangoutURL;
    }


    function bootUpHangouts() {
    	if(block.number < hangoutCountdown) throw;
        for (uint i = 0; i < groupCount; i++)
            address b = new hangout(hangoutGroups[groupCount]);
            hangoutInSession[b] = true;
    }
    

    function submitVerifiedUsers(address[] verified) {
        if(hangoutInSession[msg.sender] != true) throw; // can only be invoked by hangout contract
        if(block.number > issuePOIsCountdown) throw; // deadLine has passed and POIs have already started being issued
        
        for (uint i = 0; i < verified.length; i++)
            verifiedUsers.push(verified[i]);
        
        hangoutInSession[msg.sender] == false;
    }
    
    function issuePOIs(){
        if(block.number < issuePOIsCountdown) throw; // hangouts are still in session
            poi(poiContract).issuePOIs(verifiedUsers);
            
    }
    
    function killContract(){
        if(msg.sender != poiContract) throw;
        suicide(poiContract);
    }
}
