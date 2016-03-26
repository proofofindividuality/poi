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
