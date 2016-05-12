contract hangout {

/* 
Anti-sybil fuel (ASF) is used to gamify the POI hangouts. Participants can 
use it to "hijack each other's attention", which makes it easier for the 
POI community to keep high standards. Each user gets 5000 "anti-sybil fuel" points, 
and then rewards the other 4 users for their attention. This makes it possible 
for 4 people to put peer-pressure on the 5th if the 5th person isn't focused 
on the joint attention test. 
*/

  address owner;

  uint public genesisblock;
  uint public deadline;


    struct ASF {
        uint256 positiveRewards;  // hangout-attendees get to deal out +5000 anti-sybil fuel (ASF), 
        uint256 negativeRewards;  // and -2000 ASF, 
        uint256 recievedPoints;   // and need to receive +4000 to be verified
    }

    mapping (address => ASF) public ASFbalances;
    address[] participants;

    address[] verifiedUsers;


    function hangout(address[] hangoutGroup) {

        for (uint i = 0; i < hangoutGroup.length; i++)
            participants.push(hangoutGroup[i]);

            genesisblock = block.number;
            deadline = genesisblock + 15 minutes; // hangouts are 15 minutes long
            owner = msg.sender;

    }

    function rewardASF(address _to, uint256 _value, bool isNegative) {
    if(isNegative == false) {
    
    /* If the sent amount is bigger than the maximum amount one can give, send max amount */
        if (ASFbalances[msg.sender].positiveRewards + _value > 5000)
        _value = 5000 - ASFbalances[_to].positiveRewards;

    /* If the sent amount is bigger than the maximum reward limit, send max amount */
        if (ASFbalances[_to].recievedPoints + _value > 5000)
        _value = 5000 - ASFbalances[_to].recievedPoints;

    /* transfer the anti sybil fuel */
        ASFbalances[msg.sender].positiveRewards +=_value;
        ASFbalances[_to].recievedPoints +=_value;

    }
    else {
    
    /* If the sent amount is bigger than the maximum amount one can give, send max amount */
        if (ASFbalances[msg.sender].negativeRewards + _value > 2000)
        _value = 2000 - ASFbalances[msg.sender].negativeRewards;
    
    /* transfer the anti sybil fuel */
        ASFbalances[msg.sender].negativeRewards +=_value;
        ASFbalances[_to].recievedPoints -=_value;

    }

   } 

   /* after 15 minutes, each users that has been awarded 4000 ASF or more is seen as verified and given a POI token */

   /* the closeSession function can be called by anyone in the hangut once the deadline has passed */

   function closeSession(){
      if(block.number<deadline) throw;
      
      for(uint i = 0; i < participants.length; i++){
        if(ASFbalances[participants[i]].recievedPoints > 4000)
            verifiedUsers.push(participants[i]);
        }
       /* pass verifiedUsers into a contract that generates POIs, together with verifiedUsers from all other hangouts */

        registration(owner).submitVerifiedUsers(verifiedUsers);

       /* the POI contract will then pass the full list into the contract generatePOItokens */
       
       
        
       /* the anti-sybil fuel is then destroyed */
        
        suicide(owner);

   }


}      
