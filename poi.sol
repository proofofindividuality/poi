contract poi {
    
    address public POIs;
    address public registrationContract;
    address public depositContract;

    address scheduler;

    uint nextRound;
    uint roundLength;

    uint depositSize;
    uint groupSize;

    function poi (){
        roundLength = 2 days;
        depositSize = 1 ether;
        groupSize = 5;
        scheduler = 0x26416b12610d26fd31d227456e9009270574038f; 
    }
    
    function andSoItBegins() {
        if(nextRound != 0) throw;
        nextRound = block.number;
        newRound();
    }
    
    function newRound() {
        if(block.number < nextRound) throw;
        registrationContract = new registration(roundLength, groupSize, depositSize);
        registration(registrationContract).startRound.value(200000000000000000)();
        depositContract = new depositGovernance(depositSize, registrationContract);
        nextRound += roundLength;
        scheduleRound();
    }

    function scheduleRound() internal {
        bytes4 sig = bytes4(sha3("newRound()"));
        bytes4 scheduleCallSig = bytes4(sha3("scheduleCall(bytes4,uint256)"));
        scheduler.call.value(50000000000000000)(scheduleCallSig, sig, nextRound);
    }
    
    function issuePOIs(address[] verifiedUsers) external {
        if(msg.sender != registrationContract) throw;
        generatePOIs(POIs).killContract();
        POIs = new generatePOIs(verifiedUsers);
        endRound();
    }
    
    function endRound () internal {
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
    address mainContract;
    address depositContract;

    uint randomHour;
    uint public deadLine;
    uint hangoutCountdown;
    uint issuePOIsCountdown;
    
    uint depositSize;
    uint groupSize;
   
    mapping(address => bool) public registered;
    address[] registeredUsers;
    uint256[] randomizedTemplate;

    mapping(address => uint) userGroup;
    uint groupCount;
    
    address[][] hangoutGroups;
    mapping(uint => bytes32) public hangoutAddress;
    mapping (address => bool) hangoutInSession;

    address[] verifiedUsers;

    function registration(uint roundLength, uint groupSize, uint depositSize){
        mainContract = msg.sender;
        groupSize = groupSize;
        depositSize = depositSize;
        randomHour = uint8(sha3(this))%24 + 1; 
        deadLine = block.number + roundLength - randomHour - 1 hours; 
        hangoutCountdown = block.number + roundLength - randomHour; 
        issuePOIsCountdown = block.number + roundLength - randomHour + 45 minutes; 
        scheduler = 0x26416b12610d26fd31d227456e9009270574038f; 
    }
    
    function startRound() external {
        if(msg.sender != mainContract) throw;
        scheduleShuffling();
        scheduleHangouts();
        scheduleIssuePOIs();
    }

    function scheduleShuffling() internal {
        bytes4 sig = bytes4(sha3("generateGroups()"));
        bytes4 scheduleCallSig = bytes4(sha3("scheduleCall(bytes4,uint256)"));
        scheduler.call.value(50000000000000000)(scheduleCallSig, sig, deadLine);
    }
    
    function scheduleHangouts() internal {
        bytes4 sig = bytes4(sha3("startHangouts()"));
        bytes4 scheduleCallSig = bytes4(sha3("scheduleCall(bytes4,uint256)"));
        scheduler.call.value(50000000000000000)(scheduleCallSig, sig, hangoutCountdown);
    }
    
    function scheduleIssuePOIs() internal {
        bytes4 sig = bytes4(sha3("issuePOIs()"));
        bytes4 scheduleCallSig = bytes4(sha3("scheduleCall(bytes4,uint256)"));
        scheduler.call.value(50000000000000000)(scheduleCallSig, sig, issuePOIsCountdown);
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

    function getRandomNumber(uint seed) internal returns (uint) {
        return (uint(sha3(block.blockhash(block.number-1), seed))%100);
    }

    function generateGroups() {
        if(block.number < deadLine) throw;

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
        
        uint counter;
        groupCount = 0;
        
        for(i = 0; i < randomizedTemplate.length; i++){
            if(counter == groupSize){ groupCount++; counter = 0;}
            userGroup[registeredUsers[randomizedTemplate[i]]] = groupCount;
            hangoutGroups[groupCount].push(registeredUsers[randomizedTemplate[i]]);
            counter++;
        }
        for(i = 0; i < groupCount; i++){
            hangoutAddress[i]= sha3(hangoutGroups[i]);
        }
    }

    function getHangoutAddress() public returns(bytes32){
        if(hangoutAddress[userGroup[msg.sender]] == 0) throw;
        bytes32 hangoutURL = hangoutAddress[userGroup[msg.sender]];
        return hangoutURL;
    }

    function startHangouts() {
    	if(block.number < hangoutCountdown) throw;
        for (uint i = 0; i < groupCount; i++) {
            address b = new hangout(hangoutGroups[groupCount]);
            hangoutInSession[b] = true;
        }
    }

    function submitVerifiedUsers(address[] verified) {
        if(hangoutInSession[msg.sender] != true) throw; 
        if(block.number > issuePOIsCountdown) throw; 

        for (uint i = 0; i < verified.length; i++) {
            verifiedUsers.push(verified[i]);
        }
        hangoutInSession[msg.sender] == false;
    }
    
    function issuePOIs(){
        if(block.number < issuePOIsCountdown) throw; 
            poi(mainContract).issuePOIs(verifiedUsers);
    }
    
    function killContract(){
        if(msg.sender != mainContract) throw;
        suicide(mainContract);
    }
}


contract hangout {

    address registrationContract;

    uint public deadline;
    
    mapping(address => uint256) positiveRewards;
    mapping(address => uint256) negativeRewards;
    mapping(address => uint256) recievedPoints; 

    address[] participants;

    address[] verifiedUsers;


    function hangout(address[] hangoutGroup) {
        registrationContract = msg.sender;
        for (uint i = 0; i < hangoutGroup.length; i++) {
            participants.push(hangoutGroup[i]);
        }
        deadline = block.number + 15 minutes;
    }

    function positiveReward(address _to, uint256 _value) {
        uint giveLimit;
        uint recieveLimit;
        if (positiveRewards[msg.sender] + _value > 5000) {
            giveLimit = 5000 - positiveRewards[msg.sender]; 
        }
        if (recievedPoints[_to] + _value > 5000) {        
            recieveLimit = 5000 - recievedPoints[_to];      
        }
        if(giveLimit < recieveLimit) _value = giveLimit;
        else _value = recieveLimit;
        
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

    function closeSession(){
        if(block.number < deadline) throw;
        for(uint i = 0; i < participants.length; i++){
            if(recievedPoints[participants[i]] > 4000) verifiedUsers.push(participants[i]);
        }
        registration(registrationContract).submitVerifiedUsers(verifiedUsers);
  
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
