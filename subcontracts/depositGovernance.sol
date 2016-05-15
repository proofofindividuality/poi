/* manage all deposits in one contract. allow users to vote using the ether from their registration deposit, if they want. 
   return all deposits after the round has finished. */

contract depositGovernance {

address registrationContract;
address poiContract;

struct Participant {
      address participant;
      uint256 antiSpamDeposit;
      uint256 Votes;  // deposited ether that has been used to vote
}

Participant[] public participants;

mapping (address => uint256) public participantID;


struct proposeNewDeposit {
    uint256 depositSize;
    uint256 votesInFavour; // in ether
    uint256 votesAgainst;  // in ether

}

proposeNewDeposit[] public proposals;

function depositGovernance(uint currentDepositSize){
    poiContract = msg.sender;
    participants.length++;
    participants[0] = Participant({participant: 0, antiSpamDeposit: 0, Votes: 0});
    
    proposals.push(proposeNewDeposit({
             depositSize: currentDepositSize,
             votesInFavour: 0,
             votesAgainst: 0
         }));
}

// contract registration calls registrationDeposit(msg.sender).value(msg.value)

function registrationDeposit(address registrant)  {
if(msg.sender != registrationContract) throw;   
if(participantID[registrant] == 0) {
      participantID[registrant] = participants.length;
      participants.push(Participant({
               participant: registrant,
               antiSpamDeposit: msg.value / 1 ether,
               Votes: 0
           }));
   }
   else {
      participants[participantID[registrant]].antiSpamDeposit += msg.value / 1 ether;
   }
   proposals[0].votesInFavour += msg.value / 1 ether;
   
}

function NewProposal(uint256 depositSize){
        uint availableEther = participants[participantID[msg.sender]].antiSpamDeposit + msg.value / 1 ether;
        if(availableEther < depositSize) throw;
        proposals.push(proposeNewDeposit({
            depositSize: depositSize,
            votesInFavour: depositSize,
            votesAgainst: 0
        }));
        participants[participantID[msg.sender]].antiSpamDeposit -= availableEther - msg.value / 1 ether;
        proposals[0].votesInFavour -= availableEther - msg.value / 1 ether;
        participants[participantID[msg.sender]].Votes += depositSize;
}



function voteOnProposal(uint proposalIndex, bool opinion, uint amount) {
        if(participantID[msg.sender] == 0) {
              participantID[msg.sender] = participants.length;
              participants.push(Participant({
                       participant: msg.sender,
                       antiSpamDeposit: 0,
                       Votes: 0
                   }));
           
        }   
        uint availableEther = participants[participantID[msg.sender]].antiSpamDeposit + msg.value / 1 ether;
        if(availableEther < amount) amount = availableEther; 
        
        if(opinion == true)
        proposals[proposalIndex].votesInFavour += amount;
        else
        proposals[proposalIndex].votesAgainst += amount;
        participants[participantID[msg.sender]].antiSpamDeposit -= amount - (msg.value / 1 ether);
        proposals[0].votesInFavour -=  amount - (msg.value / 1 ether);
        participants[participantID[msg.sender]].Votes += amount;
}

function processProposals() { // invoked at the end of each round
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
            uint totalDeposit = participants[k].antiSpamDeposit + participants[k].Votes;
            participants[k].participant.send(totalDeposit * 1 ether);
         }
    /* then suicide contract */
    if(this.balance == 0) suicide(poiContract);
}


}
