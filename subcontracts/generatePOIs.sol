
/* 
  POIs are indexed and searchable, allowing a user to link together a continuous and chronological chain of POIs, if they want to.
  To do so is completely optional, and the main use-case for POIs is to just use them for one month, and then discard the old ones.
*/

contract generatePOIs {    
    
    address poiContract;

    mapping (address => uint) public POIs;
    
    function generatePOIs(address[] verifiedUsers) {
        for (uint i = 0; i < verifiedUsers.length; i++) {
           POIs[verifiedUsers[i]] += 1;
    	}
    }

    function verifyPOI(address POIholder) external returns (bool success) {
        if (msg.sender != poiContract) throw;
        if(POIs[POIholder] == 1) return true;
    }
    
    function doSignature() public returns (bool success) {
        if(POIs[msg.sender] == 1) return true;
    }
      
}
