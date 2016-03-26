
/* manage all deposits in one contract. allow users to vote using the ether from their registration deposit, if they want. 
   return all deposits after the round has finished. */

contract depositGovernance {

address owner;
address registrationContract;

/* manage deposits */

mapping (address => uint256) deposits; // deposits that have not been used as votes
mapping (address => uint256) votes; // deposited ether that has been used to vote

mapping (address => uint256) addressIndex;

address[] depositRegistry;


struct proposeNewDeposit {
    uint256 depositSize;
    uint256 votesInFavour; // in ether
    uint256 votesAgainst;  // in ether

}

proposeNewDeposit[] proposals;



function depositGovernance(){
    owner = msg.sender;
}

// contract registration calls registrationDeposit(msg.sender).value(msg.value)

function registrationDeposit(address registrant){
if(msg.sender != registrationContract) throw;
deposits[registrant] += msg.value;
if(addressIndex[registrant] == 0)

depositRegistry.push(registrant);

}

function NewProposal(uint256 depositSize){
        if(msg.value < depositSize * 1 ether) throw;
        proposals.push(proposeNewDeposit({
            depositSize: depositSize,
            votesInFavour: 0,
            votesAgainst: 0
        }));
        
       deposits[msg.sender] += msg.value / 1 ether;
       if(addressIndex[msg.sender] == 0)
            depositRegistry.push(msg.sender);
            addressIndex[msg.sender] = depositRegistry.length;


       /* add surplus to votesInFavour */
       if(msg.value > depositSize * 1 ether)
       proposals[proposals.length].votesInFavour += msg.value/1 ether - depositSize;

}

function voteOnProposal(uint proposalIndex, bool opinion){
        if(msg.value < proposals[proposalIndex].depositSize * 1 ether) throw;
        
        if(opinion == true)
        proposals[proposalIndex].votesInFavour += msg.value * 1 ether;
        else
        proposals[proposalIndex].votesAgainst += msg.value * 1 ether;

       deposits[msg.sender] += msg.value / 1 ether;
       if(addressIndex[msg.sender] == 0)
            depositRegistry.push(msg.sender);
            addressIndex[msg.sender] = depositRegistry.length;
}

function processProposals() { // invoked at the end of each round
    if(msg.sender != owner) throw;
    uint iterateToHighest;
    
     for (uint i = 0; i < proposals.length; i++){
        if(proposals[i].votesInFavour > proposals[i].votesAgainst && proposals[iterateToHighest].votesInFavour < proposals[i].votesInFavour)
        iterateToHighest = i;
    }
    
    if(proposals[iterateToHighest].votesInFavour > 0) {
        uint newDepositSize = proposals[iterateToHighest].depositSize;
    
        /* pass newDepositSize to poi contract */
    
        poi(owner).newDepositSize(newDepositSize);
    }
    
    /* then return deposits */
    
        for (uint k = depositRegistry.length; k < 0 ; k++)
            depositRegistry[i].send(deposits[depositRegistry[i]]);
            
    /* then suicide contract */
    if(depositRegistry.length == 0)
        suicide(owner);
}


}
