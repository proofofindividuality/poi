// proposal for overall architecture of the POI system
// by Johan, @resilience_me

// for an image of how the parts of the system fit together, see http://i.imgur.com/umgmBgk.png

// this is meant as a early draft of how the full system could work. parts of the draft might be production ready.
// this draft is meant to help spread the POI system concept, and to expand the number of people who invest attention in development


// contract depositGovernance: more or less finished
// generatePOIs: more or less finished
// hangout: more or less finished 
// registration: needs to be cleaned up 
// poi: not finished, needs work, scheduling needs to be streamlined and integrated with ethereum-alarm-service,
// and the other contracts need to integrate better with the main contract

 
   
// overview of the contracts:
//
// depositGovernance: manages the anti-spam deposits, and also includes a system to vote on the size of the anti-spam deposit.
// 		      a new contract is created each round, and the old one sucidides.
//
// generatePOIs: issues undivisible POI tokens to all verified users. a new contract is created after each round, and the old one suicides.
// 
// hangout: manages the verification within the hangouts. includes the ASF system that 'gamifies the hangouts' by using a point system
// 	    instead of one-vote-per-person, allowing users in a hangout to direct and steer each others attention more. a new contract is created for each hangout.
// 
// registration: manages the registration of users each month, assing them into groups by random, and boots up hangout contracts. new contract is created each round.
// 
// poi: main contract. boots up the other contracts, manages scheduling, and integrates some function calls.



// it's perhaps not optimal to boot up new contracts for everything all the time. 
// library contracts could perhaps be useful. inexperienced with those.
// feedback and better solutions are welcome, and will be added to what I do on my end.



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
        currentRound = new registration(roundLength, depositSize, groupSize);
        
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


contract registration {

    address owner;
    
    uint randomHour; // alternate the hour of the day that the global event occurs on
    uint public deadLine;
    uint hangoutCountdown;
    uint issuePOIsCountdown;
    
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

    /* the deposits are managed by the depositGovernance contract, so registration contract only 
       stores depositSize and the address for the depositContract */
    
    uint depositSize;
    address depositContract;




    function registration(uint roundLength, uint depositSize, uint groupSize){
        groupSize = groupSize;
        randomHour = uint8(sha3(this))%24 + 1; // generate random number between 1 and 24
        deadLine = block.number + roundLength - randomHour - 1 hours; // leave enough time for the randomization algorithm to add users to groups
        hangoutCountdown = block.number + roundLength - randomHour; // allow hangouts to begin at the randomHour clock stroke
        issuePOIsCountdown = block.number + roundLength - randomHour + 45 minutes; // leave 30 minutes for all verified users to be submitted
        depositSize = depositSize;
        owner = msg.sender;
    }
    
    function register() returns (bool){
        if(block.number > deadLine) throw;
        if(msg.value < depositSize * 1 ether) throw;
        if(registered[msg.sender] == true) throw;
        registeredUsers.push(msg.sender);
        registered[msg.sender] = true;
        
        bytes4 registrationDepositSig = bytes4(sha3("registrationDeposit(address)"));
	depositContract.call.value(msg.value)(registrationDepositSig, msg.sender);
        return true;
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
        return hangoutAddressRegistry[userGroup[msg.sender]];
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
            poi(owner).issuePOIs(verifiedUsers);
            
    }
    
    function endRound(){
        if(msg.sender != owner) throw;
        suicide(owner);
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
       
        bytes4 submitVerifiedUsersSig = bytes4(sha3("submitVerifiedUsers(address[])"));
        registrationContract.call(submitVerifiedUsersSig, verifiedUsers);
        
        // registration(registrationContract).submitVerifiedUsers(verifiedUsers);

       /* the POI contract will then pass the full list into the contract generatePOItokens */
        
       /* the anti-sybil fuel is then destroyed */
        
        suicide(owner);

   }


}      
   
  

contract generatePOIs {    
    
    address owner;
  
    string public name;
    string public symbol;
    uint8 public decimals;
    
    mapping (address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function generatePOIs(address[] verifiedUsers) {
        owner = msg.sender;
        balanceOf[owner] = verifiedUsers.length;            // Give the creator all initial tokens                    
        name = "POI";                                       // Set the name for display purposes     
        symbol = "POI";                                     // Set the symbol for display purposes    
        decimals = 0;                                       // Amount of decimals for display purposes        
    
      /* Send POIs to every verified address */

        for (uint i = 0; i < verifiedUsers.length; i++)
           balanceOf[owner] -= 1;                                              
           balanceOf[verifiedUsers[i]] += 1;
           Transfer(owner, verifiedUsers[i], 1);            // Notify anyone listening that this transfer took place
    }


    function depricatePOIs() {
     if (msg.sender == owner) suicide(owner);
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
    
        /* pass newDepositSize to poi contract */
        bytes4 newDepositSizeSig = bytes4(sha3("newDepositSize(uint)"));
        poiContract.call(newDepositSizeSig, newDepositSize);
    
    
    /* then return deposits */
    
        for (uint k = 1; k < participants.length; k++){
            uint totalDeposit = AutoVote[participants[k]] + Votes[participants[k]];
            participants[k].send(totalDeposit);
         }
         
    /* then suicide contract */
    suicide(poiContract);
}


}
