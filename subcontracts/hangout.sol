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
        
        suicide(registrationContract);

   }


}      
