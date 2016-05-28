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
