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


contract hangout {

/* 
   Anti-sybil fuel (ASF) is used to gamify the POI hangouts. Participants can 
   use it to "guide each other's attention", and also to downvote multi-group scammers. 
   Hangout-attendees get to deal out +5000 "anti-sybil fuel" (ASF), and -2000 ASF, 
   and need to receive +4000 to be verified. The ASF points have been balanced so that
   if 2 multi-group scammers are grouped togeher, the 3 other hangout-attendees have
   the power to down-vote those two with 3x-2000 points, preventing them from being verified.
   It has also been balanced so that in a group where only 2 people show up for some reason, 
   those 2 are not penalized and can verify one another.
*/

  address registrationContract;

  uint public genesisblock;
  uint public deadline;
  
  mapping(address => uint256) positiveRewards;    // hangout-attendees get to deal out +5000 anti-sybil fuel (ASF), 
  mapping(address => uint256) negativeRewards;    // and -2000 ASF, 
  mapping(address => uint256) recievedPoints;     // and need to receive +4000 to be verified

  address[] participants;

  address[] verifiedUsers;


    function hangout(address[] hangoutGroup) {
        for (uint i = 0; i < hangoutGroup.length; i++) {
            participants.push(hangoutGroup[i]);
         }
         genesisblock = block.number;
         deadline = genesisblock + 15 minutes; // hangouts are 15 minutes long
         registrationContract = msg.sender;
    }

    function positiveReward(address _to, uint256 _value) {
        uint giveLimit;
        uint recieveLimit;
        if (positiveRewards[msg.sender] + _value > 5000) {       // If the sent amount is bigger than the maximum amount
          giveLimit = 5000 - positiveRewards[msg.sender];        // one can give, send max amount
        }
        if (recievedPoints[_to] + _value > 5000) {               // If the sent amount is bigger than the maximum 
          recieveLimit = 5000 - recievedPoints[_to];             // reward limit, send max amount
        }
        if(giveLimit < recieveLimit) _value = giveLimit;
        else _value = recieveLimit;
        
        /* transfer the anti sybil fuel */
        positiveRewards[msg.sender] +=_value;
        recievedPoints[_to] +=_value;
    }
    
    function negativeReward(address _to, uint256 _value) {
        if (negativeRewards[msg.sender] + _value > 2000) {       // If the sent amount is bigger than the maximum amount
          _value = 2000 - negativeRewards[msg.sender];           // one can give, send max amount
        }
        /* transfer the anti sybil fuel */
        negativeRewards[msg.sender] +=_value;
        recievedPoints[_to] +=_value;
    }


   /* after 15 minutes, each users that has been awarded 4000 ASF or more is seen as verified and given a POI token */

   /* the closeSession function can be called by anyone in the hangut once the deadline has passed */

   function closeSession(){
      if(block.number < deadline) throw;
      
      for(uint i = 0; i < participants.length; i++){
        if(recievedPoints[participants[i]] > 4000)
            verifiedUsers.push(participants[i]);
        }
       /* pass verifiedUsers into a contract that generates POIs, together with verifiedUsers from all other hangouts */
       
        registration(registrationContract).submitVerifiedUsers(verifiedUsers);

       /* the POI contract will then pass the full list into the contract generatePOItokens */
        
       /* the anti-sybil fuel is then destroyed */
        
        suicide(registrationContract);

   }


}      

contract generatePOIs {    
    
    address mainContract;

    mapping (address => uint) public POIs;
    
    function generatePOIs(address[] verifiedUsers) {
    	mainContract = msg.sender;
        for (uint i = 0; i < verifiedUsers.length; i++) {
           POIs[verifiedUsers[i]] += 1;
    	}
    }

    function verifyPOI(address POIholder) external returns (bool success) {
        if (msg.sender != mainContract) throw;
        if(POIs[POIholder] == 1) return true;
    }
    
    function killContract(){
        if(msg.sender != mainContract) throw;
        suicide(mainContract);
    }
      
}
/*  
    All deposits are managed by one contract. Upon registration, the anti-spam deposit is automatically used to vote for the current
    depositSize. This auto-vote can then be changed and used to vote for another proposal, or to create a new proposal. At the end of
    each round, proccessProposals() is called and the proposal that has the highest number of up-votes, measured in ether, becomes 
    the new depositSize. proposals[0] will probably win most of the time, unless there is an active community effort to change the 
    depositSize 
*/
   
contract depositGovernance {

address registrationContract;
address poiContract;


address[] participants;
mapping(address => bool) participantIndex;

mapping(address => uint256) public AutoVote;
mapping(address => uint256) public Votes;

struct proposeNewDeposit {
    uint256 depositSize;
    uint256 votesInFavour; // in ether
    uint256 votesAgainst;  // in ether
}

proposeNewDeposit[] public proposals;

function depositGovernance(uint currentDepositSize, address registrationContract){
    poiContract = msg.sender;
    registrationContract = registrationContract;
    proposals.push(proposeNewDeposit({
             depositSize: currentDepositSize,
             votesInFavour: 0,
             votesAgainst: 0
         }));
}


function registrationDeposit(address registrant) external {
if(msg.sender != registrationContract) throw;   
if(participantIndex[registrant] == false) participants.push(msg.sender); participantIndex[msg.sender] = true;

/* the registrant automatically uses their anti-spam deposits to vote for the current depositSize */
/* they can move their auto-vote to vote for other proposals if they wish, by using voteOnProposal() */
    AutoVote[registrant] += msg.value;
    proposals[0].votesInFavour += msg.value;
}

function NewProposal(uint256 depositSize) public {
        uint availableEther = AutoVote[msg.sender] + msg.value;
        if(availableEther < depositSize) throw;
        if(participantIndex[msg.sender] == false) participants.push(msg.sender); participantIndex[msg.sender] = true;
        proposals.push(proposeNewDeposit({
            depositSize: depositSize,
            votesInFavour: depositSize,
            votesAgainst: 0
        }));
        AutoVote[msg.sender] -= (availableEther - msg.value);
        proposals[0].votesInFavour -= (availableEther - msg.value);
        Votes[msg.sender] += depositSize;
}



function voteOnProposal(uint proposalIndex, bool opinion, uint amount) public {
   
        uint availableEther = AutoVote[msg.sender] + msg.value;
        if(availableEther < amount) amount = availableEther; 
        if(participantIndex[msg.sender] == false) participants.push(msg.sender); participantIndex[msg.sender] = true;

        if(opinion == true)
        proposals[proposalIndex].votesInFavour += amount;
        else
        proposals[proposalIndex].votesAgainst += amount;
        
        AutoVote[msg.sender] -= (amount - msg.value);
        proposals[0].votesInFavour -=  (amount - msg.value);
        Votes[msg.sender] += amount;
}

function processProposals() external { // invoked at the end of each round
    if(msg.sender != poiContract) throw;
    uint iterateToHighest;
    
     for (uint i = 0; i < proposals.length; i++){
        if(proposals[i].votesInFavour > proposals[i].votesAgainst && proposals[iterateToHighest].votesInFavour < proposals[i].votesInFavour)
        iterateToHighest = i;
    }
    
        uint newDepositSize = proposals[iterateToHighest].depositSize;
    
    	poi(poiContract).newDepositSize(newDepositSize);
    
    /* then return deposits */
    
        for (uint k = 1; k < participants.length; k++){
            uint totalDeposit = AutoVote[participants[k]] + Votes[participants[k]];
            participants[k].send(totalDeposit);
         }
         
    /* then suicide contract */
    suicide(poiContract);
}


}
