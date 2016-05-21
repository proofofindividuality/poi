/* 
  POIs are indexed and searchable, allowing a user to link together a continuous and chronological chain of POIs, if they want to.
  To do so is completely optional, and the main use-case for POIs is to just use them for one month, and then discard the old ones.
*/

contract generatePOIs {    
    
    address poiContract;
  
    string public name;
    string public symbol;
    uint8 public decimals;
    
    mapping (address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function generatePOIs(address[] verifiedUsers) {
        poiContract = msg.sender;
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


    function verifyPOI(address POIholder) external returns (bool success) {
     if (msg.sender != poiContract) throw;
      if(balanceOf[POIholder] == 1) return true;
    }
      
   
}
