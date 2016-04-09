contract registration {

    address owner;
    
    uint public genesisBlock;
    uint public deadLine;
    uint hangoutCountdown;
    
    uint groupSize;
   
    /* these are used for the registration, randomization process and to assing users into groups */
    mapping(address => bool) public registered;
    address[] registeredUsers;
    uint256[] randomizedTemplate;

    mapping(address => uint) public userGroup;
    uint groupCount;
    
    /* these are used for booting up the hangout sessions */
    address[][] hangoutGroups;
    mapping(uint => bytes32) public hangoutAddressRegistry;
    mapping (address => bool) hangoutInSession;

    /* when you issue POIs, you pass along a list of verified users */
    address[] verifiedUsers;
    uint passVerifiedUsersDeadLine;

    /* the deposits are managed by the depositGovernance contract, so registration contract only 
       stores depositSize and the address for the depositContract */
    
    uint depositSize;
    address depositContract;




    function registration(uint roundLength, uint depositSize, uint groupSize){
        groupSize = groupSize;
        genesisBlock = block.number;
        deadLine = genesisBlock + roundLength - 1 hour; // leave enough time for the randomization algorithm to add users to groups
        hangoutCountdown = genesisBlock + roundLength - 20 minutes; // allow hangouts to begin 20 minutes before the next round
        
        depositSize = depositSize;
        owner = msg.sender;
    }
    
    
    function register() returns (bool){
        if(block.number > deadLine) throw;
        if(msg.value < depositSize * 1 ether) throw;
        if(registered[msg.sender] == true) throw;
        registeredUsers.push(msg.sender);
        registered[msg.sender] = true;
	depositGovernance(depositContract).registrationDeposit(msg.sender).value(msg.value);
        return true;
    }


    function getRandomNumber(uint seed) returns (uint) {
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

	for(i = 0; i < groupCount.length; i++){
    	    hangoutAddressRegistry[i]= sha3(hangoutGroups[i]);
        }
    }

    function getHangoutAddress() returns(bytes32){
        if(hangoutAddressRegistry[userGroup[msg.sender]] == 0) throw;
        // maybe use http://appear.in for first version
        // hangoutURL = "http://appear.in" + hangoutAddressRegistry[userGroup[msg.sender]]
        return hangoutAddressRegistry[userGroup[msg.sender]];
    }


    function bootUpHangouts() {
    	if(block.number < hangoutCountdown) throw;
        for (uint i = 0; i < groupCount; i++)
            address b = new hangout(hangoutGroups[groupCount]);
            hangoutInSession[b] = true;
    }
    

    function passVerifiedUsers(address[] verified) {
        if(hangoutInSession[msg.sender] != true) throw; // can only be invoked by hangout contract
        if(passVerifiedUsersDeadLine == 0) passVerifiedUsersDeadLine = block.number + 100; // give everyone enough time to submit their verified addresses
        if(block.number > passVerifiedUsersDeadLine) throw; // deadLine has passed and POIs have already started being issued
        
        for (uint i = 0; i < verified.length; i++)
            verifiedUsers.push(verified[i]);
        
        hangoutInSession[msg.sender] == false;
    }
    
    function issuePOIs(){
        if(block.number < passVerifiedUsersDeadLine) throw; // hangouts are still in session
            poi(owner).issuePOIs(verifiedUsers);
            
    }
    
    function endRound(){
        if(msg.sender != owner) throw;
        suicide(owner);
    }
}
