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
